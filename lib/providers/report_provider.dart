import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late final SupabaseService _supabaseService;

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

    state = state.copyWith(isLoading: true);
    try {
      // First, compile real-time values in DB
      await _supabaseService.triggerReportCompilation(companyId, date);

      // Then read from compiled table
      final report = await _supabaseService.getDailyReport(companyId, date);
      if (report != null) {
        final cache = Map<String, DailyReport>.from(state.reportsCache);
        cache[dateStr] = report;
        state = ReportState(reportsCache: cache, isLoading: false);
        return report;
      }
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final reportProvider = NotifierProvider<ReportNotifier, ReportState>(() {
  return ReportNotifier();
});
