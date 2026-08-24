import 'package:flutter_test/flutter_test.dart';
import 'package:nissie_ideal_shelters/models/attendance_record.dart';

void main() {
  group('Staff Attendance & Anti-Cheat Logic Tests', () {
    test('AttendanceRecord correctly calculates active duration for open session', () {
      final clockInTime = DateTime.now().subtract(const Duration(hours: 3, minutes: 15));
      final record = AttendanceRecord(
        id: 'rec-1',
        companyId: 'comp-1',
        userId: 'user-1',
        workDate: DateTime.now(),
        clockInAt: clockInTime,
        workMode: 'office',
        status: 'clocked_in',
        createdAt: clockInTime,
        updatedAt: clockInTime,
      );

      expect(record.isClockedIn, isTrue);
      expect(record.clockOutAt, isNull);
      expect(record.duration.inMinutes, greaterThanOrEqualTo(194));
      expect(record.durationFormatted.contains('3h'), isTrue);
    });

    test('AttendanceRecord correctly formats duration for completed shift', () {
      final clockInTime = DateTime(2026, 8, 24, 8, 15);
      final clockOutTime = DateTime(2026, 8, 24, 17, 30); // 9h 15m
      final record = AttendanceRecord(
        id: 'rec-2',
        companyId: 'comp-1',
        userId: 'user-1',
        workDate: DateTime(2026, 8, 24),
        clockInAt: clockInTime,
        clockOutAt: clockOutTime,
        workMode: 'field',
        propertyName: 'Graceland Estate Epe',
        status: 'clocked_out',
        totalMinutes: 555,
        isLate: false,
        notes: 'Conducted 2 site inspections with prospective buyers.',
        createdAt: clockInTime,
        updatedAt: clockOutTime,
      );

      expect(record.isClockedIn, isFalse);
      expect(record.durationFormatted, '9h 15m');
      expect(record.workModeLabel, '🚗 Inspection: Graceland Estate Epe');
      expect(record.notes, contains('Conducted 2 site inspections'));
    });

    test('AttendanceRecord JSON serialization and deserialization works accurately', () {
      final rawJson = {
        'id': 'rec-3',
        'company_id': 'comp-uuid',
        'user_id': 'user-uuid',
        'work_date': '2026-08-24',
        'clock_in_at': '2026-08-24T08:45:00.000Z',
        'clock_out_at': '2026-08-24T17:00:00.000Z',
        'work_mode': 'remote',
        'status': 'clocked_out',
        'is_late': true,
        'location_lat': 6.5244,
        'location_lng': 3.3792,
        'location_name': 'Lagos Mainland',
        'notes': 'Online sales follow-ups and WhatsApp outreach',
        'total_minutes': 495,
        'profiles': {
          'full_name': 'Emmanuel Marketer',
          'email': 'emmanuel@nissie.com',
          'role': 'marketer',
        },
        'created_at': '2026-08-24T08:45:00.000Z',
        'updated_at': '2026-08-24T17:00:00.000Z',
      };

      final record = AttendanceRecord.fromJson(rawJson);
      expect(record.id, 'rec-3');
      expect(record.userId, 'user-uuid');
      expect(record.workMode, 'remote');
      expect(record.isLate, isTrue);
      expect(record.staffName, 'Emmanuel Marketer');
      expect(record.workModeLabel, '💻 Remote');
      expect(record.locationLat, 6.5244);
      expect(record.locationLng, 3.3792);

      final exported = record.toJson();
      expect(exported['id'], 'rec-3');
      expect(exported['work_mode'], 'remote');
      expect(exported['is_late'], isTrue);
    });
  });
}
