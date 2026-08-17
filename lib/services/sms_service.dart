import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmsService {
  final http.Client _client;

  SmsService({http.Client? client}) : _client = client ?? http.Client();

  /// Sends a single SMS via Termii API.
  /// Returns true if Termii responds with a success status (e.g. 200 OK containing "ok" or message id).
  Future<({bool success, String message})> sendSmsResult({
    required String to,
    required String message,
    required String apiKey,
    required String senderId,
  }) async {
    String formattedTo = to.replaceAll(RegExp(r'\D'), '');
    if (formattedTo.startsWith('0') && formattedTo.length == 11) {
      formattedTo = '234${formattedTo.substring(1)}';
    } else if (formattedTo.length == 10 && (formattedTo.startsWith('7') || formattedTo.startsWith('8') || formattedTo.startsWith('9'))) {
      formattedTo = '234$formattedTo';
    }

    final fromSender = senderId.isEmpty ? 'NIS LTD' : senderId;

    // ── 0. Web Proxy Priority (Bypasses Browser CORS) ──
    if (kIsWeb) {
      try {
        final proxyUri = Uri.base.resolve('sms_proxy.php');
        final response = await _client.post(
          proxyUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'send',
            'api_key': apiKey,
            'to': formattedTo,
            'from': fromSender,
            'sms': message,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            return (success: true, message: data['message']?.toString() ?? 'Delivered via Gateway');
          }
        }
      } catch (e) {
        debugPrint('Web SMS Proxy note: $e');
      }
    }

    // ── 1. SmartSMS Solutions Direct API Gateway (Mobile / Non-Web) ──
    try {
      final smartSmsUri = Uri.parse('https://smartsmssolutions.com/api/json.php');
      final response = await _client.post(
        smartSmsUri,
        body: {
          'token': apiKey,
          'sender': fromSender,
          'to': formattedTo,
          'message': message,
          'routing': '3', // Corporate DND Route
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final code = data['code']?.toString();
        final comment = data['comment']?.toString();
        if (code == '1000' || data['status'] == 'OK' || data['successful'] != null || (code != null && code.startsWith('100'))) {
          return (success: true, message: 'Delivered via SmartSMS');
        }
        if (comment != null && comment.toLowerCase().contains('success')) {
          return (success: true, message: 'Delivered via SmartSMS');
        }
      }
    } catch (e) {
      // Dual-Method Fallback: Retry via HTTP GET if POST encounters network restrictions
      try {
        final encodedMsg = Uri.encodeComponent(message);
        final encodedSender = Uri.encodeComponent(fromSender);
        final getUri = Uri.parse(
          'https://smartsmssolutions.com/api/json.php?token=$apiKey&sender=$encodedSender&to=$formattedTo&message=$encodedMsg&routing=3',
        );
        final getResponse = await _client.get(getUri).timeout(const Duration(seconds: 15));
        if (getResponse.statusCode == 200) {
          final data = jsonDecode(getResponse.body);
          final code = data['code']?.toString();
          final comment = data['comment']?.toString();
          if (code == '1000' || data['status'] == 'OK' || data['successful'] != null || (code != null && code.startsWith('100'))) {
            return (success: true, message: 'Delivered via SmartSMS');
          }
          if (comment != null && comment.toLowerCase().contains('success')) {
            return (success: true, message: 'Delivered via SmartSMS');
          }
        }
        return (success: false, message: 'SmartSMS Solutions error: Check API Token in Settings');
      } catch (ge) {
        return (success: false, message: 'SmartSMS Gateway unreachable: $ge');
      }
    }

    return (success: false, message: 'SmartSMS Solutions dispatch failed. Please check your API Token in Settings.');
  }

  Future<bool> sendSms({
    required String to,
    required String message,
    required String apiKey,
    required String senderId,
  }) async {
    final res = await sendSmsResult(
      to: to,
      message: message,
      apiKey: apiKey,
      senderId: senderId,
    );
    return res.success;
  }

  /// Dispatches SMS messages to a list of phone numbers via SmartSMS Solutions.
  Future<int> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? apiKey,
    String? senderId,
  }) async {
    if (phoneNumbers.isEmpty) return 0;
    
    final finalSenderId = (senderId != null && senderId.trim().isNotEmpty) ? senderId.trim() : 'NIS LTD';
    int successCount = 0;

    if (apiKey == null || apiKey.trim().isEmpty) {
      debugPrint('--- SMS SIMULATION MODE ACTIVE ---');
      for (final phone in phoneNumbers) {
        successCount++;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return successCount;
    }

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
      
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return successCount;
  }

  /// Checks the SmartSMS Solutions wallet balance.
  Future<({double balance, String currency, String? error})> checkBalance(String? apiKey) async {
    if (apiKey == null || apiKey.trim().isEmpty) {
      return (balance: 0.0, currency: 'NGN', error: 'No API Key configured');
    }

    // ── 0. Web Proxy Priority ──
    if (kIsWeb) {
      try {
        final proxyUri = Uri.base.resolve('sms_proxy.php?api_key=$apiKey');
        final response = await _client.get(proxyUri).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['balance'] != null) {
            final balanceRaw = data['balance'];
            final double balance = (balanceRaw is num) ? balanceRaw.toDouble() : double.tryParse(balanceRaw?.toString() ?? '0') ?? 0.0;
            return (balance: balance, currency: data['currency']?.toString() ?? 'NGN', error: null);
          }
        }
      } catch (e) {
        debugPrint('Web SMS Balance Proxy note: $e');
      }
    }

    // ── 1. Direct SmartSMS Solutions Balance Check ──
    try {
      final smartSmsUri = Uri.parse('https://app.smartsmssolutions.com/io/api/client/v1/balance/?token=$apiKey');
      final response = await _client.get(smartSmsUri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final trimmed = response.body.trim();
        final parsed = double.tryParse(trimmed);
        if (parsed != null) {
          return (balance: parsed, currency: 'NGN', error: null);
        }
        final data = jsonDecode(response.body);
        if (data['balance'] != null) {
          final balanceRaw = data['balance'];
          final double balance = (balanceRaw is num) ? balanceRaw.toDouble() : double.tryParse(balanceRaw?.toString() ?? '0') ?? 0.0;
          return (balance: balance, currency: 'NGN', error: null);
        }
      }
    } catch (_) {}

    return (balance: 0.0, currency: 'NGN', error: 'Could not reach SmartSMS Solutions server');
  }
}

// Provider for SmsService
final smsServiceProvider = Provider<SmsService>((ref) {
  return SmsService();
});

