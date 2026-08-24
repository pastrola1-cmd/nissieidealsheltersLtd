import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final companyState = ref.watch(companyProvider);
    final profile = authState.profile;
    final company = companyState.company;
    final role = profile?.role ?? UserRole.buyer;
    final rolePath = role == UserRole.admin || role == UserRole.platformAdmin
        ? 'admin'
        : (role == UserRole.manager ? 'manager' : (role == UserRole.marketer ? 'marketer' : 'partner'));

    final isAdminOrManager = role == UserRole.admin || role == UserRole.platformAdmin || role == UserRole.manager;
    final isAdmin = role == UserRole.admin || role == UserRole.platformAdmin;

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Agency Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                        ? const Icon(Icons.business_rounded, color: AppColors.textTertiary, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          company?.name ?? 'Nissie Ideal Shelters',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile?.fullName ?? role.label,
                          style: const TextStyle(
                            fontSize: 12,
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

            // Scrollable Menu List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                children: [
                  // ── 1. OPERATIONS SECTION ──
                  _buildSectionHeader('OPERATIONS'),
                  const SizedBox(height: 6),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                    targetRoute: '/$rolePath/dashboard',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.assignment_outlined,
                    label: 'Leads Pipeline',
                    targetRoute: '/$rolePath/leads',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Deal Transactions',
                    targetRoute: '/admin/transactions',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.payments_outlined,
                    label: 'Installments & Recovery',
                    targetRoute: '/admin/installments',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.domain_outlined,
                    label: 'Properties',
                    targetRoute: '/$rolePath/properties',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.calendar_today_outlined,
                    label: 'Inspections',
                    targetRoute: '/admin/inspections',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Agent Tasks',
                    targetRoute: '/marketer/followups',
                  ),

                  const SizedBox(height: 20),

                  // ── 2. PEOPLE & STAFF ──
                  _buildSectionHeader('PEOPLE & STAFF'),
                  const SizedBox(height: 6),
                  if (isAdminOrManager) ...[
                    _buildMenuItem(
                      context: context,
                      icon: Icons.handshake_outlined,
                      label: 'Partners',
                      targetRoute: '/admin/partners',
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.badge_outlined,
                      label: 'Staff Management',
                      targetRoute: '/admin/staff',
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.person_add_outlined,
                      label: 'Staff Invite',
                      targetRoute: '/admin/invite-staff',
                    ),
                  ],
                  _buildMenuItem(
                    context: context,
                    icon: Icons.monetization_on_outlined,
                    label: 'Commissions',
                    targetRoute: '/admin/commissions',
                  ),
                  if (isAdmin)
                    _buildMenuItem(
                      context: context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Withdrawals & Payouts',
                      targetRoute: '/admin/withdrawals',
                    ),

                  const SizedBox(height: 20),

                  // ── 3. COMMUNICATION & ACADEMY ──
                  _buildSectionHeader('COMMUNICATION & ACADEMY'),
                  const SizedBox(height: 6),
                  if (isAdmin) ...[
                    _buildMenuItem(
                      context: context,
                      icon: Icons.email_outlined,
                      label: 'Bulk Email Portal',
                      targetRoute: '/admin/email-portal',
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.sms_outlined,
                      label: 'Bulk SMS Portal',
                      targetRoute: '/admin/sms-portal',
                    ),
                  ],
                  _buildMenuItem(
                    context: context,
                    icon: Icons.school_outlined,
                    label: 'Nissie Academy',
                    targetRoute: '/training',
                  ),
                  if (isAdminOrManager)
                    _buildMenuItem(
                      context: context,
                      icon: Icons.description_outlined,
                      label: 'Document Generator',
                      targetRoute: '/admin/documents',
                    ),

                  const SizedBox(height: 20),

                  // ── 4. REVENUE & MARKETING ──
                  _buildSectionHeader('REVENUE & MARKETING'),
                  const SizedBox(height: 6),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.bar_chart_rounded,
                    label: 'Campaign Attribution',
                    targetRoute: '/$rolePath/analytics',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.track_changes_rounded,
                    label: 'Goals & Targets',
                    targetRoute: '/admin/goals',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.summarize_outlined,
                    label: 'Daily Reports',
                    targetRoute: '/admin/reports',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.campaign_outlined,
                    label: 'AI Campaigns',
                    targetRoute: '/admin/campaigns',
                  ),

                  const SizedBox(height: 20),

                  // ── 5. SETTINGS & SYSTEM ──
                  if (isAdminOrManager) ...[
                    _buildSectionHeader('SETTINGS & SYSTEM'),
                    const SizedBox(height: 6),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.business_outlined,
                      label: 'Company Profile',
                      targetRoute: '/admin/company-profile',
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.credit_card_outlined,
                      label: 'Billing & Plans',
                      targetRoute: '/admin/billing',
                    ),
                    if (isAdmin)
                      _buildMenuItem(
                        context: context,
                        icon: Icons.settings_outlined,
                        label: 'System Settings',
                        targetRoute: '/admin/settings',
                      ),
                  ],
                ],
              ),
            ),

            // Logout Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String targetRoute,
  }) {
    final isSelected = currentRoute == targetRoute || currentRoute.startsWith('$targetRoute/');
    
    // Active styling: light mint green pill background and vibrant green icon/text
    final activeBg = const Color(0xFFE8F6F0);
    final activeColor = const Color(0xFF10B981);
    final inactiveColor = const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context); // Close drawer
            if (currentRoute != targetRoute) {
              context.push(targetRoute);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
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
}
