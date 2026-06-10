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
        'bank_name': 'Zenith Bank',
        'account_number': '1234567890',
        'account_name': 'John Partner',
        'created_at': '2026-06-10T10:00:00.000Z',
      };

      final profile = Profile.fromJson(json);
      expect(profile.id, 'user-id-123');
      expect(profile.role, UserRole.partner);
      expect(profile.status, PartnerStatus.approved);
      expect(profile.bankName, 'Zenith Bank');
      expect(profile.accountNumber, '1234567890');
      expect(profile.accountName, 'John Partner');

      final backToJson = profile.toJson();
      expect(backToJson['role'], 'partner');
      expect(backToJson['status'], 'approved');
      expect(backToJson['bank_name'], 'Zenith Bank');
      expect(backToJson['account_number'], '1234567890');
      expect(backToJson['account_name'], 'John Partner');
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

    test('Lead model tests', () {
      final json = {
        'id': 'lead-id-123',
        'company_id': 'company-id-123',
        'property_id': 'property-id-123',
        'partner_id': 'partner-id-123',
        'buyer_id': 'buyer-id-123',
        'buyer_name': 'Jane Buyer',
        'buyer_phone': '+2348098765432',
        'buyer_email': 'jane@buyer.com',
        'source_channel': 'whatsapp',
        'stage': 'new',
        'notes': 'Looking for a flat in Maitama',
        'created_at': '2026-06-10T10:00:00.000Z',
        'updated_at': '2026-06-10T10:00:00.000Z',
      };

      final lead = Lead.fromJson(json);
      expect(lead.id, 'lead-id-123');
      expect(lead.stage, LeadStage.newLead);
      expect(lead.notes, 'Looking for a flat in Maitama');

      final backToJson = lead.toJson();
      expect(backToJson['stage'], 'new');
      expect(backToJson['buyer_name'], 'Jane Buyer');
    });

    test('Inspection model tests', () {
      final json = {
        'id': 'inspection-id-123',
        'company_id': 'company-id-123',
        'property_id': 'property-id-123',
        'lead_id': 'lead-id-123',
        'buyer_id': 'buyer-id-123',
        'partner_id': 'partner-id-123',
        'scheduled_date': '2026-06-12',
        'scheduled_time': 'Morning',
        'status': 'pending',
        'notes': 'Please call 10 mins before arrival',
        'created_at': '2026-06-10T10:00:00.000Z',
      };

      final inspection = Inspection.fromJson(json);
      expect(inspection.id, 'inspection-id-123');
      expect(inspection.status, InspectionStatus.pending);
      expect(inspection.notes, 'Please call 10 mins before arrival');

      final backToJson = inspection.toJson();
      expect(backToJson['status'], 'pending');
      expect(backToJson['scheduled_date'], '2026-06-12');
    });

    test('Commission model tests', () {
      final json = {
        'id': 'commission-id-123',
        'company_id': 'company-id-123',
        'lead_id': 'lead-id-123',
        'partner_id': 'partner-id-123',
        'property_id': 'property-id-123',
        'sale_price': 100000000.0,
        'commission_rate': 5.0,
        'commission_amount': 5000000.0,
        'status': 'pending',
        'approved_by': null,
        'approved_at': null,
        'created_at': '2026-06-10T10:00:00.000Z',
      };

      final commission = Commission.fromJson(json);
      expect(commission.id, 'commission-id-123');
      expect(commission.status, CommissionStatus.pending);
      expect(commission.salePrice, 100000000.0);
      expect(commission.commissionAmount, 5000000.0);

      final backToJson = commission.toJson();
      expect(backToJson['status'], 'pending');
      expect(backToJson['commission_amount'], 5000000.0);
    });

    test('Transaction model tests', () {
      final json = {
        'id': 'transaction-id-123',
        'company_id': 'company-id-123',
        'partner_id': 'partner-id-123',
        'commission_id': 'commission-id-123',
        'type': 'credit',
        'amount': 5000000.0,
        'balance_after': 5000000.0,
        'description': 'Commission payout approved',
        'status': 'completed',
        'created_at': '2026-06-10T10:00:00.000Z',
      };

      final transaction = Transaction.fromJson(json);
      expect(transaction.id, 'transaction-id-123');
      expect(transaction.type, TransactionType.credit);
      expect(transaction.amount, 5000000.0);
      expect(transaction.balanceAfter, 5000000.0);
      expect(transaction.status, TransactionStatus.completed);

      final backToJson = transaction.toJson();
      expect(backToJson['type'], 'credit');
      expect(backToJson['amount'], 5000000.0);
      expect(backToJson['status'], 'completed');
    });
  });
}
