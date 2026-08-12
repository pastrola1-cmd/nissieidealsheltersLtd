import 'package:flutter/material.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/providers/goal_provider.dart';

class GoalCard extends StatelessWidget {
  final GoalProgress progress;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final metricTitle = _getMetricTitle(goal.metric);
    final horizonTitle = _getHorizonTitle(goal.horizon);

    final now = DateTime.now();
    final totalDays = goal.periodEnd.difference(goal.periodStart).inDays;
    final daysElapsed = now.difference(goal.periodStart).inDays.clamp(0, totalDays > 0 ? totalDays : 1);
    final expectedProgress = totalDays <= 0 ? 1.0 : daysElapsed / totalDays;
    final actualProgress = goal.targetValue == 0 ? 0.0 : progress.currentValue / goal.targetValue;
    final paceRatio = expectedProgress == 0 ? 1.0 : actualProgress / expectedProgress;

    final isEnded = now.isAfter(goal.periodEnd);

    late String paceLabel;
    late Color paceBgColor;
    late Color paceTextColor;

    if (isEnded) {
      paceLabel = 'Period Ended';
      paceBgColor = AppColors.border.withValues(alpha: 0.5);
      paceTextColor = AppColors.textTertiary;
    } else if (paceRatio >= 1.0) {
      paceLabel = 'On Track ✓';
      paceBgColor = AppColors.success.withValues(alpha: 0.15);
      paceTextColor = AppColors.success;
    } else if (paceRatio >= 0.75) {
      paceLabel = 'At Risk ⚠️';
      paceBgColor = Colors.orange.withValues(alpha: 0.15);
      paceTextColor = Colors.orange.shade800;
    } else {
      paceLabel = 'Behind 🔴';
      paceBgColor = AppColors.error.withValues(alpha: 0.15);
      paceTextColor = AppColors.error;
    }

    String projectedText;
    if (isEnded) {
      projectedText = 'Ended at ${(actualProgress * 100).toStringAsFixed(0)}% of target';
    } else if (paceRatio >= 1.0) {
      projectedText = 'Projected: Will hit target';
    } else {
      final projectedPct = (actualProgress / (expectedProgress > 0 ? expectedProgress : 1.0) * 100).clamp(0.0, 999.0);
      projectedText = 'Projected: ~${projectedPct.toStringAsFixed(0)}% of target';
    }

    final isRevenue = goal.metric == 'revenue';
    final currentStr = isRevenue 
        ? '₦${_formatCompact(progress.currentValue)}' 
        : progress.currentValue.toInt().toString();
    final targetStr = isRevenue 
        ? '₦${_formatCompact(progress.targetValue)}' 
        : goal.targetValue.toInt().toString();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          horizonTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          metricTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: paceBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      paceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: paceTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: (progress.progressPercent / 100).clamp(0.0, 1.0),
                          strokeWidth: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(paceTextColor),
                        ),
                        Center(
                          child: Text(
                            '${progress.progressPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$currentStr / $targetStr',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          projectedText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: paceRatio < 0.75 && !isEnded ? AppColors.error : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        return 'MONTHLY GOAL';
      case 'quarterly':
        return 'QUARTERLY GOAL';
      case '6month':
        return '6-MONTH GOAL';
      case 'yearly':
        return 'YEARLY GOAL';
      default:
        return horizon.toUpperCase();
    }
  }

  String _formatCompact(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}
