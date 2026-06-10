import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/company_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companyState = ref.watch(companyProvider);
    final authState = ref.watch(authProvider);

    final company = companyState.company;
    final profile = authState.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
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

              // ── Welcome Text ──
              Text(
                'Welcome back, ${profile?.fullName?.split(' ').first ?? 'Admin'}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Here is your sales performance overview.',
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
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(
                    title: 'Total Listings',
                    value: '0',
                    icon: Icons.home_work_outlined,
                    color: AppColors.accent,
                  ),
                  _buildStatCard(
                    title: 'Active Partners',
                    value: '0',
                    icon: Icons.handshake_outlined,
                    color: Colors.purple,
                  ),
                  _buildStatCard(
                    title: 'Open Leads',
                    value: '0',
                    icon: Icons.trending_up_rounded,
                    color: Colors.amber.shade800,
                  ),
                  _buildStatCard(
                    title: 'Sales Value',
                    value: '₦0.00',
                    icon: Icons.monetization_on_outlined,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 32),

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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
