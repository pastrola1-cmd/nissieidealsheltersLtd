import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';

class LeadUsageProgressBar extends ConsumerWidget {
  final bool showHeader;

  const LeadUsageProgressBar({
    super.key,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final companyState = ref.watch(companyProvider);
    
    final company = authState.company ?? companyState.company;
    final profile = authState.profile;

    if (company == null || profile == null) {
      return const SizedBox.shrink();
    }

    final monthlyLeadCountAsync = ref.watch(monthlyLeadCountProvider);

    return monthlyLeadCountAsync.when(
      loading: () => const Card(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (err, stack) => const SizedBox.shrink(),
      data: (usedCount) {
        final limit = company.effectiveLeadLimit;
        final isUnlimited = limit >= 999999;
        final usageRatio = (isUnlimited || limit <= 0) ? 0.0 : (usedCount / limit).clamp(0.0, 1.0);
        final percent = (usageRatio * 100).toInt();

        Color progressColor = AppColors.success;
        if (usageRatio >= 0.90) {
          progressColor = AppColors.error;
        } else if (usageRatio >= 0.70) {
          progressColor = Colors.orange;
        }

        final isLimitReached = !isUnlimited && limit > 0 && usedCount >= limit;

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Lead Usage',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isUnlimited ? '$usedCount / Unlimited' : '$usedCount / $limit ($percent%)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLimitReached ? AppColors.error : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(
                      value: isUnlimited ? 0.05 : usageRatio,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ),
                if (isLimitReached) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Monthly Lead Limit Reached!',
                                style: TextStyle(
                                  color: AppColors.errorDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.role == UserRole.manager
                                    ? 'Please contact your Agency Administrator to upgrade the subscription.'
                                    : 'Please upgrade your subscription plan to continue adding leads.',
                                style: const TextStyle(
                                  color: AppColors.errorDark,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                              if (profile.role == UserRole.admin) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => context.push('/admin/billing'),
                                  child: const Text(
                                    'Upgrade Subscription →',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (usageRatio >= 0.70 && !isUnlimited) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          profile.role == UserRole.manager
                              ? 'Approaching limit ($percent% used). Contact Admin to upgrade.'
                              : 'Approaching limit ($percent% used). Consider upgrading soon.',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
