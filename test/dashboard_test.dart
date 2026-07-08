// ignore_for_file: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_state.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/providers/earnings_provider.dart';
import 'package:nissie_ideal_shelters/providers/inspection_provider.dart';
import 'package:nissie_ideal_shelters/providers/dashboard_provider.dart';

// Fake Notifier implementations to inject direct mock states
class FakeAuthNotifier extends AuthNotifier {
  final Profile? testProfile;
  FakeAuthNotifier(this.testProfile);

  @override
  AuthState build() {
    return AuthState(
      isAuthenticated: testProfile != null,
      profile: testProfile,
    );
  }
}

class FakePropertyNotifier extends PropertyNotifier {
  final List<Property> mockProperties;
  FakePropertyNotifier(this.mockProperties);

  @override
  PropertyState build() {
    return PropertyState(properties: mockProperties, isLoading: false);
  }
}

class FakePartnerNotifier extends PartnerNotifier {
  final List<Profile> mockPartners;
  FakePartnerNotifier(this.mockPartners);

  @override
  PartnerState build() {
    return PartnerState(partners: mockPartners, isLoading: false);
  }
}

class FakeLeadNotifier extends LeadNotifier {
  final List<Lead> mockLeads;
  FakeLeadNotifier(this.mockLeads);

  @override
  LeadState build() {
    return LeadState(leads: mockLeads, isLoading: false);
  }
}

class FakeEarningsNotifier extends EarningsNotifier {
  final List<Commission> mockCommissions;
  final List<Transaction> mockTransactions;
  final double mockBalance;

  FakeEarningsNotifier(this.mockCommissions, this.mockTransactions, this.mockBalance);

  @override
  EarningsState build() {
    return EarningsState(
      commissions: mockCommissions,
      transactions: mockTransactions,
      runningBalance: mockBalance,
      isLoading: false,
    );
  }
}

class FakeInspectionNotifier extends InspectionNotifier {
  final List<Inspection> mockInspections;
  FakeInspectionNotifier(this.mockInspections);

