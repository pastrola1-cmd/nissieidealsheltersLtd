import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

final whatsAppServiceProvider = Provider<WhatsAppService>((ref) {
  return WhatsAppService(ref);
});

class WhatsAppService {
  final Ref _ref;

  WhatsAppService(this._ref);

  /// Sends an automated template message via WhatsApp Cloud API.
  Future<bool> sendTemplateMessage({
    required String companyId,
    required String leadId,
    required String recipientPhone,
    required String leadName,
    required String propertyTitle,
    required String brochureUrl,
    String? videoUrl,
  }) async {
    try {
      final supabaseService = _ref.read(supabaseServiceProvider);

      // 1. Fetch Company credentials
      final company = await supabaseService.getCompany(companyId);
      if (company == null || !company.whatsappEnabled) {
        debugPrint('WhatsApp automation is disabled or company not found.');
        return false;
      }

      final phoneId = company.whatsappPhoneNumberId ?? '';
      final accessToken = company.whatsappAccessToken ?? '';
      final templateName = company.whatsappTemplateName.isNotEmpty
          ? company.whatsappTemplateName
          : 'property_inquiry_auto';

      if (phoneId.isEmpty || accessToken.isEmpty) {
        debugPrint('WhatsApp credentials are not configured.');
        _logMessageFailure(
          companyId: companyId,
          leadId: leadId,
          recipientPhone: recipientPhone,
          templateName: templateName,
          error: 'Credentials missing in settings (Phone Number ID or Access Token is empty).',
        );
        return false;
      }

      // 2. Format recipient phone to E.164 (remove non-digits, replace leading 0 with 234 if length is 11)
      String cleanPhone = recipientPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
        cleanPhone = '234${cleanPhone.substring(1)}';
      }

      final url = Uri.parse('https://graph.facebook.com/v19.0/$phoneId/messages');

      // 3. Construct Meta Graph API template payload
      // Template expects:
      // - Header: document (brochure PDF URL)
      // - Body parameters: {{1}} (Lead Name), {{2}} (Property Name), {{3}} (Video Link)
      final payload = {
        'messaging_product': 'whatsapp',
        'to': cleanPhone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': 'en_US'},
          'components': [
            if (brochureUrl.isNotEmpty)
              {
                'type': 'header',
                'parameters': [
                  {
                    'type': 'document',
                    'document': {
                      'link': brochureUrl,
                      'filename': 'Property_Brochure.pdf',
                    }
                  }
                ]
              },
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': leadName},
                {'type': 'text', 'text': propertyTitle},
                {'type': 'text', 'text': videoUrl ?? 'Not Available'},
              ]
            }
          ]
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final messages = responseBody['messages'] as List?;
        final messageSid = messages != null && messages.isNotEmpty
            ? messages[0]['id'] as String?
            : null;

        // Log successful message in the DB
        await supabaseService.insert('whatsapp_messages', {
          'company_id': companyId,
          'lead_id': leadId,
          'message_sid': messageSid,
          'recipient_phone': cleanPhone,
          'template_name': templateName,
          'status': 'sent',
        });
        return true;
      } else {
        final errorMsg = responseBody['error']?['message'] as String? ?? 'HTTP ${response.statusCode}';
        debugPrint('WhatsApp API error response: ${response.body}');
        
        _logMessageFailure(
          companyId: companyId,
          leadId: leadId,
          recipientPhone: cleanPhone,
          templateName: templateName,
          error: errorMsg,
        );
        return false;
      }
    } catch (e) {
      debugPrint('Exception in sendTemplateMessage: $e');
      _logMessageFailure(
        companyId: companyId,
        leadId: leadId,
        recipientPhone: recipientPhone,
        templateName: 'unknown',
        error: e.toString(),
      );
      return false;
    }
  }

  /// Sends a raw test template message to confirm settings.
  Future<bool> sendTestMessage({
    required String phoneId,
    required String accessToken,
    required String templateName,
    required String recipientPhone,
  }) async {
    try {
      String cleanPhone = recipientPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
        cleanPhone = '234${cleanPhone.substring(1)}';
      }

      final url = Uri.parse('https://graph.facebook.com/v19.0/$phoneId/messages');
      final payload = {
        'messaging_product': 'whatsapp',
        'to': cleanPhone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': 'en_US'},
          'components': [
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': 'Test User'},
                {'type': 'text', 'text': 'Test Estate (Scale Wealth)'},
                {'type': 'text', 'text': 'https://youtube.com/watch?v=test'},
              ]
            }
          ]
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Test WhatsApp Message Exception: $e');
      return false;
    }
  }

  Future<void> _logMessageFailure({
    required String companyId,
    required String leadId,
    required String recipientPhone,
    required String templateName,
    required String error,
  }) async {
    try {
      final supabaseService = _ref.read(supabaseServiceProvider);
      await supabaseService.insert('whatsapp_messages', {
        'company_id': companyId,
        'lead_id': leadId,
        'recipient_phone': recipientPhone,
        'template_name': templateName,
        'status': 'failed',
        'error_message': error,
      });

      // Append error message to lead's notes so agency is aware of automated failure
      final lead = await supabaseService.getById('leads', leadId);
      if (lead != null) {
        final currentNotes = lead['notes'] as String? ?? '';
        final updatedNotes = '$currentNotes\n[WhatsApp Auto-Send Failed] Please follow up manually. Reason: $error';
        await supabaseService.update('leads', leadId, {
          'notes': updatedNotes,
        });
      }
    } catch (e) {
      debugPrint('Error logging message failure: $e');
    }
  }
}
