import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nissie_ideal_shelters/services/sms_service.dart';

void main() {
  group('Bulk SMS & SmartSMS Service Verification Tests', () {
    test('Format Nigerian phone numbers correctly to 234 format', () async {
      final recordedRequests = <http.Request>[];
      final mockClient = MockClient((request) async {
        recordedRequests.add(request);
        return http.Response(
          jsonEncode({
            'code': '1000',
            'comment': 'Successfully Sent',
            'successful': '1',
          }),
          200,
        );
      });

      final smsService = SmsService(client: mockClient);

      // Test 1: Standard 11 digit 080...
      final res1 = await smsService.sendSmsResult(
        to: '08031234567',
        message: 'Hello Buyer',
        apiKey: 'valid_smart_token',
        senderId: 'NIS LTD',
      );
      expect(res1.success, true);
      expect(recordedRequests.last.bodyFields['to'], '2348031234567');

      // Test 2: 10 digit 803...
      final res2 = await smsService.sendSmsResult(
        to: '8031234567',
        message: 'Hello Buyer',
        apiKey: 'valid_smart_token',
        senderId: 'NIS LTD',
      );
      expect(res2.success, true);
      expect(recordedRequests.last.bodyFields['to'], '2348031234567');

      // Test 3: International +234803...
      final res3 = await smsService.sendSmsResult(
        to: '+234 803 123 4567',
        message: 'Hello Buyer',
        apiKey: 'valid_smart_token',
        senderId: 'NIS LTD',
      );
      expect(res3.success, true);
      expect(recordedRequests.last.bodyFields['to'], '2348031234567');
    });

    test('sendBulkSms sends sequential requests to all recipient numbers', () async {
      final dispatches = <String>[];
      final mockClient = MockClient((request) async {
        dispatches.add(request.bodyFields['to']!);
        return http.Response(
          jsonEncode({
            'code': '1000',
            'comment': 'Successfully Sent',
            'successful': '1',
          }),
          200,
        );
      });

      final smsService = SmsService(client: mockClient);
      final phoneList = ['08011111111', '08022222222', '08033333333', '08044444444'];

      final sentCount = await smsService.sendBulkSms(
        phoneNumbers: phoneList,
        message: 'Dear Customer, your inspection is booked.',
        apiKey: 'valid_token',
        senderId: 'NIS LTD',
      );

      expect(sentCount, 4);
      expect(dispatches.length, 4);
      expect(dispatches, [
        '2348011111111',
        '2348022222222',
        '2348033333333',
        '2348044444444',
      ]);
    });

    test('SmartSMS balance check returns live wallet balance', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['token'], 'my_token');
        expect(request.url.queryParameters['checkbalance'], '1');
        return http.Response(
          jsonEncode({
            'balance': '4500.75',
          }),
          200,
        );
      });

      final smsService = SmsService(client: mockClient);
      final result = await smsService.checkBalance('my_token');

      expect(result.error, isNull);
      expect(result.balance, 4500.75);
      expect(result.currency, 'NGN');
    });

    test('SmartSMS error returns descriptive failure message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': '2905',
            'comment': 'Insufficient Units',
          }),
          200,
        );
      });

      final smsService = SmsService(client: mockClient);
      final result = await smsService.sendSmsResult(
        to: '08012345678',
        message: 'Hello',
        apiKey: 'token_no_units',
        senderId: 'NIS LTD',
      );

      expect(result.success, false);
    });
  });
}