  @override
  InspectionState build() {
    return InspectionState(inspections: mockInspections, isLoading: false);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Statically initialize Supabase in-memory client for testing
    await sb.Supabase.initialize(
      url: 'https://wzotqxrmewmgqetpahrm.supabase.co',
      publishableKey: 'dummy-anon-key',
    );
  });

  group('Dashboard Aggregations & Calculations Tests', () {
    final adminProfile = Profile(
      id: 'admin-1',
      companyId: 'company-1',
      role: UserRole.admin,
      fullName: 'Admin User',
      phone: '12345',
      email: 'admin@test.com',
      status: PartnerStatus.approved,
      createdAt: DateTime.now(),
    );

    final partnerProfile = Profile(
      id: 'partner-1',
      companyId: 'company-1',
      role: UserRole.partner,
      fullName: 'Partner One',
      phone: '11111',
      email: 'partner1@test.com',
      referralCode: 'REF-P1',
      status: PartnerStatus.approved,
      createdAt: DateTime.now(),
    );

    final mockProperties = [
      Property(
        id: 'prop-1',
        companyId: 'company-1',
        title: 'Luxury Mansion',
        price: 500000000.0,
        status: PropertyStatus.available,
        images: [],
        commissionType: CommissionType.percentage,
        commissionValue: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Property(
        id: 'prop-2',
        companyId: 'company-1',
        title: 'Mini Flat',
        price: 50000000.0,
        status: PropertyStatus.reserved,
        images: [],
        commissionType: CommissionType.percentage,
        commissionValue: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final mockLeads = [
      Lead(
        id: 'lead-1',
        companyId: 'company-1',
        propertyId: 'prop-1',
        partnerId: 'partner-1',
        buyerName: 'Buyer One',
        buyerPhone: '1234',
        sourceChannel: 'whatsapp',
        stage: LeadStage.closed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Lead(
        id: 'lead-2',
        companyId: 'company-1',
        propertyId: 'prop-2',
        partnerId: 'partner-1',
        buyerName: 'Buyer Two',
        buyerPhone: '5678',
        sourceChannel: 'whatsapp',
        stage: LeadStage.negotiation,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final mockCommissions = [
      Commission(
        id: 'comm-1',
        companyId: 'company-1',
        leadId: 'lead-1',
        partnerId: 'partner-1',
        propertyId: 'prop-1',
        salePrice: 500000000.0,
        commissionAmount: 25000000.0,
        status: CommissionStatus.approved,
        createdAt: DateTime.now(),
      ),
      Commission(
        id: 'comm-2',
        companyId: 'company-1',
        leadId: 'lead-2',
        partnerId: 'partner-1',
        propertyId: 'prop-2',
        salePrice: 50000000.0,
        commissionAmount: 2500000.0,
        status: CommissionStatus.pending,
        createdAt: DateTime.now(),
      ),
    ];

    final mockInspections = [
      Inspection(
        id: 'insp-1',
        companyId: 'company-1',
        propertyId: 'prop-1',
        leadId: 'lead-1',
        buyerId: 'buyer-1',
        scheduledDate: '2026-06-12',
        scheduledTime: '10:00 AM',
        status: InspectionStatus.pending,
        createdAt: DateTime.now(),
      ),
    ];

    test('Admin Dashboard calculations', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(adminProfile)),
          propertyProvider.overrideWith(() => FakePropertyNotifier(mockProperties)),
          partnerProvider.overrideWith(() => FakePartnerNotifier([partnerProfile])),
          leadProvider.overrideWith(() => FakeLeadNotifier(mockLeads)),
          earningsProvider.overrideWith(() => FakeEarningsNotifier(mockCommissions, [], 0.0)),
          inspectionProvider.overrideWith(() => FakeInspectionNotifier(mockInspections)),
        ],
      );
      addTearDown(container.dispose);

      final dashboardState = container.read(dashboardProvider);

      // Assertions
      expect(dashboardState.totalProperties, 2);
      expect(dashboardState.activePartners, 1);
      expect(dashboardState.totalLeads, 2);
      
      // Conversion Rate: 1 closed out of 2 leads = 50%
      expect(dashboardState.conversionRate, 50.0);
      
      // Total Sales Value: sum of salePrice for all commissions (500M + 50M) = 550M
      expect(dashboardState.totalSalesValue, 550000000.0);
      
      // Commission Liabilities: pending + approved (25M + 2.5M) = 27.5M
      expect(dashboardState.commissionLiabilities, 27500000.0);
      
      // Lead stage distribution counts
      expect(dashboardState.leadStageDistribution[LeadStage.closed], 1);
      expect(dashboardState.leadStageDistribution[LeadStage.negotiation], 1);
      
      // Top Partners
      expect(dashboardState.topPartners.length, 1);
      expect(dashboardState.topPartners.first.partner.id, 'partner-1');
      expect(dashboardState.topPartners.first.conversionCount, 1);
      expect(dashboardState.topPartners.first.totalSalesValue, 550000000.0);
    });

    test('Partner Dashboard calculations', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(partnerProfile)),
          propertyProvider.overrideWith(() => FakePropertyNotifier(mockProperties)),
          partnerProvider.overrideWith(() => FakePartnerNotifier([partnerProfile])),
          leadProvider.overrideWith(() => FakeLeadNotifier(mockLeads)),
          earningsProvider.overrideWith(() => FakeEarningsNotifier(mockCommissions, [], 15000000.0)),
          inspectionProvider.overrideWith(() => FakeInspectionNotifier(mockInspections)),
        ],
      );
      addTearDown(container.dispose);

      final dashboardState = container.read(dashboardProvider);

      // Assertions
      expect(dashboardState.partnerTotalLeads, 2);
      expect(dashboardState.partnerActiveDeals, 1); // 1 is closed, so 1 active
      expect(dashboardState.partnerTotalEarned, 25000000.0); // Only comm-1 is approved
      expect(dashboardState.partnerAvailableBalance, 15000000.0);
      expect(dashboardState.partnerRecentLeads.length, 2);
    });
  });
}
