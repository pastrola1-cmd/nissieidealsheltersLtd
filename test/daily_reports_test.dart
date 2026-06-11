import 'package:flutter_test/flutter_test.dart';
import 'package:ppn/models/models.dart';

void main() {
  group('DailyReport & StaffPerformance Model Tests', () {
    test('StaffPerformance converts from/to JSON successfully', () {
      final json = {
        'profile_id': 'agent_uuid_123',
        'name': 'Temiloluwa Alao',
        'leads_handled': 15,
        'conversions': 3,
        'conversion_rate': 20.0,
      };

      final staff = StaffPerformance.fromJson(json);

      expect(staff.profileId, 'agent_uuid_123');
      expect(staff.name, 'Temiloluwa Alao');
      expect(staff.leadsHandled, 15);
      expect(staff.conversions, 3);
      expect(staff.conversionRate, 20.0);

      final outJson = staff.toJson();
      expect(outJson['profile_id'], 'agent_uuid_123');
      expect(outJson['name'], 'Temiloluwa Alao');
      expect(outJson['leads_handled'], 15);
      expect(outJson['conversions'], 3);
      expect(outJson['conversion_rate'], 20.0);
    });

    test('StaffPerformance handles nulls and fallback values safely', () {
      final json = {
        'profile_id': 'agent_uuid_456',
        'name': null,
        'leads_handled': null,
        'conversions': null,
        'conversion_rate': null,
      };

      final staff = StaffPerformance.fromJson(json);

      expect(staff.profileId, 'agent_uuid_456');
      expect(staff.name, 'Unknown Staff');
      expect(staff.leadsHandled, 0);
      expect(staff.conversions, 0);
      expect(staff.conversionRate, 0.0);
    });

    test('DailyReport serialization and deserialization handles nested models', () {
      final json = {
        'id': 'report_uuid_789',
        'company_id': 'company_uuid_abc',
        'report_date': '2026-06-11',
        'new_leads': 10,
        'follow_ups': 24,
        'inspections_booked': 5,
        'inspections_completed': 3,
        'closed_deals': 2,
        'revenue_today': 150000000.0,
        'top_staff': [
          {
            'profile_id': 'agent_1',
            'name': 'Kunle',
            'leads_handled': 6,
            'conversions': 1,
            'conversion_rate': 16.6,
          }
        ],
        'leads_by_stage': {
          'new': 4,
          'contacted': 3,
          'closed': 2,
          'lost': 1,
        }
      };

      final report = DailyReport.fromJson(json);

      expect(report.id, 'report_uuid_789');
      expect(report.companyId, 'company_uuid_abc');
      expect(report.reportDate.year, 2026);
      expect(report.reportDate.month, 6);
      expect(report.reportDate.day, 11);
      expect(report.newLeads, 10);
      expect(report.followUps, 24);
      expect(report.inspectionsBooked, 5);
      expect(report.inspectionsCompleted, 3);
      expect(report.closedDeals, 2);
      expect(report.revenueToday, 150000000.0);

      expect(report.topStaff.length, 1);
      expect(report.topStaff.first.name, 'Kunle');
      expect(report.topStaff.first.leadsHandled, 6);

      expect(report.leadsByStage['new'], 4);
      expect(report.leadsByStage['closed'], 2);

      final outJson = report.toJson();
      expect(outJson['id'], 'report_uuid_789');
      expect(outJson['company_id'], 'company_uuid_abc');
      expect(outJson['report_date'], '2026-06-11');
      expect(outJson['new_leads'], 10);
      expect(outJson['revenue_today'], 150000000.0);
      expect(outJson['top_staff'].length, 1);
      expect(outJson['leads_by_stage']['new'], 4);
    });
  });
}
