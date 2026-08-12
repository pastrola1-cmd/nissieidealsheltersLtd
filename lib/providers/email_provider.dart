import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/services/email_service.dart';
import 'package:flutter/foundation.dart';

class EmailCampaignState {
  final List<EmailCampaign> campaigns;
  final bool isLoading;
  final String? errorMessage;

  const EmailCampaignState({
    this.campaigns = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EmailCampaignState copyWith({
    List<EmailCampaign>? campaigns,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EmailCampaignState(
      campaigns: campaigns ?? this.campaigns,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EmailCampaignNotifier extends Notifier<EmailCampaignState> {
  late SupabaseService _supabaseService;
  late EmailService _emailService;
  String? _loadedCompanyId;

  @override
  EmailCampaignState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _emailService = ref.watch(emailServiceProvider);

    final authState = ref.watch(authProvider);
    final companyId = authState.profile?.companyId;

    if (companyId != null) {
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() => loadEmailCampaigns());
        return const EmailCampaignState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const EmailCampaignState();
    }
  }

  /// Load all email campaigns for the company
  Future<void> loadEmailCampaigns() async {
    final authState = ref.read(authProvider);
    final companyId = authState.profile?.companyId;
    if (companyId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final response = await _supabaseService.client
          .from('email_campaigns')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((json) => EmailCampaign.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(campaigns: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Create and send an Email campaign, saving logs to Supabase
  Future<bool> sendCampaign({
    required String subject,
    required String body,
    required List<({String? name, String email, String? type})> recipients,
  }) async {
    final authState = ref.read(authProvider);
    final profile = authState.profile;
    final company = authState.company;
    if (profile == null || profile.companyId == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final provider = company?.emailProvider ?? 'simulation';

      // 1. Insert Email campaign record as pending/sending
      final campaignJson = await _supabaseService.client.from('email_campaigns').insert({
        'company_id': profile.companyId,
        'subject': subject,
        'body': body,
        'recipient_filter': null,
        'total_recipients': recipients.length,
        'delivered_count': 0,
        'failed_count': 0,
        'status': 'sending',
        'sent_by': profile.id,
      }).select().single();

      final campaign = EmailCampaign.fromJson(campaignJson);

      int delivered = 0;
      int failed = 0;

      // 2. Dispatch Email messages sequentially
      for (final rec in recipients) {
        final recName = rec.name ?? 'Contact';
        final firstName = recName.split(' ').first;
        final personalisedBody = body.replaceAll('{{name}}', firstName);

        bool success = false;
        String? errorMsg;

        if (provider == 'simulation') {
          // Simulation mode
          success = true;
          delivered++;
          debugPrint('Email Simulation: Mock sent to ${rec.email}');
        } else if (provider == 'brevo') {
          final apiKey = company?.brevoApiKey ?? '';
          final fromEmail = company?.brevoSenderEmail ?? company?.email ?? 'noreply@nissieidealshelters.com.ng';
          final fromName = company?.brevoSenderName ?? company?.name ?? 'Nissie Ideal Shelters';

          if (apiKey.isEmpty) {
            errorMsg = 'Brevo API key not configured';
            failed++;
          } else {
            success = await _emailService.sendBrevo(
              apiKey: apiKey,
              toEmail: rec.email,
              toName: recName,
              subject: subject,
              body: personalisedBody,
              fromEmail: fromEmail,
              fromName: fromName,
            );
            if (success) {
              delivered++;
            } else {
              failed++;
              errorMsg = 'Brevo API failed';
            }
          }
        } else if (provider == 'smtp') {
          final host = company?.smtpHost ?? '';
          final port = company?.smtpPort ?? 587;
          final user = company?.smtpUsername ?? '';
          final pass = company?.smtpPassword ?? '';
          final fromEmail = company?.smtpSenderEmail ?? company?.email ?? 'noreply@nissieidealshelters.com.ng';
          final fromName = company?.smtpSenderName ?? company?.name ?? 'Nissie Ideal Shelters';

          if (host.isEmpty || user.isEmpty || pass.isEmpty) {
            errorMsg = 'SMTP configuration is incomplete';
            failed++;
          } else {
            success = await _emailService.sendSmtp(
              smtpHost: host,
              smtpPort: port,
              smtpUsername: user,
              smtpPassword: pass,
              toEmail: rec.email,
              toName: recName,
              subject: subject,
              body: personalisedBody,
              fromEmail: fromEmail,
              fromName: fromName,
            );
            if (success) {
              delivered++;
            } else {
              failed++;
              errorMsg = 'SMTP relay connection failed';
            }
          }
        }

        // 3. Log individual message
        await _supabaseService.client.from('email_messages').insert({
          'campaign_id': campaign.id,
          'recipient_name': recName,
          'recipient_email': rec.email,
          'recipient_type': rec.type,
          'status': success ? 'delivered' : 'failed',
          'error_message': errorMsg,
        });

        // 100ms throttle to prevent API/socket rate issues
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 4. Update Email campaign record status & counts
      await _supabaseService.client.from('email_campaigns').update({
        'status': 'sent',
        'delivered_count': delivered,
        'failed_count': failed,
        'sent_at': DateTime.now().toIso8601String(),
      }).eq('id', campaign.id);

      // Refresh campaigns list
      await loadEmailCampaigns();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final emailCampaignProvider = NotifierProvider<EmailCampaignNotifier, EmailCampaignState>(() {
  return EmailCampaignNotifier();
});
