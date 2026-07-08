import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/providers/goal_provider.dart';

class GoalDetailScreen extends ConsumerWidget {
  final String goalId;

  const GoalDetailScreen({
    super.key,
    required this.goalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalState = ref.watch(goalProvider);
    final progress = goalState.progressCache[goalId];

    if (progress == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final goal = progress.goal;
    final metricTitle = _getMetricTitle(goal.metric);
    final horizonTitle = _getHorizonTitle(goal.horizon);
    final dateFormat = DateFormat('MMM dd, yyyy');

    final Color statusColor = _getStatusColor(progress.pace);
    final Color statusBg = statusColor.withValues(alpha: 0.1);

    final isRevenue = goal.metric == 'revenue';
    final currentStr = isRevenue 
        ? '₦${_formatCurrency(progress.currentValue)}' 
        : progress.currentValue.toInt().toString();
    final targetStr = isRevenue 
        ? '₦${_formatCurrency(progress.targetValue)}' 
        : goal.targetValue.toInt().toString();
    final projectedStr = isRevenue
        ? '₦${_formatCurrency(progress.projectedValue)}'
        : progress.projectedValue.toInt().toString();

    // Calculate time elapsed for expected progress marker
    final now = DateTime.now();
    DateTime progressTime = now;
    if (progressTime.isBefore(goal.periodStart)) {
      progressTime = goal.periodStart;
    } else if (progressTime.isAfter(goal.periodEnd)) {
      progressTime = goal.periodEnd;
    }

    final daysElapsed = progressTime.difference(goal.periodStart).inDays + 1;
    final daysTotal = goal.periodEnd.difference(goal.periodStart).inDays + 1;
    final expectedPercent = daysTotal > 0 ? (daysElapsed / daysTotal) * 100 : 0.0;
    final expectedValue = (daysElapsed / daysTotal) * goal.targetValue;
    final expectedStr = isRevenue
        ? '₦${_formatCurrency(expectedValue)}'
        : expectedValue.toInt().toString();

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '$horizonTitle Detail',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          metricTitle.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            progress.pace.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Targeting $targetStr $metricTitle',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Period: ${dateFormat.format(goal.periodStart)} — ${dateFormat.format(goal.periodEnd)} ($daysTotal days total)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Performance Circular Indicator & Stat Box Row
            if (isMobile) ...[
              _buildProgressCircleCard(progress, statusColor),
              const SizedBox(height: 16),
              _buildStatsBox(currentStr, targetStr, expectedStr, projectedStr, expectedPercent, progress.progressPercent),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildProgressCircleCard(progress, statusColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _buildStatsBox(currentStr, targetStr, expectedStr, projectedStr, expectedPercent, progress.progressPercent),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Actionable Suggestion Engine Card
            if (progress.suggestion != null) ...[
              Card(
                elevation: 0,
                color: AppColors.warningLight.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.warning, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.warningDark,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recommendation to Get On-Track',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warningDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              progress.suggestion!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Visual Pacing Timeline Chart
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pacing Timeline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Compares actual performance against expected progress based on calendar time elapsed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildPacingChart(progress.progressPercent, expectedPercent, statusColor),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLegendItem('Actual Progress', statusColor),
                        _buildLegendItem('Expected Progress Line', AppColors.textPrimary),
                        _buildLegendItem('Remaining Period', AppColors.border),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCircleCard(GoalProgress progress, Color statusColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress.progressPercent / 100,
                      strokeWidth: 10,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                    Center(
                      child: Text(
                        '${progress.progressPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Goal Completion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBox(
    String current,
    String target,
    String expected,
    String projected,
    double expectedPct,
    double actualPct,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildStatRow('Achieved Value', current, 'Target: $target'),
            const Divider(height: 24),
            _buildStatRow(
              'Expected Pace Value',
              expected,
              'Time Elapsed: ${expectedPct.toStringAsFixed(0)}%',
            ),
            const Divider(height: 24),
            _buildStatRow(
              'Projected Final Value',
              projected,
              'Pacing Rate: ${(actualPct / (expectedPct > 0 ? expectedPct : 1.0) * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, String subText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subText,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPacingChart(double actualPercent, double expectedPercent, Color statusColor) {
    final actualVal = (actualPercent / 100).clamp(0.0, 1.0);
    final expectedVal = (expectedPercent / 100).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final expectedPosition = width * expectedVal;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Background line (total path)
            Container(
              height: 24,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Actual progress line
            FractionallySizedBox(
              widthFactor: actualVal,
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Expected progress line marker (Today indicator)
            Positioned(
              left: expectedPosition - 2,
              top: -6,
              child: Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Expected progress label tag
            Positioned(
              left: expectedPosition - 20,
              top: -24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getMetricTitle(String metric) {
    switch (metric) {
      case 'leads':
        return 'Leads';
      case 'closings':
        return 'Deals Closed';
      case 'revenue':
        return 'Revenue';
      default:
        return metric;
    }
  }

  String _getHorizonTitle(String horizon) {
    switch (horizon) {
      case 'monthly':
        return 'Monthly Goal';
      case 'quarterly':
        return 'Quarterly Goal';
      case '6month':
        return '6-Month Goal';
      case 'yearly':
        return 'Yearly Goal';
      default:
        return horizon;
    }
  }

  Color _getStatusColor(String pace) {
    switch (pace) {
      case 'ahead':
        return AppColors.success;
      case 'on_track':
        return AppColors.info;
      case 'behind':
        return AppColors.warning;
      case 'critical':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String _formatCurrency(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}
