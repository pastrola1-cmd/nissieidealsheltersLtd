import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/partner_provider.dart';
import 'package:ppn/providers/company_provider.dart';

class PartnerDetailScreen extends ConsumerStatefulWidget {
  final String partnerId;
  const PartnerDetailScreen({super.key, required this.partnerId});

  @override
  ConsumerState<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends ConsumerState<PartnerDetailScreen> {
  bool _isActionLoading = false;

  Future<void> _updateStatus(
    String action,
    Future<bool> Function() apiCall,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action Partner?'),
        content: Text('Are you sure you want to ${action.toLowerCase()} this partner account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'Reject' || action == 'Suspend' ? AppColors.error : AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    final success = await apiCall();
    if (mounted) {
      setState(() => _isActionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partner status updated successfully ($action).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(partnerProvider).errorMessage ?? 'Action failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partnerState = ref.watch(partnerProvider);
    final companyName = ref.watch(companyProvider).company?.name ?? 'ScaleWealthEstate';

    // Find the partner in local state
    final Profile? partner = partnerState.partners.cast<Profile?>().firstWhere(
          (p) => p?.id == widget.partnerId,
          orElse: () => null,
        );

    if (partner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partner Details')),
        body: const Center(
          child: Text('Partner not found or loading...'),
        ),
      );
    }

    final regDate = DateFormat('MMMM d, yyyy').format(partner.createdAt);

    Color statusColor;
    IconData statusIcon;
    switch (partner.status) {
      case PartnerStatus.pending:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case PartnerStatus.approved:
        statusColor = AppColors.success;
        statusIcon = Icons.verified_rounded;
        break;
      case PartnerStatus.rejected:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      case PartnerStatus.suspended:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.block_rounded;
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Review'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main Profile Card ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar & Basic Info
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                          image: partner.avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(partner.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: partner.avatarUrl == null
                            ? Center(
                                child: Text(
                                  partner.fullName != null && partner.fullName!.isNotEmpty
                                      ? partner.fullName!
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .map((s) => s[0])
                                          .take(2)
                                          .join()
                                          .toUpperCase()
                                      : 'PT',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partner.fullName ?? 'Unnamed Partner',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, color: statusColor, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    partner.status.label.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),

                  // Contact Details
                  _buildDetailRow(
                    label: 'EMAIL ADDRESS',
                    value: partner.email ?? 'No email listed',
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'PHONE NUMBER',
                    value: partner.phone ?? 'No phone listed',
                    icon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'REGISTRATION DATE',
                    value: regDate,
                    icon: Icons.calendar_month_outlined,
                  ),

                  // Referral Code Panel (if approved)
                  if (partner.status == PartnerStatus.approved && partner.referralCode != null) ...[
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'REFERRAL CODE',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  partner.referralCode!,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: AppColors.accent),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: partner.referralCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Referral code copied to clipboard!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            tooltip: 'Copy Referral Code',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Performance Metrics Card (Mock Data) ──
            Text(
              'Activity & Performance Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.9,
              children: [
                _buildMetricCard(
                  title: 'Leads Referred',
                  value: '0',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.info,
                ),
                _buildMetricCard(
                  title: 'Inspections',
                  value: '0',
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.warning,
                ),
                _buildMetricCard(
                  title: 'Total Earnings',
                  value: '₦0',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Status Action Buttons ──
            if (_isActionLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else
              _buildActionPanel(context, partner, companyName, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textTertiary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(
    BuildContext context,
    Profile partner,
    String companyName,
    ThemeData theme,
  ) {
    if (partner.status == PartnerStatus.pending) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _updateStatus(
                'Approve',
                () => ref
                    .read(partnerProvider.notifier)
                    .approvePartner(partner.id, partner.fullName ?? '', companyName),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Approve Partner & Generate Referral Code',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _updateStatus(
                'Reject',
                () => ref.read(partnerProvider.notifier).rejectPartner(partner.id),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Reject Application',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (partner.status == PartnerStatus.approved) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _updateStatus(
            'Suspend',
            () => ref.read(partnerProvider.notifier).suspendPartner(partner.id),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            'Suspend Partner Account',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      // Suspended or Rejected -> Allow Approving (Re-enabling)
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _updateStatus(
            'Activate',
            () => ref
                .read(partnerProvider.notifier)
                .approvePartner(partner.id, partner.fullName ?? '', companyName),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            partner.status == PartnerStatus.suspended ? 'Re-activate Partner Account' : 'Approve Partner Account',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }
}
