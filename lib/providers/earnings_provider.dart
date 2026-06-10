import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/auth_state.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/core/enums/enums.dart';

class EarningsState {
  final List<Commission> commissions;
  final List<Transaction> transactions;
  final double runningBalance;
  final bool isLoading;
  final String? errorMessage;

  const EarningsState({
    this.commissions = const [],
    this.transactions = const [],
    this.runningBalance = 0.0,
    this.isLoading = false,
    this.errorMessage,
  });

  EarningsState copyWith({
    List<Commission>? commissions,
    List<Transaction>? transactions,
    double? runningBalance,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EarningsState(
      commissions: commissions ?? this.commissions,
      transactions: transactions ?? this.transactions,
      runningBalance: runningBalance ?? this.runningBalance,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EarningsNotifier extends Notifier<EarningsState> {
  late final SupabaseService _supabaseService;

  @override
  EarningsState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _initialize();
    return const EarningsState();
  }

  void _initialize() {
    // Listen to auth state to load balance/earnings automatically
    ref.listen<AuthState>(authProvider, (previous, next) {
      final profile = next.profile;
      if (profile != null) {
        loadEarnings();
      } else {
        state = const EarningsState();
      }
    }, fireImmediately: true);
  }

  /// Loads earnings, commissions, transactions, and wallet balance.
  Future<void> loadEarnings() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    state = state.copyWith(isLoading: true);
    try {
      List<Commission> comms;
      List<Transaction> txs;
      double balance = 0.0;

      if (profile.role == UserRole.partner) {
        comms = await _supabaseService.getCommissions(
          companyId: profile.companyId,
          partnerId: profile.id,
        );
        txs = await _supabaseService.getTransactions(
          companyId: profile.companyId,
          partnerId: profile.id,
        );
        balance = await _supabaseService.getPartnerBalance(profile.id);
      } else {
        // Admin or Platform Admin view all company transactions/commissions
        comms = await _supabaseService.getCommissions(
          companyId: profile.companyId,
        );
        txs = await _supabaseService.getTransactions(
          companyId: profile.companyId,
        );
      }

      // Sort logs descending by date
      comms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = EarningsState(
        commissions: comms,
        transactions: txs,
        runningBalance: balance,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Closes a lead and auto-provisions a pending commission record.
  Future<bool> closeLeadWithCommission({
    required String leadId,
    required double salePrice,
    required double commissionAmount,
    required String propertyId,
    required String partnerId,
    double? commissionRate,
  }) async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Admin profile not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      // 1. Create commission record (starts as 'pending')
      final Map<String, dynamic> commInsert = {
        'company_id': authProfile.companyId,
        'lead_id': leadId,
        'partner_id': partnerId,
        'property_id': propertyId,
        'sale_price': salePrice,
        'commission_rate': commissionRate,
        'commission_amount': commissionAmount,
        'status': CommissionStatus.pending.value,
      };

      await _supabaseService.createCommission(commInsert);

      // 2. Transition lead stage to closed
      await ref.read(leadProvider.notifier).updateStage(leadId, LeadStage.closed);

      // Reload local logs
      await loadEarnings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Approves a commission payout (Admin only).
  /// This updates the commission status to approved and issues a credit transaction to the partner wallet.
  Future<bool> approvePayout(String commissionId) async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Admin profile not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      // 1. Retrieve commission details
      final comm = state.commissions.cast<Commission?>().firstWhere((c) => c?.id == commissionId, orElse: () => null);
      if (comm == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Commission record not found.');
        return false;
      }

      // 2. Update status to approved in DB
      await _supabaseService.updateCommissionStatus(
        commissionId,
        CommissionStatus.approved,
        approvedBy: authProfile.id,
      );

      // Resolve property details for transaction description
      final property = ref.read(propertyProvider).properties.cast<Property?>().firstWhere(
            (p) => p?.id == comm.propertyId,
            orElse: () => null,
          );
      final propTitle = property?.title ?? 'Referred Property';

      // 3. Create wallet credit transaction log
      final Map<String, dynamic> txInsert = {
        'company_id': comm.companyId,
        'partner_id': comm.partnerId,
        'commission_id': comm.id,
        'type': TransactionType.credit.value,
        'amount': comm.commissionAmount,
        'description': 'Commission payout for property sale: $propTitle',
      };

      await _supabaseService.insert('transactions', txInsert);

      // Reload local ledger
      await loadEarnings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Disputes a payout (Admin only).
  Future<bool> disputePayout(String commissionId) async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Admin profile not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.updateCommissionStatus(
        commissionId,
        CommissionStatus.disputed,
      );
      // Reload
      await loadEarnings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Updates partner bank details.
  Future<bool> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Partner profile not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.updateProfileBankDetails(
        authProfile.id,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
      );

      // Force refresh of the authProvider profile state
      await ref.read(authProvider.notifier).refreshProfile();

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Request withdrawal (Partner only).
  Future<bool> requestWithdrawal({
    required double amount,
  }) async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Partner profile not found.');
      return false;
    }

    if (amount <= 0) {
      state = state.copyWith(errorMessage: 'Withdrawal amount must be greater than zero.');
      return false;
    }

    if (amount > state.runningBalance) {
      state = state.copyWith(errorMessage: 'Insufficient withdrawable balance.');
      return false;
    }

    if (authProfile.bankName == null ||
        authProfile.accountNumber == null ||
        authProfile.accountName == null) {
      state = state.copyWith(errorMessage: 'Please configure your bank details before requesting a withdrawal.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final Map<String, dynamic> txInsert = {
        'company_id': authProfile.companyId,
        'partner_id': authProfile.id,
        'type': TransactionType.withdrawal.value,
        'amount': amount,
        'status': TransactionStatus.pending.value,
        'description': 'Withdrawal request to ${authProfile.bankName} (${authProfile.accountNumber})',
      };

      await _supabaseService.insert('transactions', txInsert);

      // Reload
      await loadEarnings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Process withdrawal request (Admin only - approve or reject).
  Future<bool> resolveWithdrawalRequest(String transactionId, TransactionStatus status) async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Admin profile not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.updateTransactionStatus(transactionId, status);

      // Reload
      await loadEarnings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final earningsProvider = NotifierProvider<EarningsNotifier, EarningsState>(() {
  return EarningsNotifier();
});
