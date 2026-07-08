import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/earnings_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';

class AdminWithdrawalsScreen extends ConsumerStatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  ConsumerState<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends ConsumerState<AdminWithdrawalsScreen> {
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Completed', 'Rejected'
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(earningsProvider.notifier).loadEarnings();
      ref.read(partnerProvider.notifier).loadPartners(ref.read(authProvider).profile?.companyId);
    });
  }

  Future<void> _handleApprove(Transaction transaction, Profile? partner) async {
    final formattedAmount = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0).format(transaction.amount);
    final bankDetails = partner != null ? '${partner.bankName} (${partner.accountNumber})' : 'N/A';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Payment'),
          content: Text('Are you sure you have completed the bank transfer of $formattedAmount to the partner\'s bank account?\n\nTarget bank: $bankDetails\nAccount Name: ${partner?.accountName ?? "N/A"}\n\nThis will mark the withdrawal as completed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Mark as Paid', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isActionInProgress = true);
      final success = await ref.read(earningsProvider.notifier).resolveWithdrawalRequest(transaction.id, TransactionStatus.completed);
      setState(() => _isActionInProgress = false);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal marked as completed and paid!'),
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

  Future<void> _handleReject(Transaction transaction, Profile? partner) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Withdrawal Request'),
          content: const Text('Are you sure you want to reject this withdrawal request? This will instantly refund the requested amount back to the partner\'s wallet balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reject & Refund', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isActionInProgress = true);
      final success = await ref.read(earningsProvider.notifier).resolveWithdrawalRequest(transaction.id, TransactionStatus.rejected);
      setState(() => _isActionInProgress = false);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request rejected. Funds refunded to partner.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final error = ref.read(earningsProvider).errorMessage ?? 'Rejection failed';
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
    final partners = ref.watch(partnerProvider).partners;

    // Filter only withdrawal transactions
    final allWithdrawals = state.transactions.where((tx) => tx.type == TransactionType.withdrawal).toList();

    // Apply status filter
    final filtered = allWithdrawals.where((tx) {
      if (_selectedStatusFilter == 'All') return true;
      return tx.status.value.toLowerCase() == _selectedStatusFilter.toLowerCase();
    }).toList();

    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Withdrawals Control Panel'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.isLoading && state.transactions.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                // Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        'Pending',
                        'Completed',
                        'Rejected'
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
                ),

                // Payout requests listing
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
                              final tx = filtered[index];
                              final partner = partners.cast<Profile?>().firstWhere((p) => p?.id == tx.partnerId, orElse: () => null);
                              return _buildWithdrawalCard(tx, partner, currencyFormat, theme);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWithdrawalCard(
    Transaction transaction,
    Profile? partner,
    NumberFormat format,
    ThemeData theme,
  ) {
    Color statusColor;
    switch (transaction.status) {
      case TransactionStatus.pending:
        statusColor = Colors.orange;
        break;
      case TransactionStatus.completed:
        statusColor = AppColors.success;
        break;
      case TransactionStatus.rejected:
        statusColor = AppColors.error;
        break;
    }

    final dateStr = DateFormat('MMM d, yyyy · HH:mm').format(transaction.createdAt);
    final partnerName = partner?.fullName ?? 'Unknown Partner';
    final bankName = partner?.bankName ?? 'Not configured';
    final accountNumber = partner?.accountNumber ?? 'Not configured';
    final accountName = partner?.accountName ?? 'Not configured';

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
                'Requested: $dateStr',
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
                  transaction.status.label.toUpperCase(),
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

          _buildItemRow(label: 'PARTNER', value: partnerName, icon: Icons.person_outline_rounded),
          const SizedBox(height: 8),
          _buildItemRow(label: 'BANK NAME', value: bankName, icon: Icons.business_rounded),
          const SizedBox(height: 8),
          _buildItemRow(label: 'ACCOUNT NUMBER', value: accountNumber, icon: Icons.credit_card_rounded),
          const SizedBox(height: 8),
          _buildItemRow(label: 'ACCOUNT NAME', value: accountName, icon: Icons.badge_outlined),
          const SizedBox(height: 8),
          _buildItemRow(label: 'REQUEST AMOUNT', value: format.format(transaction.amount), icon: Icons.wallet_outlined, isBoldAccent: true),

          if (transaction.status == TransactionStatus.pending) ...[
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
                      onPressed: () => _handleReject(transaction, partner),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Reject'),
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
                      onPressed: () => _handleApprove(transaction, partner),
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: const Text('Mark as Paid'),
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
              'No payouts logged',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Withdrawal requests from partners will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
