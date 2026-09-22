import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:nissie_ideal_shelters/config/supabase_config.dart';
import 'package:nissie_ideal_shelters/models/wallet.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/paystack_service.dart';

@immutable
class WalletState {
  final Wallet wallet;
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final String? errorMessage;
  final bool isConnectedToSupabase;

  const WalletState({
    required this.wallet,
    this.transactions = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isConnectedToSupabase = true,
  });

  WalletState copyWith({
    Wallet? wallet,
    List<WalletTransaction>? transactions,
    bool? isLoading,
    String? errorMessage,
    bool? isConnectedToSupabase,
    bool clearError = false,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isConnectedToSupabase: isConnectedToSupabase ?? this.isConnectedToSupabase,
    );
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});

class WalletNotifier extends Notifier<WalletState> {
  final sb.SupabaseClient _client = SupabaseConfig.client;

  /// Session-level cache so a provider rebuild (e.g. guest -> signed-in)
  /// never wipes locally-recorded history before Supabase sync lands.
  static List<WalletTransaction> _sessionTxCache = const [];

  static void _cacheTx(List<WalletTransaction> tx) {
    if (tx.isNotEmpty) _sessionTxCache = List.unmodifiable(tx);
  }

  /// Clears session transaction cache on user logout to prevent leakage
  static void clearSessionCache() {
    _sessionTxCache = const [];
  }

