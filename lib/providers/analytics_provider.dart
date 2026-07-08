import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

enum AnalyticsPeriod { today, thisWeek, thisMonth, thisQuarter }

class MonthlyRevenue {
  final String monthLabel; // e.g., "Jan", "Feb"
  final double revenue;
  const MonthlyRevenue(this.monthLabel, this.revenue);
}

class AnalyticsState {
  final bool isLoading;
  final String? errorMessage;
  final AnalyticsPeriod period;
  final DateTime startDate;
  final DateTime endDate;

  // Scoped KPIs
  final int totalLeadsCurrent;
  final int totalLeadsPrevious;
  final double conversionRateCurrent;
  final double conversionRatePrevious;
  final double revenueCurrent;
  final double revenuePrevious;
  final int activeCampaignsCount;

  // Visualizations
  final Map<LeadStage, int> pipelineFunnel;
  final List<StaffPerformance> staffPerformance;
  final List<MonthlyRevenue> revenueTrend;

  const AnalyticsState({
    this.isLoading = false,
    this.errorMessage,
    this.period = AnalyticsPeriod.thisMonth,
    required this.startDate,
    required this.endDate,
    this.totalLeadsCurrent = 0,
    this.totalLeadsPrevious = 0,
    this.conversionRateCurrent = 0.0,
    this.conversionRatePrevious = 0.0,
    this.revenueCurrent = 0.0,
    this.revenuePrevious = 0.0,
    this.activeCampaignsCount = 0,
    this.pipelineFunnel = const {},
    this.staffPerformance = const [],
    this.revenueTrend = const [],
  });

