import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class ReportState {
  final Map<String, DailyReport> reportsCache; // maps ISO date -> report
  final bool isLoading;
  final String? errorMessage;

  const ReportState({
    this.reportsCache = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  ReportState copyWith({
    Map<String, DailyReport>? reportsCache,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ReportState(
      reportsCache: reportsCache ?? this.reportsCache,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ReportNotifier extends Notifier<ReportState> {
  late SupabaseService _supabaseService;

  @override
  ReportState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    return const ReportState();
  }

  Future<DailyReport?> fetchReportForDate(DateTime date) async {
    final companyId = ref.read(authProvider).profile?.companyId;
    if (companyId == null) return null;

    final dateStr = date.toIso8601String().split('T').first;
    if (state.reportsCache.containsKey(dateStr)) {
      return state.reportsCache[dateStr];
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Try DB RPC compilation first
      try {
        await _supabaseService.triggerReportCompilation(companyId, date);
        final report = await _supabaseService.getDailyReport(companyId, date);
        if (report != null) {
          final cache = Map<String, DailyReport>.from(state.reportsCache);
          cache[dateStr] = report;
          state = ReportState(reportsCache: cache, isLoading: false);
          return report;
        }
      } catch (_) {
        // Fallback to client compilation if RPC or table is missing
      }

      // 2. Direct client-side live aggregation
      final leadsRes = await _supabaseService.client
          .from('leads')
          .select()
          .eq('company_id', companyId);
      final allLeads = (leadsRes as List).map((e) => Lead.fromJson(e as Map<String, dynamic>)).toList();

      final newLeads = allLeads.where((l) {
        final d = l.createdAt;
        return d.year == date.year && d.month == date.month && d.day == date.day;
      }).length;

      final followUps = allLeads.where((l) {
        final d = l.updatedAt;
        return d.year == date.year && d.month == date.month && d.day == date.day;
      }).length;

      // Stage distribution
      final stageMap = <String, int>{};
      for (final l in allLeads) {
        final stageKey = l.stage.name;
        stageMap[stageKey] = (stageMap[stageKey] ?? 0) + 1;
      }

      // Staff performance
      final staffRes = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('company_id', companyId);
      final staffList = (staffRes as List).map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();

      final topStaff = staffList.map((s) {
        final handled = allLeads.where((l) => l.assignedAgentId == s.id).length;
        final closed = allLeads.where((l) => l.assignedAgentId == s.id && l.stage == LeadStage.closed).length;
        final rate = handled > 0 ? (closed / handled) * 100 : 0.0;
        return StaffPerformance(
          profileId: s.id,
          name: s.fullName ?? s.email ?? 'Staff',
          leadsHandled: handled,
          conversions: closed,
          conversionRate: rate,
        );
      }).toList()..sort((a, b) => b.conversions.compareTo(a.conversions));

      final liveReport = DailyReport(
        id: 'live-$dateStr',
        companyId: companyId,
        reportDate: date,
        newLeads: newLeads,
        followUps: followUps,
        inspectionsBooked: 0,
        inspectionsCompleted: 0,
        closedDeals: allLeads.where((l) => l.stage == LeadStage.closed).length,
        revenueToday: 0.0,
        topStaff: topStaff,
        leadsByStage: stageMap,
      );

      final cache = Map<String, DailyReport>.from(state.reportsCache);
      cache[dateStr] = liveReport;
      state = ReportState(reportsCache: cache, isLoading: false);
      return liveReport;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final reportProvider = NotifierProvider<ReportNotifier, ReportState>(() {
  return ReportNotifier();
});
