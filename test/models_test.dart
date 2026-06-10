import 'package:flutter_test/flutter_test.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';

void main() {
  group('Models serialization & deserialization tests', () {
    test('Company model tests', () {
      final json = {
        'id': 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        'name': 'Scalewealth Estate',
        'logo_url': 'https://example.com/logo.png',
        'email': 'info@scalewealth.com',
        'phone': '+2348000000000',
        'address': 'Abuja, Nigeria',
        'created_at': '2026-06-10T10:00:00.000Z',
      };

      final company = Company.fromJson(json);
      expect(company.id, 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6');
      expect(company.name, 'Scalewealth Estate');
      expect(company.logoUrl, 'https://example.com/logo.png');

      final backToJson = company.toJson();
      expect(backToJson['id'], 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6');
    });

    test('Profile model tests', () {
      final json = {
        'id': 'user-id-123',
        'company_id': 'company-id-123',
        'role': 'partner',
        'full_name': 'John Partner',
        'phone': '+2348012345678',
        'email': 'john@partner.com',
        'avatar_url': 'https://example.com/avatar.png',
        'referral_code': 'PPN-JP-A1B2',
        'status': 'approved',
        'created_at': '2026-06-10T10:00:00.000Z',
      };

      final profile = Profile.fromJson(json);
      expect(profile.id, 'user-id-123');
      expect(profile.role, UserRole.partner);
      expect(profile.status, PartnerStatus.approved);

      final backToJson = profile.toJson();
      expect(backToJson['role'], 'partner');
      expect(backToJson['status'], 'approved');
    });

    test('Property model tests', () {
      final json = {
        'id': 'property-id-123',
        'company_id': 'company-id-123',
        'title': '3 Bedroom Terrace',
        'description': 'Beautiful duplex',
        'location': 'Maitama, Abuja',
        'price': 150000000.0,
        'status': 'available',
        'images': ['https://example.com/img1.png'],
        'video_url': null,
        'assigned_partner_id': null,
        'created_by': null,
        'commission_type': 'percentage',
        'commission_value': 5.0,
        'created_at': '2026-06-10T10:00:00.000Z',
        'updated_at': '2026-06-10T10:00:00.000Z',
      };

      final property = Property.fromJson(json);
      expect(property.id, 'property-id-123');
      expect(property.price, 150000000.0);
      expect(property.status, PropertyStatus.available);
      expect(property.commissionType, CommissionType.percentage);

      final backToJson = property.toJson();
      expect(backToJson['commission_type'], 'percentage');
    });
  });
}