  AnalyticsState copyWith({
    bool? isLoading,
    String? errorMessage,
    AnalyticsPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    int? totalLeadsCurrent,
    int? totalLeadsPrevious,
    double? conversionRateCurrent,
    double? conversionRatePrevious,
    double? revenueCurrent,
    double? revenuePrevious,
    int? activeCampaignsCount,
    Map<LeadStage, int>? pipelineFunnel,
    List<StaffPerformance>? staffPerformance,
    List<MonthlyRevenue>? revenueTrend,
  }) {
    return AnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalLeadsCurrent: totalLeadsCurrent ?? this.totalLeadsCurrent,
      totalLeadsPrevious: totalLeadsPrevious ?? this.totalLeadsPrevious,
      conversionRateCurrent: conversionRateCurrent ?? this.conversionRateCurrent,
      conversionRatePrevious: conversionRatePrevious ?? this.conversionRatePrevious,
      revenueCurrent: revenueCurrent ?? this.revenueCurrent,
      revenuePrevious: revenuePrevious ?? this.revenuePrevious,
      activeCampaignsCount: activeCampaignsCount ?? this.activeCampaignsCount,
      pipelineFunnel: pipelineFunnel ?? this.pipelineFunnel,
      staffPerformance: staffPerformance ?? this.staffPerformance,
      revenueTrend: revenueTrend ?? this.revenueTrend,
    );
  }
}

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  late final SupabaseService _supabaseService;

  @override
  AnalyticsState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    final now = DateTime.now();
    return AnalyticsState(
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  void setPeriod(AnalyticsPeriod period) {
    final now = DateTime.now();
    DateTime start = state.startDate;
    DateTime end = state.endDate;

    switch (period) {
      case AnalyticsPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case AnalyticsPeriod.thisWeek:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case AnalyticsPeriod.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case AnalyticsPeriod.thisQuarter:
        final quarter = ((now.month - 1) / 3).floor();
        start = DateTime(now.year, quarter * 3 + 1, 1);
        end = DateTime(now.year, (quarter + 1) * 3 + 1, 0, 23, 59, 59);
        break;
    }

    state = state.copyWith(period: period, startDate: start, endDate: end);
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null || profile.companyId == null) return;
    final companyId = profile.companyId!;

    state = state.copyWith(isLoading: true);
    try {
      final client = _supabaseService.client;
      final isManager = profile.role == UserRole.manager;

      // 1. Fetch campaigns count
      final campaignsList = await _supabaseService.getCampaigns(companyId);
      final activeCampaignsCount = campaignsList.length;

      // Calculate previous period dates for trends
      final periodDuration = state.endDate.difference(state.startDate);
      final prevStart = state.startDate.subtract(periodDuration);
      final prevEnd = state.startDate.subtract(const Duration(seconds: 1));

      // 2. Fetch Leads
      final leadsRes = await client.from('leads').select().eq('company_id', companyId);
      var allLeads = List<Map<String, dynamic>>.from(leadsRes).map((e) => Lead.fromJson(e)).toList();

      if (isManager) {
        // Scope manager to only see team leads (assigned to agent OR where manager supervising)
        // If profile.id is manager, we check leads assigned to agents whose manager_id = manager.id
        final staffQuery = await client.from('profiles').select().eq('company_id', companyId).eq('manager_id', profile.id);
        final subordinates = List<Map<String, dynamic>>.from(staffQuery).map((e) => Profile.fromJson(e)).toList();
        final subordinateIds = subordinates.map((s) => s.id).toSet();
        
        allLeads = allLeads.where((l) => subordinateIds.contains(l.assignedAgentId) || l.assignedAgentId == profile.id).toList();
      }

      final currentLeads = allLeads.where((l) => l.createdAt.isAfter(state.startDate) && l.createdAt.isBefore(state.endDate)).toList();
      final previousLeads = allLeads.where((l) => l.createdAt.isAfter(prevStart) && l.createdAt.isBefore(prevEnd)).toList();

      // 3. Fetch Commissions
      final commissionsList = await _supabaseService.getCommissions(companyId: companyId);
      
      // Scoping approved commissions based on period
      final currentApprovedComms = commissionsList.where((c) {
        if (c.status != CommissionStatus.approved || c.approvedAt == null) return false;
        if (isManager) {
          // Verify if commission's lead belongs to the manager's team
          final lead = allLeads.any((l) => l.id == c.leadId);
          if (!lead) return false;
        }
        return c.approvedAt!.isAfter(state.startDate) && c.approvedAt!.isBefore(state.endDate);
      }).toList();
      
      final prevApprovedComms = commissionsList.where((c) {
        if (c.status != CommissionStatus.approved || c.approvedAt == null) return false;
        if (isManager) {
          final lead = allLeads.any((l) => l.id == c.leadId);
          if (!lead) return false;
        }
        return c.approvedAt!.isAfter(prevStart) && c.approvedAt!.isBefore(prevEnd);
      }).toList();

      final revenueCurrent = currentApprovedComms.fold(0.0, (sum, c) => sum + c.salePrice);
      final revenuePrevious = prevApprovedComms.fold(0.0, (sum, c) => sum + c.salePrice);

      final currentConversions = currentApprovedComms.length;
      final prevConversions = prevApprovedComms.length;

      final conversionRateCurrent = currentLeads.isNotEmpty ? (currentConversions / currentLeads.length) * 100 : 0.0;
      final conversionRatePrevious = previousLeads.isNotEmpty ? (prevConversions / previousLeads.length) * 100 : 0.0;

      // Funnel Stage Distribution
      final funnel = <LeadStage, int>{};
      for (final stage in LeadStage.values) {
        funnel[stage] = currentLeads.where((l) => l.stage == stage).length;
      }

      // Staff Performance Calculation
      // If manager: show only team members under them. If admin: show all marketers/managers.
      var staffQuery = client.from('profiles').select().eq('company_id', companyId);
      if (isManager) {
        staffQuery = staffQuery.eq('manager_id', profile.id);
      } else {
        staffQuery = staffQuery.inFilter('role', ['manager', 'marketer']);
      }
      final staffProfilesRes = await staffQuery;
      final staffProfiles = List<Map<String, dynamic>>.from(staffProfilesRes).map((e) => Profile.fromJson(e)).toList();

      final staffList = staffProfiles.map((p) {
        final handledLeads = currentLeads.where((l) => l.assignedAgentId == p.id).toList();
        final handledCount = handledLeads.length;
        final handledIds = handledLeads.map((l) => l.id).toSet();
        
        final closedCount = currentApprovedComms.where((c) => handledIds.contains(c.leadId)).length;
        final rate = handledCount > 0 ? (closedCount / handledCount) * 100 : 0.0;

        return StaffPerformance(
          profileId: p.id,
          name: p.fullName ?? 'Unknown Agent',
          leadsHandled: handledCount,
          conversions: closedCount,
          conversionRate: rate,
        );
      }).toList();

      // Monthly Revenue Trend (Last 6 Months)
      final revenueTrend = <MonthlyRevenue>[];
      final monthFormat = DateFormat('MMM');
      for (int i = 5; i >= 0; i--) {
        final targetMonth = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
        final nextMonth = DateTime(targetMonth.year, targetMonth.month + 1, 1);

        final monthComms = commissionsList.where((c) {
          if (c.status != CommissionStatus.approved || c.approvedAt == null) return false;
          if (isManager) {
            final lead = allLeads.any((l) => l.id == c.leadId);
            if (!lead) return false;
          }
          return c.approvedAt!.isAfter(targetMonth) && c.approvedAt!.isBefore(nextMonth);
        });
        final sum = monthComms.fold(0.0, (s, c) => s + c.salePrice);
        revenueTrend.add(MonthlyRevenue(monthFormat.format(targetMonth), sum));
      }

      state = state.copyWith(
        isLoading: false,
        totalLeadsCurrent: currentLeads.length,
        totalLeadsPrevious: previousLeads.length,
        conversionRateCurrent: conversionRateCurrent,
        conversionRatePrevious: conversionRatePrevious,
        revenueCurrent: revenueCurrent,
        revenuePrevious: revenuePrevious,
        activeCampaignsCount: activeCampaignsCount,
        pipelineFunnel: funnel,
        staffPerformance: staffList,
        revenueTrend: revenueTrend,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final analyticsProvider = NotifierProvider<AnalyticsNotifier, AnalyticsState>(() {
  return AnalyticsNotifier();
});
