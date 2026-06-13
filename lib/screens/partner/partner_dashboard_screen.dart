import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/company_provider.dart';
import 'package:ppn/providers/dashboard_provider.dart';
import 'package:ppn/providers/notification_provider.dart';

class PartnerDashboardScreen extends ConsumerWidget {
  const PartnerDashboardScreen({super.key});

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
                // ── Header ──
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
                              'Partner Program Network',
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
                        IconButton(
                          icon: const Icon(Icons.person_outline_rounded, color: AppColors.textPrimary),
                          onPressed: () => context.push('/partner/profile'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Welcome Text ──
                Text(
                  'Welcome, ${profile?.fullName?.split(' ').first ?? 'Partner'}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track your referrals, earnings, and progress.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
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
                      title: 'Total Referrals',
                      value: dashboardState.partnerTotalLeads.toString(),
                      icon: Icons.group_outlined,
                      color: AppColors.accent,
                    ),
                    _buildStatCard(
                      title: 'Active Deals',
                      value: dashboardState.partnerActiveDeals.toString(),
                      icon: Icons.hourglass_empty_rounded,
                      color: Colors.amber.shade800,
                    ),
                    _buildStatCard(
                      title: 'Total Earnings',
                      value: '₦${_formatAmount(dashboardState.partnerTotalEarned)}',
                      icon: Icons.monetization_on_outlined,
                      color: Colors.teal,
                    ),
                    _buildStatCard(
                      title: 'Available Balance',
                      value: '₦${_formatAmount(dashboardState.partnerAvailableBalance)}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Quick Actions Row ──
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.home_work_outlined,
                        label: 'Browse Listings',
                        onTap: () => context.go('/partner/properties'),
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.wallet_giftcard_rounded,
                        label: 'Payout Wallet',
                        onTap: () => context.go('/partner/earnings'),
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.copy_rounded,
                        label: 'Copy Code',
                        onTap: () {
                          if (profile?.referralCode != null) {
                            Clipboard.setData(ClipboardData(text: profile!.referralCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Referral Code Copied: ${profile.referralCode}'),
                                backgroundColor: AppColors.accent,
                              ),
                            );
                          }
                        },
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Lead Generation Rate chart ──
                PartnerPerformanceChart(leadsOverTime: dashboardState.partnerLeadsOverTime),
                const SizedBox(height: 28),

                // ── Recent Client Referrals ──
                Card(
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
                          'Recent Referred Clients',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (dashboardState.partnerRecentLeads.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No referred clients yet.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dashboardState.partnerRecentLeads.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final lead = dashboardState.partnerRecentLeads[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  lead.buyerName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Referred on ${_formatDate(lead.createdAt)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStageColor(lead.stage).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    lead.stage.label,
                                    style: TextStyle(
                                      color: _getStageColor(lead.stage),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              );
                            },
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
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class PartnerPerformanceChart extends StatelessWidget {
  final Map<String, int> leadsOverTime;

  const PartnerPerformanceChart({super.key, required this.leadsOverTime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Sort keys chronologically
    final sortedKeys = leadsOverTime.keys.toList()..sort();
    
    // Take recent 5 months
    final displayKeys = sortedKeys.length > 5 ? sortedKeys.sublist(sortedKeys.length - 5) : sortedKeys;

    final maxVal = leadsOverTime.values.fold<int>(0, (m, val) => val > m ? val : m);

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
              'Leads Generated (Monthly)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            if (displayKeys.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No referral activity yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: displayKeys.map((key) {
                    final val = leadsOverTime[key] ?? 0;
                    final pct = maxVal == 0 ? 0.0 : val / maxVal;
                    
                    // Simple month label formatting (e.g. "2026-06" -> "Jun")
                    final parts = key.split('-');
                    final monthNum = parts.length > 1 ? int.tryParse(parts[1]) : null;
                    final monthLabel = _getMonthAbbreviation(monthNum);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          val.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 24,
                          height: 60 * pct + 10, // Ensure a minimum height
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accent,
                                AppColors.accent.withValues(alpha: 0.6),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          monthLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getMonthAbbreviation(int? month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return 'Mth';
    }
  }
}
