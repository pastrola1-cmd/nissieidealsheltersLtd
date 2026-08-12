import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmailService {
  final http.Client _client;

  EmailService({http.Client? client}) : _client = client ?? http.Client();

  /// Resolves the SMTP relay URL dynamically based on the browser's origin.
  String _getSmtpRelayUrl() {
    try {
      final baseUri = Uri.base;
      if (baseUri.host.isEmpty || baseUri.host == 'localhost') {
        // Fallback for local development
        return 'https://nissieidealshelters.com.ng/portal-new/send_email.php';
      }
      final scheme = baseUri.scheme.isEmpty ? 'https' : baseUri.scheme;
      final portPart = baseUri.hasPort ? ':${baseUri.port}' : '';
      // If we are in the subdirectory, match it
      final pathPart = baseUri.path.contains('portal-new') ? '/portal-new' : '';
      return '$scheme://${baseUri.host}$portPart$pathPart/send_email.php';
    } catch (_) {
      return 'https://nissieidealshelters.com.ng/portal-new/send_email.php';
    }
  }

  /// Sends an email via custom SMTP using the cPanel PHP relay script.
  Future<bool> sendSmtp({
    required String smtpHost,
    required int smtpPort,
    required String smtpUsername,
    required String smtpPassword,
    required String toEmail,
    required String toName,
    required String subject,
    required String body,
    required String fromEmail,
    required String fromName,
  }) async {
    final relayUrl = _getSmtpRelayUrl();
    try {
      final response = await _client.post(
        Uri.parse(relayUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'smtp_host': smtpHost,
          'smtp_port': smtpPort,
          'smtp_username': smtpUsername,
          'smtp_password': smtpPassword,
          'to_email': toEmail,
          'to_name': toName,
          'subject': subject,
          'body': body,
          'from_email': fromEmail,
          'from_name': fromName,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('SMTP Relay Success: ${response.body}');
        return true;
      } else {
        debugPrint('SMTP Relay Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception in SMTP Relay: $e');
      return false;
    }
  }

  /// Sends an email via Brevo HTTP API.
  Future<bool> sendBrevo({
    required String apiKey,
    required String toEmail,
    required String toName,
    required String subject,
    required String body,
    required String fromEmail,
    required String fromName,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('https://api.brevo.com/v3/smtp/email'),
        headers: {
          'accept': 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {
            'name': fromName.isEmpty ? 'Nissie Ideal Shelters' : fromName,
            'email': fromEmail,
          },
          'to': [
            {'email': toEmail, 'name': toName}
          ],
          'subject': subject,
          'htmlContent': body,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Brevo Email Success: ${response.body}');
        return true;
      } else {
        debugPrint('Brevo Email Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception sending via Brevo: $e');
      return false;
    }
  }
}

// Provider for EmailService
final emailServiceProvider = Provider<EmailService>((ref) {
  return EmailService();
});
