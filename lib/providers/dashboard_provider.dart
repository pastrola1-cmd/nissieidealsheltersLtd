import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/providers/partner_provider.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/earnings_provider.dart';
import 'package:ppn/providers/inspection_provider.dart';
import 'package:ppn/core/enums/enums.dart';

class DashboardState {
  // Admin analytics
  final int totalProperties;
  final int activePartners;
  final int totalLeads;
  final double conversionRate;
  final double totalSalesValue;
  final double commissionLiabilities;
  final Map<LeadStage, int> leadStageDistribution;
  final List<PartnerPerformance> topPartners;
  final List<ActivityLog> recentActivities;

  // Partner analytics
  final int partnerTotalLeads;
  final int partnerActiveDeals;
  final double partnerTotalEarned;
  final double partnerAvailableBalance;
  final Map<String, int> partnerLeadsOverTime; // "YYYY-MM" -> count
  final List<Lead> partnerRecentLeads;

  // Buyer analytics
  final List<Inspection> buyerUpcomingInspections;
  final int buyerAvailablePropertiesCount;

  final bool isLoading;
  final String? errorMessage;

  const DashboardState({
    this.totalProperties = 0,
    this.activePartners = 0,
    this.totalLeads = 0,
    this.conversionRate = 0.0,
    this.totalSalesValue = 0.0,
    this.commissionLiabilities = 0.0,
    this.leadStageDistribution = const {},
    this.topPartners = const [],
    this.recentActivities = const [],
    this.partnerTotalLeads = 0,
    this.partnerActiveDeals = 0,
    this.partnerTotalEarned = 0.0,
    this.partnerAvailableBalance = 0.0,
    this.partnerLeadsOverTime = const {},
    this.partnerRecentLeads = const [],
    this.buyerUpcomingInspections = const [],
    this.buyerAvailablePropertiesCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  DashboardState copyWith({
    int? totalProperties,
    int? activePartners,
    int? totalLeads,
    double? conversionRate,
    double? totalSalesValue,
    double? commissionLiabilities,
    Map<LeadStage, int>? leadStageDistribution,
    List<PartnerPerformance>? topPartners,
    List<ActivityLog>? recentActivities,
    int? partnerTotalLeads,
    int? partnerActiveDeals,
    double? partnerTotalEarned,
    double? partnerAvailableBalance,
    Map<String, int>? partnerLeadsOverTime,
    List<Lead>? partnerRecentLeads,
    List<Inspection>? buyerUpcomingInspections,
    int? buyerAvailablePropertiesCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      totalProperties: totalProperties ?? this.totalProperties,
      activePartners: activePartners ?? this.activePartners,
      totalLeads: totalLeads ?? this.totalLeads,
      conversionRate: conversionRate ?? this.conversionRate,
      totalSalesValue: totalSalesValue ?? this.totalSalesValue,
      commissionLiabilities: commissionLiabilities ?? this.commissionLiabilities,
      leadStageDistribution: leadStageDistribution ?? this.leadStageDistribution,
      topPartners: topPartners ?? this.topPartners,
      recentActivities: recentActivities ?? this.recentActivities,
      partnerTotalLeads: partnerTotalLeads ?? this.partnerTotalLeads,
      partnerActiveDeals: partnerActiveDeals ?? this.partnerActiveDeals,
      partnerTotalEarned: partnerTotalEarned ?? this.partnerTotalEarned,
      partnerAvailableBalance: partnerAvailableBalance ?? this.partnerAvailableBalance,
      partnerLeadsOverTime: partnerLeadsOverTime ?? this.partnerLeadsOverTime,
      partnerRecentLeads: partnerRecentLeads ?? this.partnerRecentLeads,
      buyerUpcomingInspections: buyerUpcomingInspections ?? this.buyerUpcomingInspections,
      buyerAvailablePropertiesCount: buyerAvailablePropertiesCount ?? this.buyerAvailablePropertiesCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PartnerPerformance {
  final Profile partner;
  final int conversionCount;
  final double totalSalesValue;

  const PartnerPerformance({
    required this.partner,
    required this.conversionCount,
    required this.totalSalesValue,
  });
}

enum ActivityType {
  leadCreated,
  commissionPending,
  commissionApproved,
  commissionDisputed,
  inspectionBooked,
}

class ActivityLog {
  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  const ActivityLog({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    if (profile == null) {
      return const DashboardState();
    }

    final propertiesState = ref.watch(propertyProvider);
    final partnersState = ref.watch(partnerProvider);
    final leadsState = ref.watch(leadProvider);
    final earningsState = ref.watch(earningsProvider);
    final inspectionsState = ref.watch(inspectionProvider);

    final isLoading = propertiesState.isLoading ||
        partnersState.isLoading ||
        leadsState.isLoading ||
        earningsState.isLoading ||
        inspectionsState.isLoading;

    final errorMessage = propertiesState.errorMessage ??
        partnersState.errorMessage ??
        leadsState.errorMessage ??
        earningsState.errorMessage ??
        inspectionsState.errorMessage;

    final properties = propertiesState.properties;
    final partners = partnersState.partners;
    final leads = leadsState.leads;
    final commissions = earningsState.commissions;
    final inspections = inspectionsState.inspections;

    // Helper map to lookup property titles
    final propertiesMap = {for (var p in properties) p.id: p};

    // Helper map to lookup partner names
    final partnersMap = {for (var p in partners) p.id: p};

    // ── 1. Admin Metrics ──
    final totalProperties = properties.length;
    final activePartners = partners.where((p) => p.status == PartnerStatus.approved).length;
    final totalLeads = leads.length;

    final closedLeadsCount = leads.where((l) => l.stage == LeadStage.closed).length;
    final conversionRate = totalLeads == 0 ? 0.0 : (closedLeadsCount / totalLeads) * 100;

    // Total sales value: sum of salePrice for all commission records (representing closed leads)
    final totalSalesValue = commissions.fold<double>(0.0, (sum, c) => sum + c.salePrice);

    // Commission liabilities: sum of commissionAmount for all pending + approved commission records
    final commissionLiabilities = commissions
        .where((c) => c.status == CommissionStatus.pending || c.status == CommissionStatus.approved)
        .fold<double>(0.0, (sum, c) => sum + c.commissionAmount);

    // Lead stage distribution count
    final leadStageDistribution = <LeadStage, int>{};
    for (var stage in LeadStage.values) {
      leadStageDistribution[stage] = leads.where((l) => l.stage == stage).length;
    }

    // Top partners by conversion count (closed leads)
    final partnerConversions = <String, int>{};
    final partnerSalesValue = <String, double>{};
    for (var lead in leads.where((l) => l.stage == LeadStage.closed)) {
      if (lead.partnerId != null) {
        partnerConversions[lead.partnerId!] = (partnerConversions[lead.partnerId!] ?? 0) + 1;
      }
    }
    for (var comm in commissions) {
      if (comm.partnerId != null) {
        partnerSalesValue[comm.partnerId!] = (partnerSalesValue[comm.partnerId!] ?? 0.0) + comm.salePrice;
      }
    }

    final topPartners = partners
        .where((p) => p.status == PartnerStatus.approved && (partnerConversions[p.id] ?? 0) > 0)
        .map((p) => PartnerPerformance(
              partner: p,
              conversionCount: partnerConversions[p.id] ?? 0,
              totalSalesValue: partnerSalesValue[p.id] ?? 0.0,
            ))
        .toList();
    // Sort by conversion count descending, then by sales value descending
    topPartners.sort((a, b) {
      final cmp = b.conversionCount.compareTo(a.conversionCount);
      if (cmp != 0) return cmp;
      return b.totalSalesValue.compareTo(a.totalSalesValue);
    });

    // Recent Activity Feed (combining leads, commissions, and inspections ordered descending by date)
    final recentActivities = <ActivityLog>[];

    for (var lead in leads) {
      final propTitle = propertiesMap[lead.propertyId]?.title ?? 'Property';
      recentActivities.add(ActivityLog(
        id: 'lead_${lead.id}',
        type: ActivityType.leadCreated,
        title: 'New Lead: ${lead.buyerName}',
        subtitle: 'Referred for $propTitle via ${lead.sourceChannel}',
        timestamp: lead.createdAt,
      ));
    }

    for (var comm in commissions) {
      final propTitle = propertiesMap[comm.propertyId]?.title ?? 'Property';
      final partnerName = partnersMap[comm.partnerId]?.fullName ?? 'Partner';
      final formattedAmount = '₦${comm.commissionAmount.toStringAsFixed(2)}';
      
      ActivityType type;
      String actionText;
      if (comm.status == CommissionStatus.approved) {
        type = ActivityType.commissionApproved;
        actionText = 'Approved';
      } else if (comm.status == CommissionStatus.disputed) {
        type = ActivityType.commissionDisputed;
        actionText = 'Disputed';
      } else {
        type = ActivityType.commissionPending;
        actionText = 'Pending';
      }

      recentActivities.add(ActivityLog(
        id: 'comm_${comm.id}_${comm.status.value}',
        type: type,
        title: 'Commission $actionText: $formattedAmount',
        subtitle: 'For $propTitle referred by $partnerName',
        timestamp: comm.createdAt,
      ));
    }

    for (var insp in inspections) {
      final propTitle = propertiesMap[insp.propertyId]?.title ?? 'Property';
      recentActivities.add(ActivityLog(
        id: 'insp_${insp.id}',
        type: ActivityType.inspectionBooked,
        title: 'Inspection Scheduled',
        subtitle: '$propTitle on ${insp.scheduledDate} at ${insp.scheduledTime}',
        timestamp: insp.createdAt,
      ));
    }

    // Sort recent activities descending by timestamp
    recentActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Limit to 20 activities
    final limitedActivities = recentActivities.take(20).toList();


    // ── 2. Partner Metrics ──
    final partnerLeads = leads.where((l) => l.partnerId == profile.id).toList();
    final partnerTotalLeads = partnerLeads.length;
    final partnerActiveDeals = partnerLeads.where((l) => l.stage != LeadStage.closed && l.stage != LeadStage.lost).length;
    
    final partnerCommissions = commissions.where((c) => c.partnerId == profile.id).toList();
    final partnerTotalEarned = partnerCommissions
        .where((c) => c.status == CommissionStatus.approved || c.status == CommissionStatus.paid)
        .fold<double>(0.0, (sum, c) => sum + c.commissionAmount);

    final partnerAvailableBalance = earningsState.runningBalance;

    // Leads generated over time grouped by year-month
    final partnerLeadsOverTime = <String, int>{};
    for (var lead in partnerLeads) {
      final yearMonth = '${lead.createdAt.year}-${lead.createdAt.month.toString().padLeft(2, '0')}';
      partnerLeadsOverTime[yearMonth] = (partnerLeadsOverTime[yearMonth] ?? 0) + 1;
    }

    // Partner recent referred leads (sort by createdAt descending, take 5)
    final partnerRecentLeadsList = List<Lead>.from(partnerLeads);
    partnerRecentLeadsList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final partnerRecentLeads = partnerRecentLeadsList.take(5).toList();


    // ── 3. Buyer Metrics ──
    // Upcoming inspections for buyer (status is pending or confirmed, scheduled in the future/present)
    final buyerUpcomingInspections = inspections
        .where((i) => i.buyerId == profile.id && (i.status == InspectionStatus.pending || i.status == InspectionStatus.confirmed))
        .toList();

    // Available properties count
    final buyerAvailablePropertiesCount = properties.where((p) => p.status == PropertyStatus.available).length;

    return DashboardState(
      totalProperties: totalProperties,
      activePartners: activePartners,
      totalLeads: totalLeads,
      conversionRate: conversionRate,
      totalSalesValue: totalSalesValue,
      commissionLiabilities: commissionLiabilities,
      leadStageDistribution: leadStageDistribution,
      topPartners: topPartners,
      recentActivities: limitedActivities,
      partnerTotalLeads: partnerTotalLeads,
      partnerActiveDeals: partnerActiveDeals,
      partnerTotalEarned: partnerTotalEarned,
      partnerAvailableBalance: partnerAvailableBalance,
      partnerLeadsOverTime: partnerLeadsOverTime,
      partnerRecentLeads: partnerRecentLeads,
      buyerUpcomingInspections: buyerUpcomingInspections,
      buyerAvailablePropertiesCount: buyerAvailablePropertiesCount,
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }

  Future<void> refresh() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    await Future.wait([
      ref.read(propertyProvider.notifier).loadProperties(profile.companyId ?? ''),
      if (profile.role == UserRole.admin || profile.role == UserRole.platformAdmin)
        ref.read(partnerProvider.notifier).loadPartners(profile.companyId),
      ref.read(leadProvider.notifier).loadLeads(),
      ref.read(earningsProvider.notifier).loadEarnings(),
      ref.read(inspectionProvider.notifier).loadInspections(),
    ]);
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});
