import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/company_provider.dart';
import 'package:ppn/providers/dashboard_provider.dart';
import 'package:ppn/providers/notification_provider.dart';
import 'package:ppn/widgets/lead_usage_progress_bar.dart';
import 'package:ppn/widgets/goals_dashboard_list.dart';


class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companyState = ref.watch(companyProvider);
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(dashboardProvider);
    final notificationState = ref.watch(notificationProvider);

    final company = companyState.company;
    final profile = authState.profile;
    final unreadNotifications = notificationState.notifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Premium Custom Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Company Logo
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                            image: company?.logoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(company!.logoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: company?.logoUrl == null
                              ? const Icon(Icons.business_rounded, size: 24, color: AppColors.textTertiary)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company?.name ?? 'Loading Agency...',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Agency Admin Dashboard',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Notification Bell
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                              onPressed: () => context.push('/notifications'),
                            ),
                            if (unreadNotifications > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$unreadNotifications',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        // Company Settings Cog
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                          onPressed: () => context.push('/admin/company-profile'),
                        ),
                        const SizedBox(width: 4),
                        // Admin Profile Avatar
                        GestureDetector(
                          onTap: () => context.push('/admin/settings'),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                              image: profile?.avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(profile!.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                          ),
                          child: profile?.avatarUrl == null
                              ? const Icon(Icons.person_rounded, size: 20, color: AppColors.textTertiary)
                              : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Premium Welcome Banner ──
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
                        'Welcome back,',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile?.fullName?.split(' ').first ?? 'Admin'} 👋',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Here is your sales performance overview.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const LeadUsageProgressBar(),
                const SizedBox(height: 20),
                const GoalsDashboardList(),
                const SizedBox(height: 28),

                // ── Summary Cards Grid ──
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.35,
                  children: [
                    _buildStatCard(
                      title: 'Total Listings',
                      value: dashboardState.totalProperties.toString(),
                      icon: Icons.home_work_outlined,
                      color: AppColors.accent,
                    ),
                    _buildStatCard(
                      title: 'Active Partners',
                      value: dashboardState.activePartners.toString(),
                      icon: Icons.handshake_outlined,
                      color: Colors.purple,
                    ),
                    _buildStatCard(
                      title: 'Total Leads',
                      value: dashboardState.totalLeads.toString(),
                      subtitle: '${dashboardState.conversionRate.toStringAsFixed(1)}% Conv.',
                      icon: Icons.trending_up_rounded,
                      color: Colors.amber.shade800,
                    ),
                    _buildStatCard(
                      title: 'Sales Value',
                      value: '₦${_formatAmount(dashboardState.totalSalesValue)}',
                      subtitle: '₦${_formatAmount(dashboardState.commissionLiabilities)} Liab.',
                      icon: Icons.monetization_on_outlined,
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Pipeline Distribution Chart ──
                PipelineDistributionChart(distribution: dashboardState.leadStageDistribution),
                const SizedBox(height: 28),

                // ── Top Performing Partners ──
                TopPartnersList(partners: dashboardState.topPartners),
                const SizedBox(height: 28),

                // ── Recent Activity Feed ──
                RecentActivityFeed(activities: dashboardState.recentActivities),
                const SizedBox(height: 28),

                // ── Quick Actions Card ──
                Card(
                  color: AppColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Management',
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
                          onTap: () => context.push('/admin/campaigns/generator'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.description_rounded, color: Colors.blue),
                          ),
                          title: const Text('Document Registry', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Generate and manage offer letters, tenancy agreements & receipts'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/documents'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.psychology_rounded, color: Colors.amber),
                          ),
                          title: const Text('Block Performance & Evolution', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Manage and optimize advertising template blocks'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/campaigns/performance'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.analytics_rounded, color: Colors.indigo),
                          ),
                          title: const Text('Performance Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('View pipeline funnel, staff performance and revenue trends'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/analytics'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(

                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bar_chart_rounded, color: Colors.teal),
                          ),
                          title: const Text('Performance Reports', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('View daily agency lead, inspection, and revenue reports'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/reports'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.business_rounded, color: AppColors.accent),
                          ),
                          title: const Text('Manage Agency Branding', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Edit name, support contact, and logo'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/company-profile'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.purple),
                          ),
                          title: const Text('Personal Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Edit profile, update password, and avatar'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/settings'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_today_rounded, color: Colors.teal),
                          ),
                          title: const Text('Manage Property Inspections', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Confirm, complete, or cancel bookings'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/inspections'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.currency_exchange_rounded, color: Colors.amber),
                          ),
                          title: const Text('Manage Commissions & Payouts', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Approve or dispute partner payout ledger'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/commissions'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.deepOrange),
                          ),
                          title: const Text('Manage Withdrawal Requests', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Approve, mark paid, or reject partner withdrawals'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/withdrawals'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_add_rounded, color: Colors.indigo),
                          ),
                          title: const Text('Invite Staff Members', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Register managers or marketers for your agency'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/invite-staff'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.star_rounded, color: Colors.blue),
                          ),
                          title: const Text('Subscription & Billing', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Manage your SaaS plan and check listing limits'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/billing'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PipelineDistributionChart extends StatelessWidget {
  final Map<LeadStage, int> distribution;

  const PipelineDistributionChart({super.key, required this.distribution});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = distribution.values.fold<int>(0, (sum, val) => sum + val);

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pipeline Stage Distribution',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No lead data available yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...LeadStage.values.map((stage) {
                final count = distribution[stage] ?? 0;
                final percentage = total == 0 ? 0.0 : count / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            stage.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '$count (${(percentage * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(_getStageColor(stage)),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Color _getStageColor(LeadStage stage) {
    switch (stage) {
      case LeadStage.newLead:
        return Colors.blue;
      case LeadStage.contacted:
        return Colors.orange;
      case LeadStage.inspectionBooked:
        return Colors.purple;
      case LeadStage.negotiation:
        return Colors.amber.shade800;
      case LeadStage.closed:
        return Colors.teal;
      case LeadStage.lost:
        return Colors.red;
    }
  }
}