  @override
  WalletState build() {
    final authState = ref.watch(authProvider);
    final userId = authState.profile?.id ?? 'guest_user';
    final now = DateTime.now();

    // Clear cache if guest user
    if (userId == 'guest_user') {
      _sessionTxCache = const [];
    }

    final defaultWallet = Wallet(
      id: 'w_$userId',
      userId: userId,
      balance: 0.0,
      ledgerBalance: 0.0,
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    // Initial state: restore session cache only for authenticated users
    final initialTx = (userId != 'guest_user' && _sessionTxCache.isNotEmpty)
        ? _sessionTxCache
        : const <WalletTransaction>[];

    // Trigger asynchronous Supabase ledger sync
    Future.microtask(() => _syncWithSupabase(userId));

    return WalletState(wallet: defaultWallet, transactions: initialTx);
  }

  /// Synchronizes balance and ledger audit trail directly from Supabase PostgreSQL
  Future<void> _syncWithSupabase(String userId) async {
    if (userId == 'guest_user') return;

    try {
      // 1. Fetch or create user wallet in Supabase
      final walletRow = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      Wallet? liveWallet;
      if (walletRow != null) {
        liveWallet = Wallet.fromJson(walletRow);
      } else {
        // Safe insert or RPC
        try {
          final res = await _client.rpc('get_or_create_wallet', params: {'p_user_id': userId});
          if (res != null) {
            liveWallet = Wallet.fromJson(Map<String, dynamic>.from(res));
          }
        } catch (_) {
          // Table or RPC may be pending migration execution in dashboard
        }
      }

      // 2. Fetch user's real transactions
      final txRows = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final liveTransactions = (txRows as List)
          .map((row) => WalletTransaction.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      if (liveWallet != null) {
        final mergedTx = liveTransactions.isNotEmpty ? liveTransactions : state.transactions;
        _cacheTx(mergedTx);
        state = state.copyWith(
          wallet: liveWallet,
          transactions: mergedTx,
          isConnectedToSupabase: true,
        );
      }
    } catch (e) {
      debugPrint('WalletNotifier._syncWithSupabase notice: $e');
      // Graceful local continuity if migration is yet to be applied in Supabase dashboard
      state = state.copyWith(isConnectedToSupabase: false);
    }
  }

  /// Real payment funding via Paystack.
  /// Only the service-role webhook may mint credit (fund RPC is locked down),
  /// so after a verified checkout this polls for the webhook's credit by
  /// reference instead of crediting locally. Fails closed on timeout.
  Future<bool> fundWallet({
    required double amount,
    String method = 'Paystack Card / Transfer',
    String? reference,
  }) async {
    if (amount <= 0) {
      state = state.copyWith(isLoading: false, errorMessage: 'Invalid funding amount');
      return false;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    final paystackRef = reference ?? ref.read(paystackServiceProvider).generateReference();
    final userId = state.wallet.userId;

    if (userId == 'guest_user') {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please sign in before funding your wallet',
      );
      return false;
    }

    // 1) Direct RPC path (only works if ever granted; currently service-role-only).
    try {
      final rpcRes = await _client.rpc('fund_wallet_with_reference', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_reference': paystackRef,
        'p_description': 'Wallet Deposit via $method',
        'p_channel': 'paystack',
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        await _syncWithSupabase(userId);
        state = state.copyWith(isLoading: false);
        return true;
      }
    } catch (_) {
      // Permission-denied or RPC missing: fall through to webhook poll.
    }

    // 2) Webhook poll: checkout was server-verified, credit lands via webhook.
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        await _syncWithSupabase(userId);
      } catch (_) {}
      if (state.transactions.any((t) => t.reference == paystackRef)) {
        state = state.copyWith(isLoading: false);
        return true;
      }
    }
    debugPrint('fundWallet: webhook credit not observed for $paystackRef');
    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Payment confirmed but credit is pending. It will appear shortly — do not pay again.',
    );
    return false;
  }

  /// Deducts inspection deposit from wallet (reserves via server RPC only)
  Future<bool> payInspectionDeposit({
    required String propertyTitle,
    String? bookingId,
    double amount = 3000.0,
  }) async {
    if (amount < 0) {
      state = state.copyWith(errorMessage: 'Invalid deposit amount');
      return false;
    }
    // Free Nissie estate inspections require no hold.
    if (amount == 0) return true;
    if (state.wallet.balance < amount) {
      return false; // Insufficient balance
    }

    final userId = state.wallet.userId;
    if (userId == 'guest_user') {
      state = state.copyWith(errorMessage: 'Please sign in to use wallet balance');
      return false;
    }
    final secure = Random.secure();
    final bId = bookingId ?? 'BK_${secure.nextInt(999999)}';

    try {
      final rpcRes = await _client.rpc('reserve_inspection_deposit', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_booking_id': bId,
        'p_property_title': propertyTitle,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        await _syncWithSupabase(userId);
        return true;
      }
      state = state.copyWith(errorMessage: 'Could not reserve deposit. Try again.');
      return false;
    } catch (e) {
      debugPrint('payInspectionDeposit notice: $e');
      state = state.copyWith(errorMessage: 'Could not reserve deposit. Try again.');
      return false;
    }
  }

  /// Automated on-site PIN verification via server RPC only.
  /// Never credit locally — server splits ₦2,000 agent / ₦1,000 platform.
  Future<bool> releaseInspectionPayout({
    required String bookingId,
    required String pin,
    String? agentId,
    String? propertyTitle,
    double agentPayout = 2000.0,
    double platformFee = 1000.0,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    // Require explicit agent — never default to caller's own wallet (prevents self-payout).
    if (agentId == null || agentId.isEmpty || agentId == 'guest_user') {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Agent verification requires agent sign-in',
      );
      return false;
    }
    final targetAgentId = agentId;

    try {
      final rpcRes = await _client.rpc('settle_inspection_pin_payout', params: {
        'p_booking_id': bookingId,
        'p_pin': pin,
        'p_agent_user_id': targetAgentId,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        await _syncWithSupabase(targetAgentId);
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid PIN or booking. No payout released.',
      );
      return false;
    } catch (e) {
      debugPrint('releaseInspectionPayout notice: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Payout failed. No funds moved.',
      );
      return false;
    }
  }

  /// Releases an escrow hold on a cancelled tour and refunds deposit to balance.
  Future<bool> cancelAndRefundDeposit({required String bookingId}) async {
    final userId = state.wallet.userId;
    if (userId == 'guest_user') return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await _client.rpc('refund_inspection_deposit', params: {
        'p_booking_id': bookingId,
        'p_user_id': userId,
      });

      if (res != null && res['success'] == true) {
        await _syncWithSupabase(userId);
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: (res?['message'] as String?) ?? 'Refund request failed',
      );
      return false;
    } catch (e) {
      debugPrint('cancelAndRefundDeposit error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Refund failed. Please contact support.',
      );
      return false;
    }
  }

  /// Bank withdrawal via server RPC only (min ₦2,000, verified NUBAN).
  Future<bool> requestWithdrawal({
    required double amount,
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    if (amount < 2000) {
      state = state.copyWith(errorMessage: 'Minimum withdrawal is ₦2,000');
      return false;
    }
    if (accountNumber.length != 10) {
      state = state.copyWith(errorMessage: 'Account number must be 10 digits');
      return false;
    }
    if (state.wallet.balance < amount) {
      state = state.copyWith(errorMessage: 'Insufficient wallet balance for withdrawal');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    final userId = state.wallet.userId;
    if (userId == 'guest_user') {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please sign in to withdraw',
      );
      return false;
    }

    try {
      final rpcRes = await _client.rpc('request_agent_withdrawal', params: {
        'p_agent_user_id': userId,
        'p_amount': amount,
        'p_bank_code': bankCode,
        'p_bank_name': bankName,
        'p_account_number': accountNumber,
        'p_account_name': accountName,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        await _syncWithSupabase(userId);
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Withdrawal rejected by server',
      );
      return false;
    } catch (e) {
      debugPrint('requestWithdrawal notice: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Withdrawal failed. No funds moved.',
      );
      return false;
    }
  }
}
