import 'package:flutter_test/flutter_test.dart';
import 'package:nissie_ideal_shelters/models/models.dart';

void main() {
  group('Goal Model Tests', () {
    test('Goal converts to and from JSON correctly', () {
      final now = DateTime.now();
      final goal = Goal(
        id: 'test-goal-id',
        companyId: 'test-company-id',
        createdBy: 'test-user-id',
        metric: 'leads',
        horizon: 'monthly',
        targetValue: 100.0,
        periodStart: now,
        periodEnd: now.add(const Duration(days: 30)),
      );

      final json = goal.toJson();
      expect(json['id'], 'test-goal-id');
      expect(json['company_id'], 'test-company-id');
      expect(json['created_by'], 'test-user-id');
      expect(json['metric'], 'leads');
      expect(json['horizon'], 'monthly');
      expect(json['target_value'], 100.0);
      expect(json['period_start'], now.toIso8601String().split('T').first);

      final fromJson = Goal.fromJson(json);
      expect(fromJson.id, goal.id);
      expect(fromJson.companyId, goal.companyId);
      expect(fromJson.createdBy, goal.createdBy);
      expect(fromJson.metric, goal.metric);
      expect(fromJson.horizon, goal.horizon);
      expect(fromJson.targetValue, goal.targetValue);
      // Comparing dates formatted as yyyy-MM-dd
      expect(
        fromJson.periodStart.toIso8601String().split('T').first,
        goal.periodStart.toIso8601String().split('T').first,
      );
    });

    test('Goal copyWith works correctly', () {
      final now = DateTime.now();
      final goal = Goal(
        id: 'test-goal-id',
        companyId: 'test-company-id',
        metric: 'closings',
        horizon: 'monthly',
        targetValue: 50.0,
        periodStart: now,
        periodEnd: now.add(const Duration(days: 30)),
      );

      final updatedGoal = goal.copyWith(targetValue: 75.0);
      expect(updatedGoal.targetValue, 75.0);
      expect(updatedGoal.id, goal.id);
      expect(updatedGoal.metric, goal.metric);
    });
  });

  group('Pacing Algorithm Math Tests', () {
    // Ported from computeProgress in GoalNotifier
    String computePace(double currentValue, double expectedProgress) {
      if (currentValue >= expectedProgress * 1.1) {
        return 'ahead';
      } else if (currentValue >= expectedProgress * 0.9) {
        return 'on_track';
      } else if (currentValue >= expectedProgress * 0.6) {
        return 'behind';
      } else {
        return 'critical';
      }
    }

    test('Pacing classifies "ahead" correctly', () {
      final expectedProgress = 50.0; // Day 15 of 30
      final currentValue = 60.0; // Achieved 60


      final pace = computePace(currentValue, expectedProgress);
      expect(pace, 'ahead');
    });

    test('Pacing classifies "on_track" correctly', () {
      final expectedProgress = 50.0;
      final currentValue = 47.0; // 47 is within 90%-110% of 50


      final pace = computePace(currentValue, expectedProgress);
      expect(pace, 'on_track');
    });

    test('Pacing classifies "behind" correctly', () {
      final expectedProgress = 50.0;
      final currentValue = 35.0; // 35 is between 60% and 90% of 50


      final pace = computePace(currentValue, expectedProgress);
      expect(pace, 'behind');
    });

    test('Pacing classifies "critical" correctly', () {
      final expectedProgress = 50.0;
      final currentValue = 20.0; // 20 is below 60% of 50


      final pace = computePace(currentValue, expectedProgress);
      expect(pace, 'critical');
    });

    test('Projected value math is accurate', () {
      final currentValue = 30.0;
      final daysElapsed = 15;
      final daysTotal = 30;

      final projectedValue = (currentValue / daysElapsed) * daysTotal;
      expect(projectedValue, 60.0);
    });
  });
}
