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

  /// Refresh wallet balance using Termii API
  Future<void> refreshWalletBalance() async {
    final company = ref.read(authProvider).company;
    final apiKey = company?.termiiApiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      state = state.copyWith(walletBalance: 5000.0, currency: 'NGN');
      return;
    }
    try {
      final response = await _smsService.checkBalance(apiKey);
      if (response.error == null) {
        state = state.copyWith(
          walletBalance: response.balance,
          currency: response.currency,
        );
      } else {
        state = state.copyWith(errorMessage: 'Termii: ${response.error}');
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
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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

    state = state.copyWith(isLoading: true);
    try {
      final apiKey = company?.termiiApiKey;
      final senderId = company?.termiiSenderId ?? 'Nissie';

      // 1. Insert SMS campaign record as pending/sending
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

      final campaign = SmsCampaign.fromJson(campaignJson);

      int delivered = 0;
      int failed = 0;

      // 2. Dispatch SMS messages
      for (final rec in recipients) {
        final recName = rec.name ?? 'Contact';
        final firstName = recName.split(' ').first;
        final personalised = message.replaceAll('{{name}}', firstName);

        bool success = false;
        String? errorMsg;

        if (apiKey == null || apiKey.trim().isEmpty) {
          // Simulation mode
          success = true;
          delivered++;
        } else {
          try {
            // Sequential sending with delay
            success = await _smsService.sendSms(
              to: rec.phone,
              message: personalised,
              apiKey: apiKey,
              senderId: senderId,
            );
            if (success) {
              delivered++;
            } else {
              failed++;
              errorMsg = 'Termii failed to send';
            }
          } catch (e) {
            failed++;
            errorMsg = e.toString();
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 3. Log individual message
        await _supabaseService.client.from('sms_messages').insert({
          'campaign_id': campaign.id,
          'recipient_name': recName,
          'recipient_phone': rec.phone,
          'recipient_type': rec.type,
          'message_body': personalised,
          'status': success ? 'delivered' : 'failed',
          'error_message': errorMsg,
        });
      }

      // 4. Update SMS campaign record status & counts
      await _supabaseService.client.from('sms_campaigns').update({
        'status': 'sent',
        'delivered_count': delivered,
        'failed_count': failed,
        'sent_at': DateTime.now().toIso8601String(),
      }).eq('id', campaign.id);

      // Refresh data
      await loadSmsCampaigns();
      await refreshWalletBalance();
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
