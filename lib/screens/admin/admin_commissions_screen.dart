import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/earnings_provider.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/partner_provider.dart';
import 'package:ppn/providers/property_provider.dart';

class AdminCommissionsScreen extends ConsumerStatefulWidget {
  const AdminCommissionsScreen({super.key});

  @override
  ConsumerState<AdminCommissionsScreen> createState() => _AdminCommissionsScreenState();
}

class _AdminCommissionsScreenState extends ConsumerState<AdminCommissionsScreen> {
  final _searchController = TextEditingController();
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Approved', 'Paid', 'Disputed'
  String _searchQuery = '';
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(earningsProvider.notifier).loadEarnings();
      ref.read(partnerProvider.notifier).loadPartners(ref.read(authProvider).profile?.companyId);
      ref.read(leadProvider.notifier).loadLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove(Commission commission) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Payout Approval'),
          content: Text('Are you sure you want to approve this commission payout of ${NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0).format(commission.commissionAmount)} to the partner? This will instantly credit their available wallet balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Approve Payout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isActionInProgress = true);
      final success = await ref.read(earningsProvider.notifier).approvePayout(commission.id);
      setState(() => _isActionInProgress = false);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commission payout successfully approved and credited!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final error = ref.read(earningsProvider).errorMessage ?? 'Approval failed';
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
  }

  Future<void> _handleDispute(Commission commission) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Flag Payout as Disputed'),
          content: const Text('Are you sure you want to flag this commission payout as disputed? This holds the payout and notifies the partner.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Flag Dispute', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isActionInProgress = true);
      final success = await ref.read(earningsProvider.notifier).disputePayout(commission.id);
      setState(() => _isActionInProgress = false);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commission payout status set to disputed.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final error = ref.read(earningsProvider).errorMessage ?? 'Failed to dispute payout';
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
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(earningsProvider);
    final theme = Theme.of(context);

    // Resolvers
    final properties = ref.watch(propertyProvider).properties;
    final partners = ref.watch(partnerProvider).partners;
    final leads = ref.watch(leadProvider).leads;

    // Filters & Search
    final filtered = state.commissions.where((c) {
      final property = properties.cast<Property?>().firstWhere((p) => p?.id == c.propertyId, orElse: () => null);
      final partner = partners.cast<Profile?>().firstWhere((p) => p?.id == c.partnerId, orElse: () => null);
      final lead = leads.cast<Lead?>().firstWhere((l) => l?.id == c.leadId, orElse: () => null);

      final propTitle = property?.title.toLowerCase() ?? '';
      final partnerName = partner?.fullName?.toLowerCase() ?? '';
      final buyerName = lead?.buyerName.toLowerCase() ?? '';

      final matchesSearch = propTitle.contains(_searchQuery) ||
          partnerName.contains(_searchQuery) ||
          buyerName.contains(_searchQuery);

      final matchesStatus = _selectedStatusFilter == 'All' ||
          c.status.value.toLowerCase() == _selectedStatusFilter.replaceAll(' ', '_').toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Commissions Control Panel'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.isLoading && state.commissions.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                // Search bar and status tabs
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search commissions by buyer, property, or partner...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All',
                            'Pending',
                            'Approved',
                            'Paid',
                            'Disputed'
                          ].map((status) {
                            final isSelected = _selectedStatusFilter == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedStatusFilter = status;
                                    });
                                  }
                                },
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                                ),
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Payouts listing
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(earningsProvider.notifier).loadEarnings();
                    },
                    child: filtered.isEmpty
                        ? _buildEmptyState(theme)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final commission = filtered[index];
                              final property = properties.cast<Property?>().firstWhere((p) => p?.id == commission.propertyId, orElse: () => null);
                              final partner = partners.cast<Profile?>().firstWhere((p) => p?.id == commission.partnerId, orElse: () => null);
                              final lead = leads.cast<Lead?>().firstWhere((l) => l?.id == commission.leadId, orElse: () => null);
                              return _buildAdminCommissionCard(commission, property, partner, lead, currencyFormat, theme);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAdminCommissionCard(
    Commission commission,
    Property? property,
    Profile? partner,
    Lead? lead,
    NumberFormat format,
    ThemeData theme,
  ) {
    Color statusColor;
    switch (commission.status) {
      case CommissionStatus.pending:
        statusColor = Colors.orange;
        break;
      case CommissionStatus.approved:
        statusColor = AppColors.success;
        break;
      case CommissionStatus.paid:
        statusColor = Colors.teal;
        break;
      case CommissionStatus.disputed:
        statusColor = AppColors.error;
        break;
    }

    final dateStr = DateFormat('MMM d, yyyy').format(commission.createdAt);
    final partnerName = partner?.fullName ?? 'Direct client';
    final buyerName = lead?.buyerName ?? 'Buyer Client';

    // Calculation text
    String rateText = '';
    if (commission.commissionRate != null) {
      rateText = '${commission.commissionRate!.toStringAsFixed(1)}% of ${format.format(commission.salePrice)}';
    } else {
      rateText = 'Flat Payout';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Closed: $dateStr',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                ),
                child: Text(
                  commission.status.label.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          _buildItemRow(label: 'PARTNER', value: partnerName, icon: Icons.handshake_outlined),
          const SizedBox(height: 8),
          _buildItemRow(label: 'BUYER', value: buyerName, icon: Icons.person_outline_rounded),
          const SizedBox(height: 8),
          _buildItemRow(label: 'PROPERTY', value: property?.title ?? 'Unknown Property Listing', icon: Icons.home_work_outlined),
          const SizedBox(height: 8),
          _buildItemRow(label: 'FINAL SALE PRICE', value: format.format(commission.salePrice), icon: Icons.monetization_on_outlined),
          const SizedBox(height: 8),
          _buildItemRow(label: 'COMMISSION RATE', value: rateText, icon: Icons.calculate_outlined),
          const SizedBox(height: 8),
          _buildItemRow(label: 'COMMISSION AMOUNT', value: format.format(commission.commissionAmount), icon: Icons.wallet_outlined, isBoldAccent: true),

          if (commission.status == CommissionStatus.pending) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (_isActionInProgress)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDispute(commission),
                      icon: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: const Text('Dispute'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleApprove(commission),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve Payout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow({required String label, required String value, required IconData icon, bool isBoldAccent = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isBoldAccent ? AppColors.accent : AppColors.textPrimary,
              fontWeight: isBoldAccent ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.currency_exchange_rounded, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No commissions logged',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Commission records will appear here once deals close.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
