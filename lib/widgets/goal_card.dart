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

    final Color statusColor = _getStatusColor(progress.pace);
    final Color statusBg = statusColor.withValues(alpha: 0.1);

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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          metricTitle,
                          style: const TextStyle(
                            fontSize: 16,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      progress.pace.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
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
                    width: 50,
                    height: 50,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress.progressPercent / 100,
                          strokeWidth: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                        Center(
                          child: Text(
                            '${progress.progressPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$currentStr / $targetStr',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Projected: ${isRevenue ? "₦" : ""}${_formatCompact(progress.projectedValue)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
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
