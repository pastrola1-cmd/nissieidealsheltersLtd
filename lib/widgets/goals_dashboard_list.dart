import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/goal_provider.dart';
import 'package:nissie_ideal_shelters/widgets/goal_card.dart';

class GoalsDashboardList extends ConsumerStatefulWidget {
  const GoalsDashboardList({super.key});

  @override
  ConsumerState<GoalsDashboardList> createState() => _GoalsDashboardListState();
}

class _GoalsDashboardListState extends ConsumerState<GoalsDashboardList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(goalProvider.notifier).fetchGoals());
  }

  @override
  Widget build(BuildContext context) {
    final goalState = ref.watch(goalProvider);
    final userProfile = ref.watch(authProvider).profile;
    final isAdmin = userProfile?.role == UserRole.admin || userProfile?.role == UserRole.platformAdmin;
    final isManager = userProfile?.role == UserRole.manager;
    final canManageGoals = isAdmin || isManager;
    final rolePath = isAdmin ? 'admin' : 'manager';

    if (goalState.goals.isEmpty) {
      if (!isAdmin) return const SizedBox.shrink();
      
      // For Admin, show a helpful set-up call-to-action card if there are no goals
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.track_changes_outlined,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'No goals set yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Set conversion targets to monitor performance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.push('/admin/goals'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Set Goals',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Performance Goals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (canManageGoals)
              TextButton(
                onPressed: () => context.push('/$rolePath/goals'),
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: goalState.goals.length,
            itemBuilder: (context, index) {
              final goal = goalState.goals[index];
              final progress = goalState.progressCache[goal.id];

              if (progress == null) {
                return Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              return Container(
                width: 250,
                margin: const EdgeInsets.only(right: 16),
                child: GoalCard(
                  progress: progress,
                  onTap: canManageGoals ? () => context.push('/$rolePath/goals/${goal.id}') : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
