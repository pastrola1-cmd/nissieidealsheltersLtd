import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmsService {
  final http.Client _client;

  SmsService({http.Client? client}) : _client = client ?? http.Client();

  /// Sends a single SMS via Termii API.
  /// Returns true if Termii responds with a success status (e.g. 200 OK containing "ok" or message id).
  Future<bool> sendSms({
    required String to,
    required String message,
    required String apiKey,
    required String senderId,
  }) async {
    // Format recipient phone number to internationally accepted format without '+' prefix for Termii
    // e.g. +234 801 234 5678 -> 2348012345678
    final formattedTo = to.replaceAll(RegExp(r'\D'), '');

    try {
      final response = await _client.post(
        Uri.parse('https://v4.api.termii.com/api/sms/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': formattedTo,
          'from': senderId.isEmpty ? 'Nissie' : senderId,
          'sms': message,
          'type': 'plain',
          'channel': 'generic',
          'api_key': apiKey,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Termii response format usually has 'message_id' or 'message' field indicating success
        debugPrint('Termii SMS Success Response: ${response.body}');
        return data['message_id'] != null || (data['message'] as String?)?.toLowerCase() == 'successfully sent';
      } else {
        debugPrint('Termii SMS Error Response Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception while sending Termii SMS: $e');
      return false;
    }
  }

  /// Dispatches SMS messages to a list of phone numbers.
  /// If [apiKey] is null or empty, it runs in simulation mode, printing to console.
  Future<int> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? apiKey,
    String? senderId,
  }) async {
    if (phoneNumbers.isEmpty) return 0;
    
    final finalSenderId = senderId ?? 'Nissie';
    int successCount = 0;

    if (apiKey == null || apiKey.trim().isEmpty) {
      // Mock Fallback Simulation Mode
      debugPrint('--- SMS SIMULATION MODE ACTIVE (No Termii API Key Configured) ---');
      debugPrint('Sender ID: $finalSenderId');
      debugPrint('Message: "$message"');
      for (final phone in phoneNumbers) {
        debugPrint('Simulated SMS sent successfully to: $phone');
        successCount++;
        // Minor mock delay
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint('-----------------------------------------------------------------');
      return successCount;
    }

    // Live Termii Mode
    // Send requests in parallel chunks or sequentially. Sequential with minor delays is safer for API rate limits.
    for (final phone in phoneNumbers) {
      if (phone.trim().isEmpty) continue;
      
      final success = await sendSms(
        to: phone,
        message: message,
        apiKey: apiKey,
        senderId: finalSenderId,
      );
      
      if (success) {
        successCount++;
      }
      
      // Rate limiting precaution (Termii allows up to 100 requests per second, so 100ms throttle is safe)
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return successCount;
  }

  /// Checks the Termii account wallet balance.
  /// If [apiKey] is null or empty, it returns a mock balance.
  Future<({double balance, String currency, String? error})> checkBalance(String? apiKey) async {
    if (apiKey == null || apiKey.trim().isEmpty) {
      return (balance: 5000.0, currency: 'NGN', error: null);
    }
    try {
      final response = await _client.get(
        Uri.parse('https://v4.api.termii.com/api/get-balance?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balanceStr = data['balance']?.toString() ?? '0.0';
        final currency = data['currency']?.toString() ?? 'NGN';
        final balance = double.tryParse(balanceStr) ?? 0.0;
        return (balance: balance, currency: currency, error: null);
      } else {
        final data = jsonDecode(response.body);
        return (balance: 0.0, currency: 'NGN', error: data['message']?.toString() ?? 'Failed with status: ${response.statusCode}');
      }
    } catch (e) {
      return (balance: 0.0, currency: 'NGN', error: e.toString());
    }
  }
}

// Provider for SmsService
final smsServiceProvider = Provider<SmsService>((ref) {
  return SmsService();
});

