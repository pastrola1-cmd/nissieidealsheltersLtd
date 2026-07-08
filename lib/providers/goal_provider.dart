import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalProgress {
  final Goal goal;
  final double currentValue;
  final double targetValue;
  final double progressPercent;
  final String pace; // 'ahead', 'on_track', 'behind', 'critical'
  final double projectedValue;
  final String? suggestion;

  const GoalProgress({
    required this.goal,
    required this.currentValue,
    required this.targetValue,
    required this.progressPercent,
    required this.pace,
    required this.projectedValue,
    this.suggestion,
  });
}

class GoalState {
  final List<Goal> goals;
  final Map<String, GoalProgress> progressCache; // key: goalId
  final bool isLoading;
  final String? errorMessage;

  const GoalState({
    this.goals = const [],
    this.progressCache = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  GoalState copyWith({
    List<Goal>? goals,
    Map<String, GoalProgress>? progressCache,
    bool? isLoading,
    String? errorMessage,
  }) {
    return GoalState(
      goals: goals ?? this.goals,
      progressCache: progressCache ?? this.progressCache,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class GoalNotifier extends Notifier<GoalState> {
  late final SupabaseService _supabaseService;

  @override
  GoalState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    return const GoalState();
  }

  Future<void> fetchGoals() async {
    final companyId = ref.read(authProvider).profile?.companyId;
    if (companyId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final goalsList = await _supabaseService.getGoals(companyId: companyId);
      state = state.copyWith(goals: goalsList, isLoading: false);
      
      // Prefetch progress for all loaded goals
      for (final goal in goalsList) {
        await computeProgress(goal);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addGoal(Goal goal) async {
    state = state.copyWith(isLoading: true);
    try {
      final newGoal = await _supabaseService.createGoal(goal.toJson());
      final updatedGoals = [...state.goals, newGoal];
      state = state.copyWith(goals: updatedGoals, isLoading: false);
      await computeProgress(newGoal);
    } on PostgrestException catch (e) {
      String msg = e.message;
      if (e.code == '23505') {
        msg = 'A goal for this metric, horizon, and period already exists.';
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      throw Exception(msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deleteGoal(String goalId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.delete('goals', goalId);
      final updatedGoals = state.goals.where((g) => g.id != goalId).toList();
      final cache = Map<String, GoalProgress>.from(state.progressCache)..remove(goalId);
      state = state.copyWith(goals: updatedGoals, progressCache: cache, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<GoalProgress> computeProgress(Goal goal) async {
    final client = _supabaseService.client;
    final startStr = goal.periodStart.toIso8601String().split('T').first;
    final endStr = goal.periodEnd.toIso8601String().split('T').first;

    double currentValue = 0.0;

    if (goal.metric == 'leads') {
      final res = await client
          .from('leads')
          .select('id')
          .eq('company_id', goal.companyId)
          .gte('created_at', '${startStr}T00:00:00')
          .lte('created_at', '${endStr}T23:59:59');
      currentValue = (res as List).length.toDouble();
    } else if (goal.metric == 'closings') {
      final res = await client
          .from('commissions')
          .select('id')
          .eq('company_id', goal.companyId)
          .eq('status', 'approved')
          .gte('approved_at', '${startStr}T00:00:00')
          .lte('approved_at', '${endStr}T23:59:59');
      currentValue = (res as List).length.toDouble();
    }
 else if (goal.metric == 'revenue') {
      final res = await client
          .from('commissions')
          .select('sale_price')
          .eq('company_id', goal.companyId)
          .eq('status', 'approved')
          .gte('approved_at', '${startStr}T00:00:00')
          .lte('approved_at', '${endStr}T23:59:59');
      
      final sales = List<Map<String, dynamic>>.from(res as List);
      currentValue = sales.fold(0.0, (sum, item) => sum + (item['sale_price'] as num).toDouble());
    }

    final now = DateTime.now();
    DateTime progressTime = now;
    if (progressTime.isBefore(goal.periodStart)) {
      progressTime = goal.periodStart;
    } else if (progressTime.isAfter(goal.periodEnd)) {
      progressTime = goal.periodEnd;
    }

    final daysElapsed = progressTime.difference(goal.periodStart).inDays + 1;
    final daysTotal = goal.periodEnd.difference(goal.periodStart).inDays + 1;

    final expectedProgress = (daysElapsed / daysTotal) * goal.targetValue;
    final progressPercent = goal.targetValue > 0 ? (currentValue / goal.targetValue) * 100 : 0.0;

    String pace;
    if (currentValue >= expectedProgress * 1.1) {
      pace = 'ahead';
    } else if (currentValue >= expectedProgress * 0.9) {
      pace = 'on_track';
    } else if (currentValue >= expectedProgress * 0.6) {
      pace = 'behind';
    } else {
      pace = 'critical';
    }

    final projectedValue = daysElapsed > 0 ? (currentValue / daysElapsed) * daysTotal : 0.0;

    String? suggestion;
    if (pace == 'behind' || pace == 'critical') {
      if (goal.metric == 'leads') {
        final remaining = (expectedProgress - currentValue).ceil();
        suggestion = 'Increase marketing campaigns. Generate $remaining more leads this week to get back on track.';
      } else if (goal.metric == 'closings') {
        final negCountRes = await client
            .from('leads')
            .select('id')
            .eq('company_id', goal.companyId)
            .eq('stage', 'negotiation');
        final count = (negCountRes as List).length;
        suggestion = 'Focus on converting existing leads. You have $count leads in negotiation stage.';
      } else if (goal.metric == 'revenue') {
        suggestion = 'Prioritize high-value properties. Promote listings with larger commission yields.';
      }
    }

    final progress = GoalProgress(
      goal: goal,
      currentValue: currentValue,
      targetValue: goal.targetValue,
      progressPercent: progressPercent,
      pace: pace,
      projectedValue: projectedValue,
      suggestion: suggestion,
    );

    final cache = Map<String, GoalProgress>.from(state.progressCache);
    cache[goal.id] = progress;
    state = state.copyWith(progressCache: cache);

    return progress;
  }
}

final goalProvider = NotifierProvider<GoalNotifier, GoalState>(() {
  return GoalNotifier();
});
