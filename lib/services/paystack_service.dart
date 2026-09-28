import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:nissie_ideal_shelters/config/supabase_config.dart';

final paystackServiceProvider = Provider<PaystackService>((ref) {
  return PaystackService();
});

class NigerianBank {
  final String name;
  final String code;
  final String slug;

  const NigerianBank({
    required this.name,
    required this.code,
    required this.slug,
  });

  factory NigerianBank.fromJson(Map<String, dynamic> json) {
    return NigerianBank(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

class AccountResolutionResult {
  final bool isValid;
  final String accountName;
  final String accountNumber;
  final String? errorMessage;

  const AccountResolutionResult({
    required this.isValid,
    required this.accountName,
    required this.accountNumber,
    this.errorMessage,
  });
}

class PaystackService {
  static const String _baseUrl = 'https://api.paystack.co';

  static const String _defaultPublicKey = 'pk_live_05c3f6c24b453816614c11e1a3d61e3c6842e8eb';

  /// Standard default public key for Nissie testing / fallback
  String get publicKey {
    const defined = String.fromEnvironment('PAYSTACK_PUBLIC_KEY');
    if (defined.isNotEmpty) return defined;
    try {
      final envVal = dotenv.env['PAYSTACK_PUBLIC_KEY'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return _defaultPublicKey;
  }

  String? get secretKey {
    const defined = String.fromEnvironment('PAYSTACK_SECRET_KEY');
    if (defined.isNotEmpty) return defined;
    // Secret key must NEVER ship in the client. Resolve via Edge Function.
    return null;
  }

  /// Verified directory of major Nigerian commercial banks and fintechs
  static const List<NigerianBank> defaultBanks = [
    NigerianBank(name: 'Access Bank', code: '044', slug: 'access-bank'),
    NigerianBank(name: 'Guaranty Trust Bank (GTBank)', code: '058', slug: 'gtbank'),
    NigerianBank(name: 'Zenith Bank', code: '057', slug: 'zenith-bank'),
    NigerianBank(name: 'First Bank of Nigeria', code: '011', slug: 'first-bank-of-nigeria'),
    NigerianBank(name: 'United Bank for Africa (UBA)', code: '033', slug: 'united-bank-for-africa'),
    NigerianBank(name: 'OPay Digital Services', code: '999992', slug: 'paycom'),
    NigerianBank(name: 'Palmpay', code: '999991', slug: 'palmpay'),
    NigerianBank(name: 'Kuda Bank', code: '50211', slug: 'kuda-bank'),
    NigerianBank(name: 'Moniepoint Microfinance Bank', code: '50515', slug: 'moniepoint-mfb'),
    NigerianBank(name: 'Fidelity Bank', code: '070', slug: 'fidelity-bank'),
    NigerianBank(name: 'Stanbic IBTC Bank', code: '221', slug: 'stanbic-ibtc-bank'),
    NigerianBank(name: 'Sterling Bank', code: '232', slug: 'sterling-bank'),
    NigerianBank(name: 'Union Bank of Nigeria', code: '032', slug: 'union-bank-of-nigeria'),
    NigerianBank(name: 'Wema Bank', code: '035', slug: 'wema-bank'),
  ];

  /// Resolves a 10-digit NUBAN account number with any Nigerian bank.
  /// Confirms the real legal account name before withdrawal via server Edge Function.
  Future<AccountResolutionResult> resolveAccountNumber({
    required String accountNumber,
    required String bankCode,
  }) async {
    if (accountNumber.length != 10) {
      return const AccountResolutionResult(
        isValid: false,
        accountName: '',
        accountNumber: '',
        errorMessage: 'Account number must be exactly 10 digits',
      );
    }

    try {
      final base = SupabaseConfig.supabaseUrl;
      final anon = SupabaseConfig.supabaseAnonKey;

      // 1. Primary path: Route verification through secure Edge Function holding SECRET
      if (base.isNotEmpty && anon.isNotEmpty) {
        final res = await http.post(
          Uri.parse('$base/functions/v1/paystack-resolve-account'),
          headers: {
            'apikey': anon,
            'Authorization': 'Bearer $anon',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'accountNumber': accountNumber,
            'bankCode': bankCode,
          }),
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['success'] == true && data['accountName'] != null) {
            return AccountResolutionResult(
              isValid: true,
              accountName: data['accountName'] as String,
              accountNumber: (data['accountNumber'] as String?) ?? accountNumber,
            );
          }
        }

        final errData = jsonDecode(res.body) as Map<String, dynamic>?;
        final msg = errData?['message'] as String? ?? 'Could not resolve account name';
        return AccountResolutionResult(
          isValid: false,
          accountName: '',
          accountNumber: accountNumber,
          errorMessage: msg,
        );
      }

      // 2. Direct Fallback: Only if client secretKey was provided in local test environment
      final key = secretKey;
      if (key != null && key.isNotEmpty) {
        final response = await http.get(
          Uri.parse('$_baseUrl/bank/resolve?account_number=$accountNumber&bank_code=$bankCode'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['status'] == true && data['data'] != null) {
            final accountName = data['data']['account_name'] as String? ?? 'VERIFIED RECIPIENT';
            return AccountResolutionResult(
              isValid: true,
              accountName: accountName,
              accountNumber: accountNumber,
            );
          }
        }
      }

      return AccountResolutionResult(
        isValid: false,
        accountName: '',
        accountNumber: accountNumber,
        errorMessage: 'Bank verification unavailable. Please try again when online.',
      );
    } catch (e) {
      debugPrint('PaystackService.resolveAccountNumber error: $e');
      return AccountResolutionResult(
        isValid: false,
        accountName: '',
        accountNumber: accountNumber,
        errorMessage: 'Network error verifying account. Please retry.',
      );
    }
  }

  /// Generates an immutable, unique Paystack transaction reference
  String generateReference({String prefix = 'NISSIE_DEP'}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp';
  }

  /// Launches Paystack checkout via server-initialized transaction.
  /// LIVE SETUP:
  /// 1. Deploy supabase/functions/paystack-initialize, paystack-verify,
  ///    paystack-webhook with PAYSTACK_SECRET_KEY (+ SERVICE_ROLE for webhook).
  /// 2. Run app with --dart-define SUPABASE_URL/ANON_KEY (already required).
  /// Flow: initialize -> open authorization_url -> poll verify -> onSuccess
  /// ONLY after server confirms success. Webhook credits wallet independently
  /// (idempotent on reference), so double-credit is safe.
  Future<bool> launchPaystackCheckout({
    required String email,
    required double amountInNaira,
    required String reference,
    required Function(String reference) onSuccess,
    required VoidCallback onCancel,
    Function(String message)? onError,
    String? userId,
  }) async {
    try {
      if (amountInNaira <= 0) {
        onError?.call('Invalid amount');
        onCancel();
        return false;
      }
      final base = SupabaseConfig.supabaseUrl;
      final anon = SupabaseConfig.supabaseAnonKey;
      if (base.isEmpty || anon.isEmpty) {
        onError?.call('Backend not configured. Contact support.');
        onCancel();
        return false;
      }
      // 1) Initialize server-side (holds SECRET)
      http.Response initRes;
      try {
        initRes = await http
            .post(
              Uri.parse('$base/functions/v1/paystack-initialize'),
              headers: {'apikey': anon, 'Authorization': 'Bearer $anon', 'Content-Type': 'application/json'},
              body: jsonEncode({'email': email, 'amountNaira': amountInNaira, 'reference': reference, 'userId': userId}),
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        onError?.call('Could not reach payment server. Check connection or deploy paystack-initialize.');
        onCancel();
        return false;
      }
      if (initRes.statusCode != 200) {
        onError?.call('Payment server not ready (deploy paystack-initialize + PAYSTACK_SECRET_KEY).');
        onCancel();
        return false;
      }
      final initJson = jsonDecode(initRes.body) as Map<String, dynamic>;
      final url = initJson['authorization_url'] as String?;
      final ref = (initJson['reference'] as String?) ?? reference;
      if (url == null) {
        onError?.call('Payment init failed. Try again.');
        onCancel();
        return false;
      }
      // 2) Open Paystack checkout
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) {
        onError?.call('Could not open payment page.');
        onCancel();
        return false;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // 3) Poll verify (user pays in browser, then returns)
      const maxTries = 45; // ~3 min
      for (var i = 0; i < maxTries; i++) {
        await Future.delayed(const Duration(seconds: 4));
        try {
          final vRes = await http
              .post(
                Uri.parse('$base/functions/v1/paystack-verify'),
                headers: {'apikey': anon, 'Authorization': 'Bearer $anon', 'Content-Type': 'application/json'},
                body: jsonEncode({'reference': ref}),
              )
              .timeout(const Duration(seconds: 10));
          if (vRes.statusCode == 200) {
            final v = jsonDecode(vRes.body) as Map<String, dynamic>;
            if (v['success'] == true) {
              await onSuccess(ref);
              return true;
            }
          }
        } catch (_) {
          // keep polling
        }
      }
      onError?.call('Payment not confirmed yet. If you paid, your wallet will credit via webhook shortly.');
      return false;
    } catch (e) {
      debugPrint('Paystack checkout error: $e');
      onError?.call(e.toString());
      onCancel();
      return false;
    }
  }

  /// Initiates automated transfer payout via the paystack-payout Edge Function.
  Future<Map<String, dynamic>> initiatePayout({
    required String reference,
    required double amount,
    required String accountNumber,
    required String bankCode,
    required String accountName,
  }) async {
    final base = SupabaseConfig.supabaseUrl;
    final anon = SupabaseConfig.supabaseAnonKey;
    final token = SupabaseConfig.client.auth.currentSession?.accessToken ?? anon;

    if (base.isEmpty || anon.isEmpty) {
      return {'success': false, 'message': 'Payment service configuration missing'};
    }

    try {
      final res = await http.post(
        Uri.parse('$base/functions/v1/paystack-payout'),
        headers: {
          'apikey': anon,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reference': reference,
          'amount': amount,
          'accountNumber': accountNumber,
          'bankCode': bankCode,
          'accountName': accountName,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
      if (res.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'reference': data['reference'],
          'transferCode': data['transferCode'],
          'status': data['status'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Payout transfer could not be initiated',
      };
    } catch (e) {
      debugPrint('PaystackService.initiatePayout error: $e');
      return {
        'success': false,
        'message': 'Network error calling payout service: $e',
      };
    }
  }
}
