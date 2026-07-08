import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/performance_service.dart';

class PerformanceState {
  final List<CampaignBlockStat> blockStats;
  final bool isLoading;
  final String? errorMessage;

  const PerformanceState({
    this.blockStats = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PerformanceState copyWith({
    List<CampaignBlockStat>? blockStats,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PerformanceState(
      blockStats: blockStats ?? this.blockStats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PerformanceNotifier extends Notifier<PerformanceState> {
  late PerformanceService _performanceService;
  String? _loadedCompanyId;

  @override
  PerformanceState build() {
    _performanceService = ref.watch(performanceServiceProvider);

    final authState = ref.watch(authProvider);
    final companyId = authState.profile?.companyId;

    if (companyId != null) {
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() => loadBlockStats(companyId));
        return const PerformanceState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const PerformanceState();
    }
  }

  Future<void> loadBlockStats(String companyId) async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _performanceService.getBlockStats(companyId);
      state = PerformanceState(blockStats: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> recalculateScores() async {
    final companyId = _loadedCompanyId;
    if (companyId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      await _performanceService.recalculateBlockScores(companyId);
      final list = await _performanceService.getBlockStats(companyId);
      state = PerformanceState(blockStats: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleBlockActiveStatus(String blockId, bool isActive) async {
    final companyId = _loadedCompanyId;
    if (companyId == null) return;

    try {
      await _performanceService.updateBlockActiveStatus(companyId, blockId, isActive);
      
      // Update local state
      final updatedList = state.blockStats.map((stat) {
        if (stat.blockId == blockId) {
          return stat.copyWith(isActive: isActive);
        }
        return stat;
      }).toList();

      final exists = state.blockStats.any((s) => s.blockId == blockId);
      if (!exists) {
        updatedList.add(CampaignBlockStat(
          companyId: companyId,
          blockId: blockId,
          timesUsed: 0,
          leadsAttributed: 0,
          conversionsAttributed: 0,
          performanceScore: 1.0,
          isActive: isActive,
        ));
      }

      state = state.copyWith(blockStats: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final performanceProvider = NotifierProvider<PerformanceNotifier, PerformanceState>(() {
  return PerformanceNotifier();
});