class TopPartnersList extends StatelessWidget {
  final List<PartnerPerformance> partners;

  const TopPartnersList({super.key, required this.partners});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Partners',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (partners.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No partner conversions yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: partners.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final performance = partners[index];
                  final partner = performance.partner;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.border,
                      backgroundImage: partner.avatarUrl != null ? NetworkImage(partner.avatarUrl!) : null,
                      child: partner.avatarUrl == null
                          ? const Icon(Icons.person, color: AppColors.textTertiary)
                          : null,
                    ),
                    title: Text(
                      partner.fullName ?? 'Unnamed Partner',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${performance.conversionCount} Closed Deals',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: Text(
                      '₦${performance.totalSalesValue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.teal,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class RecentActivityFeed extends StatelessWidget {
  final List<ActivityLog> activities;

  const RecentActivityFeed({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No recent activities recorded.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final log = activities[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getActivityColor(log.type).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getActivityIcon(log.type),
                            color: _getActivityColor(log.type),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                log.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(log.timestamp),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.leadCreated:
        return Icons.person_add_rounded;
      case ActivityType.commissionPending:
        return Icons.hourglass_empty_rounded;
      case ActivityType.commissionApproved:
        return Icons.check_circle_outline_rounded;
      case ActivityType.commissionDisputed:
        return Icons.warning_amber_rounded;
      case ActivityType.inspectionBooked:
        return Icons.event_available_rounded;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.leadCreated:
        return Colors.blue;
      case ActivityType.commissionPending:
        return Colors.amber.shade800;
      case ActivityType.commissionApproved:
        return Colors.teal;
      case ActivityType.commissionDisputed:
        return Colors.red;
      case ActivityType.inspectionBooked:
        return Colors.purple;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
