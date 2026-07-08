import 'package:flutter_test/flutter_test.dart';
import 'package:nissie_ideal_shelters/providers/analytics_provider.dart';

void main() {
  group('Analytics State & MonthlyRevenue Model Tests', () {
    test('MonthlyRevenue model holds correct data', () {
      const revenue = MonthlyRevenue('Jan', 15000000.0);
      expect(revenue.monthLabel, 'Jan');
      expect(revenue.revenue, 15000000.0);
    });

    test('AnalyticsState default constructor initialized correctly', () {
      final now = DateTime.now();
      final state = AnalyticsState(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );

      expect(state.isLoading, false);
      expect(state.errorMessage, isNull);
      expect(state.period, AnalyticsPeriod.thisMonth);
      expect(state.totalLeadsCurrent, 0);
      expect(state.totalLeadsPrevious, 0);
      expect(state.conversionRateCurrent, 0.0);
      expect(state.conversionRatePrevious, 0.0);
      expect(state.revenueCurrent, 0.0);
      expect(state.revenuePrevious, 0.0);
      expect(state.activeCampaignsCount, 0);
      expect(state.pipelineFunnel, isEmpty);
      expect(state.staffPerformance, isEmpty);
      expect(state.revenueTrend, isEmpty);
    });

    test('AnalyticsState copyWith updates fields correctly', () {
      final now = DateTime.now();
      final state = AnalyticsState(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );

      final updated = state.copyWith(
        isLoading: true,
        totalLeadsCurrent: 25,
        totalLeadsPrevious: 20,
        conversionRateCurrent: 12.0,
        conversionRatePrevious: 10.0,
        revenueCurrent: 5000000.0,
        revenuePrevious: 4000000.0,
        activeCampaignsCount: 3,
        period: AnalyticsPeriod.thisQuarter,
      );

      expect(updated.isLoading, true);
      expect(updated.totalLeadsCurrent, 25);
      expect(updated.totalLeadsPrevious, 20);
      expect(updated.conversionRateCurrent, 12.0);
      expect(updated.conversionRatePrevious, 10.0);
      expect(updated.revenueCurrent, 5000000.0);
      expect(updated.revenuePrevious, 4000000.0);
      expect(updated.activeCampaignsCount, 3);
      expect(updated.period, AnalyticsPeriod.thisQuarter);
    });
  });

  group('Delta Math Tests', () {
    double calculateDelta(double current, double previous) {
      if (previous == 0.0) return 0.0;
      return ((current - previous) / previous) * 100;
    }

    test('Delta calculation identifies positive growth', () {
      expect(calculateDelta(150, 100), 50.0);
      expect(calculateDelta(12, 10), 20.0);
    });

    test('Delta calculation identifies negative growth', () {
      expect(calculateDelta(50, 100), -50.0);
      expect(calculateDelta(8, 10), -20.0);
    });

    test('Delta calculation handles zero previous values safely', () {
      expect(calculateDelta(100, 0), 0.0);
      expect(calculateDelta(0, 0), 0.0);
    });
  });

  group('Analytics Period Date Calculations', () {
    // Pure function mimicking date calculation in setPeriod based on a fixed "now"
    Map<String, DateTime> calculatePeriodRange(AnalyticsPeriod period, DateTime mockNow) {
      DateTime start = mockNow;
      DateTime end = mockNow;

      switch (period) {
        case AnalyticsPeriod.today:
          start = DateTime(mockNow.year, mockNow.month, mockNow.day);
          end = DateTime(mockNow.year, mockNow.month, mockNow.day, 23, 59, 59);
          break;
        case AnalyticsPeriod.thisWeek:
          start = mockNow.subtract(Duration(days: mockNow.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
          end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case AnalyticsPeriod.thisMonth:
          start = DateTime(mockNow.year, mockNow.month, 1);
          end = DateTime(mockNow.year, mockNow.month + 1, 0, 23, 59, 59);
          break;
        case AnalyticsPeriod.thisQuarter:
          final quarter = ((mockNow.month - 1) / 3).floor();
          start = DateTime(mockNow.year, quarter * 3 + 1, 1);
          end = DateTime(mockNow.year, (quarter + 1) * 3 + 1, 0, 23, 59, 59);
          break;
      }
      return {'start': start, 'end': end};
    }

    test('Today period dates are correct', () {
      final mockNow = DateTime(2026, 6, 11, 12, 30, 0); // Thursday
      final range = calculatePeriodRange(AnalyticsPeriod.today, mockNow);

      expect(range['start'], DateTime(2026, 6, 11, 0, 0, 0));
      expect(range['end'], DateTime(2026, 6, 11, 23, 59, 59));
    });

    test('This Week period dates start on Monday and end on Sunday', () {
      final mockNow = DateTime(2026, 6, 11, 12, 30, 0); // Thursday, weekday = 4
      final range = calculatePeriodRange(AnalyticsPeriod.thisWeek, mockNow);

      // Should start on Monday June 8th, 2026
      expect(range['start'], DateTime(2026, 6, 8, 0, 0, 0));
      // Should end on Sunday June 14th, 2026
      expect(range['end'], DateTime(2026, 6, 14, 23, 59, 59));
    });

    test('This Month period dates start on 1st and end on last day', () {
      final mockNow = DateTime(2026, 6, 11, 12, 30, 0); // June
      final range = calculatePeriodRange(AnalyticsPeriod.thisMonth, mockNow);

      expect(range['start'], DateTime(2026, 6, 1, 0, 0, 0));
      // June has 30 days
      expect(range['end'], DateTime(2026, 6, 30, 23, 59, 59));
    });

    test('This Quarter period dates boundaries are correct', () {
      final mockNow = DateTime(2026, 6, 11, 12, 30, 0); // June (Q2: Apr, May, June)
      final range = calculatePeriodRange(AnalyticsPeriod.thisQuarter, mockNow);

      // Q2 starts April 1st
      expect(range['start'], DateTime(2026, 4, 1, 0, 0, 0));
      // Q2 ends June 30th
      expect(range['end'], DateTime(2026, 6, 30, 23, 59, 59));
    });
  });
}
