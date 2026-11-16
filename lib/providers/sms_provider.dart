import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/services/sms_service.dart';

class SmsCampaignState {
  final List<SmsCampaign> campaigns;
  final bool isLoading;
  final String? errorMessage;
  final double walletBalance;
  final String currency;

  const SmsCampaignState({
    this.campaigns = const [],
    this.isLoading = false,
    this.errorMessage,
    this.walletBalance = 0.0,
    this.currency = 'NGN',
  });

  SmsCampaignState copyWith({
    List<SmsCampaign>? campaigns,
    bool? isLoading,
    String? errorMessage,
    double? walletBalance,
    String? currency,
  }) {
    return SmsCampaignState(
      campaigns: campaigns ?? this.campaigns,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      walletBalance: walletBalance ?? this.walletBalance,
      currency: currency ?? this.currency,
    );
  }
}

class SmsCampaignNotifier extends Notifier<SmsCampaignState> {
  late SupabaseService _supabaseService;
  late SmsService _smsService;
  String? _loadedCompanyId;

  @override
  SmsCampaignState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _smsService = ref.watch(smsServiceProvider);

    final authState = ref.watch(authProvider);
    final companyId = authState.profile?.companyId;

    if (companyId != null) {
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() {
          loadSmsCampaigns();
          refreshWalletBalance();
        });
        return const SmsCampaignState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const SmsCampaignState();
    }
  }

  String? _getEffectiveApiKey(Company? company) {
    final key = company?.termiiApiKey;
    if (key != null && key.trim().isNotEmpty && !key.startsWith('tlv_')) {
      return key.trim();
    }
    return null;
  }

  /// Refresh wallet balance using SmartSMS Solutions API
  Future<void> refreshWalletBalance() async {
    final company = ref.read(authProvider).company;
    final apiKey = _getEffectiveApiKey(company);
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(walletBalance: 0.0, errorMessage: 'SmartSMS Token not configured in Settings.');
      return;
    }
    try {
      final response = await _smsService.checkBalance(apiKey);
      if (response.error == null) {
        state = state.copyWith(
          walletBalance: response.balance,
          currency: response.currency,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(errorMessage: 'SmartSMS: ${response.error}');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Load all SMS campaigns for the company
  Future<void> loadSmsCampaigns() async {
    final authState = ref.read(authProvider);
    final companyId = authState.profile?.companyId;
    if (companyId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final response = await _supabaseService.client
          .from('sms_campaigns')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
      
      final list = (response as List)
          .map((json) => SmsCampaign.fromJson(json as Map<String, dynamic>))
          .toList();
      
      state = state.copyWith(campaigns: list, isLoading: false);
    } catch (_) {
      // sms_campaigns table may not exist in database yet; fail gracefully
      state = state.copyWith(campaigns: [], isLoading: false);
    }
  }

  /// Create and send an SMS campaign, saving records to Supabase
  Future<bool> sendCampaign({
    required String title,
    required String message,
    required List<({String? name, String phone, String? type})> recipients,
  }) async {
    final authState = ref.read(authProvider);
    final profile = authState.profile;
    final company = authState.company;
    if (profile == null || profile.companyId == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final apiKey = _getEffectiveApiKey(company);
      final senderId = (company?.termiiSenderId != null && company!.termiiSenderId!.trim().isNotEmpty)
          ? company.termiiSenderId!.trim()
          : 'NIS LTD';

      if (apiKey == null || apiKey.trim().isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'SmartSMS API Token not configured. Please enter your SmartSMS Token in Admin -> Settings.',
        );
        return false;
      }

      // 1. Insert SMS campaign record if table exists
      SmsCampaign? campaign;
      try {
        final campaignJson = await _supabaseService.client.from('sms_campaigns').insert({
          'company_id': profile.companyId,
          'title': title,
          'message': message,
          'channel': 'generic',
          'sender_id': senderId,
          'total_recipients': recipients.length,
          'delivered_count': 0,
          'failed_count': 0,
          'status': 'sending',
          'sent_by': profile.id,
        }).select().single();

        campaign = SmsCampaign.fromJson(campaignJson);
      } catch (_) {
        // sms_campaigns table does not exist in schema; proceed with sending without DB logging
      }

      int delivered = 0;
      int failed = 0;
      String? lastFailureReason;

      // 2. Dispatch SMS messages
      for (int i = 0; i < recipients.length; i++) {
        final rec = recipients[i];
        final recName = rec.name ?? 'Contact';
        final firstName = recName.split(' ').first;
        final personalised = message.replaceAll('{{name}}', firstName);

        bool success = false;
        String? errorMsg;

        try {
          final result = await _smsService.sendSmsResult(
            to: rec.phone,
            message: personalised,
            apiKey: apiKey,
            senderId: senderId,
          );
          success = result.success;
          if (success) {
            delivered++;
          } else {
            failed++;
            errorMsg = result.message;
            lastFailureReason = result.message;
          }
        } catch (e) {
          failed++;
          errorMsg = e.toString();
          lastFailureReason = e.toString();
        }

        // 3. Log individual message if campaign record exists
        if (campaign != null) {
          try {
            await _supabaseService.client.from('sms_messages').insert({
              'campaign_id': campaign.id,
              'recipient_name': recName,
              'recipient_phone': rec.phone,
              'recipient_type': rec.type,
              'message_body': personalised,
              'status': success ? 'delivered' : 'failed',
              'error_message': errorMsg,
            });
          } catch (_) {}
        }

        // Fast abort on critical account-level errors (insufficient balance, invalid token, route rejected)
        if (!success && lastFailureReason != null) {
          final lower = lastFailureReason.toLowerCase();
          if (lower.contains('insufficient') ||
              lower.contains('invalid token') ||
              lower.contains('not allowed') ||
              lower.contains('unregistered')) {
            // Mark remaining recipients as failed due to the same account-level barrier
            for (int j = i + 1; j < recipients.length; j++) {
              failed++;
              if (campaign != null) {
                try {
                  await _supabaseService.client.from('sms_messages').insert({
                    'campaign_id': campaign.id,
                    'recipient_name': recipients[j].name ?? 'Contact',
                    'recipient_phone': recipients[j].phone,
                    'recipient_type': recipients[j].type,
                    'message_body': message,
                    'status': 'failed',
                    'error_message': lastFailureReason,
                  });
                } catch (_) {}
              }
            }
            break;
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 4. Update SMS campaign record status & counts if campaign record exists
      if (campaign != null) {
        final campaignStatus = delivered == 0 ? 'failed' : (failed > 0 ? 'partial' : 'sent');
        try {
          await _supabaseService.client.from('sms_campaigns').update({
            'status': campaignStatus,
            'delivered_count': delivered,
            'failed_count': failed,
            'sent_at': DateTime.now().toIso8601String(),
          }).eq('id', campaign.id);
        } catch (_) {}
      }

      // Refresh data
      await loadSmsCampaigns();
      await refreshWalletBalance();

      if (delivered == 0 && failed > 0) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: lastFailureReason ?? 'All messages failed to deliver. Check SmartSMS balance or Sender ID.',
        );
        return false;
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final smsCampaignProvider = NotifierProvider<SmsCampaignNotifier, SmsCampaignState>(() {
  return SmsCampaignNotifier();
});
