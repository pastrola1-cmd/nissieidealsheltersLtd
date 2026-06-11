import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/platform_provider.dart';

class PlatformDashboardScreen extends ConsumerWidget {
  const PlatformDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(platformProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'PPN SaaS Platform Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () => ref.read(platformProvider.notifier).loadPlatformData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: AppColors.errorDark),
                        ),
                      ),

                    // ── 1. Stats Overview ──
                    _buildStatsRow(state),
                    const SizedBox(height: 32),

                    // ── 2. Header and Add Company ──
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registered Tenant Agencies',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddCompanyDialog(context, ref),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Onboard Agency', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Registered Tenant Agencies',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showAddCompanyDialog(context, ref),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Onboard Agency'),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),

                    // ── 3. Companies List ──
                    if (state.companies.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0),
                          child: Text(
                            'No registered companies yet.',
                            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.companies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final companyData = state.companies[index];
                          return _buildCompanyCard(context, ref, companyData);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow(PlatformState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = (constraints.maxWidth - 32) / 3;
        final bool isSmall = constraints.maxWidth < 600;

        final items = [
          _buildStatCard('Total Tenants', state.companies.length.toString(), Icons.domain, AppColors.primary),
          _buildStatCard('Total Listings', state.totalProperties.toString(), Icons.home_work, AppColors.success),
          _buildStatCard('Total Partners', state.totalPartners.toString(), Icons.group, AppColors.info),
        ];

        if (isSmall) {
          return Column(
            children: items.map((card) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SizedBox(width: double.infinity, child: card),
            )).toList(),
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(BuildContext context, WidgetRef ref, PlatformCompanyData data) {
    final company = data.company;
    final isSuspended = data.status == 'suspended';
    final isPending = data.status == 'pending';
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSuspended
              ? AppColors.error.withOpacity(0.3)
              : (isPending
                  ? AppColors.warning.withOpacity(0.3)
                  : AppColors.border),
          width: (isSuspended || isPending) ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Logo & Name/Badge Stack
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    image: company.logoUrl != null
                        ? DecorationImage(image: NetworkImage(company.logoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: company.logoUrl == null
                      ? const Icon(Icons.business_rounded, color: AppColors.textTertiary, size: 24)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSuspended
                                  ? AppColors.errorLight
                                  : (isPending ? AppColors.warningLight : AppColors.successLight),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSuspended
                                  ? 'SUSPENDED'
                                  : (isPending ? 'PENDING APPROVAL' : 'ACTIVE'),
                              style: TextStyle(
                                color: isSuspended
                                    ? AppColors.errorDark
                                    : (isPending ? AppColors.warningDark : AppColors.successDark),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (company.isHidden)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'HIDDEN FROM SIGNUP',
                                style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            
            // Full-width Tenant ID Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        company.id,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: company.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tenant ID copied to clipboard.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.accent),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _buildCardDetail('Properties', data.propertiesCount.toString()),
                _buildCardDetail('Partners', data.partnersCount.toString()),
                _buildCardDetail('Admins', data.admins.length.toString()),
                _buildCardDetail('Managers', data.managersCount.toString()),
                _buildCardDetail('Marketers', data.marketersCount.toString()),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subscription Plan',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: company.subscriptionTier == 'enterprise'
                                  ? Colors.amber[700]
                                  : (company.subscriptionTier == 'growth'
                                      ? Colors.blue[700]
                                      : Colors.grey[700]),
                            ),
                            const SizedBox(width: 4),
                             Text(
                              '${company.subscriptionTier.toUpperCase()} (Limit: ${company.effectiveLeadLimit >= 999999 ? 'Unlimited' : company.effectiveLeadLimit})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status & Expires At',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${company.subscriptionStatus.toUpperCase()} (${company.subscriptionExpiresAt != null ? company.subscriptionExpiresAt!.toLocal().toString().split(' ')[0] : 'Never'})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: company.subscriptionStatus == 'active' || company.subscriptionStatus == 'trialing'
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar_rounded, color: AppColors.accent),
                    tooltip: 'Modify Subscription',
                    onPressed: () => _showEditSubscriptionDialog(context, ref, company),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Row 3: Admin User List & Contact Info (Responsive layout)
            if (data.admins.isNotEmpty) ...[
              const Text(
                'Admins:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              ...data.admins.map((admin) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${admin.fullName} (${admin.email})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (admin.phone != null && admin.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 8),
                          Text(
                            admin.phone!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],

            // Row 4: Action Toggles (Suspend / Reactivate / Approve)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                // ── Delete Button ──
                OutlinedButton.icon(
                  onPressed: () => _deleteCompany(context, ref, company),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete'),
                ),
                
                // ── Visibility Toggle Button ──
                OutlinedButton.icon(
                  onPressed: () => ref.read(platformProvider.notifier).toggleCompanyVisibility(company.id, !company.isHidden),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(company.isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 16),
                  label: Text(company.isHidden ? 'Show in Dropdown' : 'Hide from Dropdown'),
                ),

                // ── Suspend / Reactivate / Approve Button ──
                if (isPending)
                  ElevatedButton.icon(
                    onPressed: () => _approveCompany(context, ref, company.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve Tenant'),
                  )
                else if (isSuspended)
                  ElevatedButton.icon(
                    onPressed: () => _toggleStatus(context, ref, company.id, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Reactivate Company'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _toggleStatus(context, ref, company.id, true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Suspend Account'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetail(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _approveCompany(BuildContext context, WidgetRef ref, String companyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Tenant?'),
        content: const Text('Are you sure you want to approve this tenant agency? Their admin status will change to APPROVED, allowing them to access their dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(platformProvider.notifier).approveCompany(companyId);
    }
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, String companyId, bool suspend) async {
    final title = suspend ? 'Suspend Tenant?' : 'Reactivate Tenant?';
    final content = suspend
        ? 'Are you sure you want to suspend this company? All administrators from this agency will be locked out of the system.'
        : 'Are you sure you want to reactivate this company? Administrators will regain access to their dashboards.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: suspend ? AppColors.error : AppColors.success),
            child: Text(suspend ? 'Suspend' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(platformProvider.notifier).toggleCompanyStatus(companyId, suspend);
    }
  }

  Future<void> _deleteCompany(BuildContext context, WidgetRef ref, Company company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${company.name}?'),
        content: const Text(
          'WARNING: This will permanently delete the agency and all its listings, leads, commissions, and transaction history.\n\nThis action cannot be undone. Are you sure you want to proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(platformProvider.notifier).deleteCompany(company.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agency deleted successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddCompanyDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onboard New Agency'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Agency/Company Name *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Contact Email'),
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Contact Phone'),
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Office Address'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final success = await ref.read(platformProvider.notifier).createCompany(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                      address: addressController.text.trim(),
                    );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Company onboarded successfully! Copy its Tenant ID from the dashboard list.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditSubscriptionDialog(BuildContext context, WidgetRef ref, Company company) {
    final formKey = GlobalKey<FormState>();
    String selectedTier = company.subscriptionTier;
    String selectedStatus = company.subscriptionStatus;
    DateTime selectedDate = company.subscriptionExpiresAt ?? DateTime.now().add(const Duration(days: 14));
    final customLimitController = TextEditingController(
      text: company.customLeadLimit != null ? company.customLeadLimit.toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Modify Subscription: ${company.name}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedTier,
                    decoration: const InputDecoration(labelText: 'Subscription Plan Tier'),
                    items: const [
                      DropdownMenuItem(value: 'basic', child: Text('Basic (₦25,000/mo)')),
                      DropdownMenuItem(value: 'growth', child: Text('Growth (₦50,000/mo)')),
                      DropdownMenuItem(value: 'enterprise', child: Text('Enterprise (₦100,000/mo)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedTier = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'trialing', child: Text('Trialing')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'past_due', child: Text('Past Due')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: customLimitController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Lead Limit (Override)',
                      hintText: 'Leave empty for plan default (150/500/unlimited)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expiration Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            selectedDate.toLocal().toString().split(' ')[0],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Pick Date'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final customLimitText = customLimitController.text.trim();
                final customLimit = customLimitText.isEmpty ? null : int.tryParse(customLimitText);

                final success = await ref.read(platformProvider.notifier).updateCompanySubscription(
                      company.id,
                      tier: selectedTier,
                      status: selectedStatus,
                      expiresAt: selectedDate,
                      customLeadLimit: customLimit,
                    );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subscription updated successfully!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
