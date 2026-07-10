import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/widgets/goals_dashboard_list.dart';

class MarketerDashboardScreen extends ConsumerWidget {
  const MarketerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final leadState = ref.watch(leadProvider);
    final userProfile = ref.watch(authProvider).profile;

    // Filter leads assigned to this specific marketer
    final myLeads = leadState.leads.where((l) => l.assignedAgentId == userProfile?.id).toList();

    // Stats calculations
    final assignedCount = myLeads.length;
    final followUpsCount = myLeads.where((l) => l.stage == LeadStage.contacted).length;
    final conversionsCount = myLeads.where((l) => l.stage == LeadStage.closed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(leadProvider.notifier).loadLeads(),
          color: AppColors.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Custom Header Row ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Dashboard',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                          onPressed: () => context.push('/notifications'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                          tooltip: 'Sign Out',
                          onPressed: () => ref.read(authProvider.notifier).logout(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // ── Gradient Welcome Banner ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.dashboardHeaderGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${userProfile?.fullName?.split(' ').first ?? 'Agent'}! 👋',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track leads, follow up, and close deals.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // ── Stats Cards Row ──
                _buildStatsRow(isMobile, assignedCount, followUpsCount, conversionsCount),
                const SizedBox(height: 24),

                // ── Active Performance Goals ──
                const GoalsDashboardList(),
                const SizedBox(height: 24),

                // ── Quick Actions Card ──
                Card(
                  color: AppColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                          ),
                          title: const Text('Campaign Generator', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Generate rule-based ad copy & platform layouts'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/marketer/campaigns/generator'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_search_rounded, color: AppColors.primary),
                          ),
                          title: const Text('My Leads', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Track and update your assigned leads'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.go('/marketer/leads'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.school_rounded, color: Colors.amber),
                          ),
                          title: const Text('Nissie Academy', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Access sales training, client objections simulator, and exams'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/training'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.settings_outlined, color: Colors.blueGrey),
                          ),
                          title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Edit profile and update password'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // ── Recent Activity Section ──
                Text(
                  'Recent Leads Activity',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  color: AppColors.surface,
                  child: myLeads.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.history_rounded, size: 48, color: AppColors.textTertiary),
                                SizedBox(height: 12),
                                Text(
                                  'Your recent activity will appear here',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: myLeads.take(3).length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final lead = myLeads[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                                child: const Icon(Icons.person, color: AppColors.accent),
                              ),
                              title: Text(
                                lead.buyerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                'Stage: ${lead.stage.label} • Phone: ${lead.buyerPhone}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                              onTap: () => context.push('/marketer/leads/${lead.id}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile, int assigned, int followUps, int conversions) {
    final stats = [
      ('Assigned Leads', assigned.toString(), Icons.person_search, AppColors.primary),
      ('Follow-ups Due', followUps.toString(), Icons.schedule, AppColors.warning),
      ('Conversions', conversions.toString(), Icons.check_circle_outline, AppColors.success),
    ];

    if (isMobile) {
      return Column(
        children: stats.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildStatCard(s.$1, s.$2, s.$3, s.$4),
        )).toList(),
      );
    }

    return Row(
      children: stats.map((s) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildStatCard(s.$1, s.$2, s.$3, s.$4),
        ),
      )).toList(),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.scale(
            scale: 0.95 + (0.05 * val),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
