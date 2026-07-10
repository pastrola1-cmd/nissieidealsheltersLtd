import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/training_provider.dart';

class TrainingDashboardScreen extends ConsumerWidget {
  const TrainingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trainingState = ref.watch(trainingProvider);
    final authState = ref.watch(authProvider);
    final role = authState.profile?.role;
    final isStaffAdmin = role == UserRole.admin || role == UserRole.manager;

    if (trainingState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Nissie Academy',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          centerTitle: false,
          actions: [
            if (isStaffAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/training/manage'),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Manage Academy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
              ),
          ],
          bottom: const TabBar(
            isScrollable: false,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              Tab(icon: Icon(Icons.auto_stories_outlined), text: 'Study'),
              Tab(icon: Icon(Icons.forum_outlined), text: 'Simulate'),
              Tab(icon: Icon(Icons.assignment_outlined), text: 'Exams'),
              Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Leaderboard'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStudyTab(context, ref, trainingState, authState.profile?.id),
            _buildSimulatorTab(context, ref, trainingState, authState.profile?.id),
            _buildExamsTab(context, ref, trainingState, authState.profile?.id),
            _buildLeaderboardTab(context, ref, trainingState),
          ],
        ),
      ),
    );
  }

  // ── Study Center Tab ──
  Widget _buildStudyTab(BuildContext context, WidgetRef ref, TrainingState state, String? profileId) {
    if (state.materials.isEmpty) {
      return const Center(
        child: Text('No study guides uploaded yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: state.materials.length,
      itemBuilder: (context, index) {
        final mat = state.materials[index];
        final isRead = state.progress.any((p) => p.profileId == profileId && p.itemId == mat.id && p.itemType == 'material');

        return Card(
          color: AppColors.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon wrapper
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    mat.mediaUrl != null ? Icons.picture_as_pdf_rounded : Icons.article_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Title and Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${mat.points} XP',
                              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          if (isRead)
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                          else
                            const Icon(Icons.circle_outlined, color: AppColors.textTertiary, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mat.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mat.description ?? 'Study guide to refine your sales performance.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              context.push('/training/material/${mat.id}');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceVariant,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Read Article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          if (mat.mediaUrl != null) ...[
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                // For white-label downloading or redirecting
                              },
                              icon: const Icon(Icons.download_rounded, size: 14),
                              label: const Text('PDF Attachment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Objections Simulator Tab ──
  Widget _buildSimulatorTab(BuildContext context, WidgetRef ref, TrainingState state, String? profileId) {
    if (state.simulators.isEmpty) {
      return const Center(
        child: Text('No simulator scenarios created yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: state.simulators.length,
      itemBuilder: (context, index) {
        final sim = state.simulators[index];
        final progress = state.progress.cast<TrainingProgress?>().firstWhere(
              (p) => p?.profileId == profileId && p?.itemId == sim.id && p?.itemType == 'simulator',
              orElse: () => null,
            );

        return Card(
          color: AppColors.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.purple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${sim.points} XP',
                              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          if (progress != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${progress.score}% Done',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sim.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Client: ${sim.clientPersona} (${sim.objectionType.toUpperCase()})',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sim.description ?? 'Handle the objection step by step.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.push('/training/simulator/${sim.id}');
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text(
                          progress != null ? 'Retake Challenge' : 'Start Simulation',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Quizzes / Exams Tab ──
  Widget _buildExamsTab(BuildContext context, WidgetRef ref, TrainingState state, String? profileId) {
    if (state.exams.isEmpty) {
      return const Center(
        child: Text('No certification exams uploaded yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: state.exams.length,
      itemBuilder: (context, index) {
        final exam = state.exams[index];
        final progress = state.progress.cast<TrainingProgress?>().firstWhere(
              (p) => p?.profileId == profileId && p?.itemId == exam.id && p?.itemType == 'exam',
              orElse: () => null,
            );
        final isPassed = progress != null && progress.score != null && progress.score! >= exam.passingScore;

        return Card(
          color: AppColors.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amber,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${exam.points} XP',
                              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          if (progress != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPassed ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPassed ? 'PASSED (${progress.score}%)' : 'FAILED (${progress.score}%)',
                                style: TextStyle(
                                  color: isPassed ? AppColors.success : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exam.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Questions: ${exam.questions.length} • Passing Score: ${exam.passingScore}% • Time Limit: ${exam.timeLimitMins}m',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exam.description ?? 'Solid test of marketing strategy & product info.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          context.push('/training/exam/${exam.id}');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          progress != null ? 'Retake Exam' : 'Take Exam',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Leaderboard Tab ──
  Widget _buildLeaderboardTab(BuildContext context, WidgetRef ref, TrainingState state) {
    final pointsMap = ref.read(trainingProvider.notifier).getLeaderboardPoints();
    
    // Sort profiles by points descending
    final sortedStaff = List<Profile>.from(state.companyStaff)
      ..sort((a, b) {
        final ptsA = pointsMap[a.id] ?? 0;
        final ptsB = pointsMap[b.id] ?? 0;
        return ptsB.compareTo(ptsA);
      });

    if (sortedStaff.isEmpty) {
      return const Center(
        child: Text('No members in the leaderboard.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Top 3 Podium Area (if >= 3 members) ──
        if (sortedStaff.length >= 3) ...[
          _buildPodium(context, sortedStaff.take(3).toList(), pointsMap, state),
          const SizedBox(height: 24),
        ],

        // ── List of All Members ──
        const Text(
          'Rankings & Badges',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedStaff.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = sortedStaff[index];
              final points = pointsMap[user.id] ?? 0;
              final userBadges = state.badges.where((b) => b.profileId == user.id).toList();

              return ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: index == 0
                              ? Colors.amber.shade700
                              : index == 1
                                  ? Colors.grey.shade600
                                  : index == 2
                                      ? Colors.brown.shade600
                                      : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null ? const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20) : null,
                    ),
                  ],
                ),
                title: Text(
                  user.fullName ?? 'Team Member',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Wrap(
                  spacing: 4,
                  children: userBadges.map((b) {
                    return Tooltip(
                      message: b.badgeName,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                        ),
                        child: Text(
                          b.badgeName.split(' ').first,
                          style: const TextStyle(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                trailing: Text(
                  '$points XP',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accent, fontSize: 14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(BuildContext context, List<Profile> topThree, Map<String, int> pointsMap, TrainingState state) {
    // topThree has exactly 3 elements [0: First, 1: Second, 2: Third]
    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd Place
        _buildPodiumPosition(context, second, 2, pointsMap[second.id] ?? 0, 90, Colors.grey.shade400),
        // 1st Place
        _buildPodiumPosition(context, first, 1, pointsMap[first.id] ?? 0, 110, Colors.amber.shade400),
        // 3rd Place
        _buildPodiumPosition(context, third, 3, pointsMap[third.id] ?? 0, 80, Colors.brown.shade300),
      ],
    );
  }

  Widget _buildPodiumPosition(BuildContext context, Profile user, int rank, int points, double height, Color podiumColor) {
    return Column(
      children: [
        // Profile picture
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 32 : 26,
              backgroundColor: podiumColor,
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? const Icon(Icons.person_rounded, color: Colors.white, size: 28) : null,
            ),
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Text(
                    rank == 1 ? '👑' : '#$rank',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user.fullName?.split(' ').first ?? 'Member',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          '$points XP',
          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: podiumColor.withOpacity(0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: podiumColor.withOpacity(0.5), width: 1.5),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(fontWeight: FontWeight.w900, color: podiumColor.withOpacity(0.8), fontSize: 24),
            ),
          ),
        ),
      ],
    );
  }
}
