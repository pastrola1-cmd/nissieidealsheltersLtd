import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/earnings_provider.dart';
import 'package:ppn/providers/property_provider.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(earningsProvider.notifier).loadEarnings());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showBankDetailsDialog(Profile? profile) async {
    final bankController = TextEditingController(text: profile?.bankName);
    final numberController = TextEditingController(text: profile?.accountNumber);
    final nameController = TextEditingController(text: profile?.accountName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Payout Bank Account', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Provide the bank details where you wish to receive your commission payouts.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: bankController,
                        decoration: InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'e.g. GTBank, Access Bank',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Bank name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Account Number',
                          hintText: '10 digits',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Account number is required';
                          if (v.trim().length != 10 || int.tryParse(v) == null) {
                            return 'Enter a valid 10-digit account number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Account Name',
                          hintText: 'e.g. John Doe',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Account name is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            final success = await ref.read(earningsProvider.notifier).updateBankDetails(
                                  bankName: bankController.text.trim(),
                                  accountNumber: numberController.text.trim(),
                                  accountName: nameController.text.trim(),
                                );
                            if (!mounted) return;
                            setDialogState(() => isSaving = false);
                            if (success) {
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bank details saved successfully!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              final error = ref.read(earningsProvider).errorMessage ?? 'Failed to save details';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Details'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showWithdrawalDialog(double availableBalance, Profile? profile) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Request Payout', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance: ${currencyFormat.format(availableBalance)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Enter the amount you wish to withdraw. The request will be reviewed by administrators.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Withdrawal Amount (₦)',
                        hintText: 'e.g. 50000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) return 'Enter a valid amount greater than zero';
                        if (amount > availableBalance) return 'Insufficient available balance';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSubmitting = true);
                            final success = await ref.read(earningsProvider.notifier).requestWithdrawal(
                                  amount: double.parse(amountController.text.trim()),
                                );
                            if (!mounted) return;
                            setDialogState(() => isSubmitting = false);
                            if (success) {
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Withdrawal request submitted successfully!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              final error = ref.read(earningsProvider).errorMessage ?? 'Failed to submit request';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Request Payout'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(earningsProvider);
    final theme = Theme.of(context);
    final properties = ref.watch(propertyProvider).properties;
    final profile = ref.watch(authProvider).profile;

    // Calculate aggregate metrics
    final pendingTotal = state.commissions
        .where((c) => c.status == CommissionStatus.pending)
        .fold<double>(0.0, (sum, c) => sum + c.commissionAmount);

    final allTimeEarnings = state.commissions
        .where((c) => c.status == CommissionStatus.approved || c.status == CommissionStatus.paid)
        .fold<double>(0.0, (sum, c) => sum + c.commissionAmount);

    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Earnings & Wallet'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Commissions'),
            Tab(text: 'Transaction Ledger'),
          ],
        ),
      ),
      body: state.isLoading && state.commissions.isEmpty && state.transactions.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(earningsProvider.notifier).loadEarnings();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Balance cards grid ──
                      _buildBalanceDashboard(
                        balance: state.runningBalance,
                        pending: pendingTotal,
                        allTime: allTimeEarnings,
                        format: currencyFormat,
                        profile: profile,
                        theme: theme,
                      ),
                      const SizedBox(height: 28),

                      // ── Tabs List Area ──
                      SizedBox(
                        height: 500, // Fixed height for nested TabBar view
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildCommissionsList(state.commissions, properties, currencyFormat, theme),
                            _buildLedgerList(state.transactions, currencyFormat, theme),
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

  Widget _buildBalanceDashboard({
    required double balance,
    required double pending,
    required double allTime,
    required NumberFormat format,
    required Profile? profile,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        // Main wallet balance
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Withdrawable',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                format.format(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wallet Account Verified', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.successLight, size: 14),
                          const SizedBox(width: 4),
                          Text('Active', style: TextStyle(color: AppColors.successLight.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: (balance > 0 && profile?.bankName != null) ? () => _showWithdrawalDialog(balance, profile) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bank details setup card
        _buildBankDetailsCard(profile, theme),
        const SizedBox(height: 16),

        // Sub stats row
        Row(
          children: [
            Expanded(
              child: _buildSubStatCard(
                title: 'Pending Payout',
                value: format.format(pending),
                icon: Icons.hourglass_top_rounded,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSubStatCard(
                title: 'All-Time Earned',
                value: format.format(allTime),
                icon: Icons.emoji_events_outlined,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionsList(
    List<Commission> commissions,
    List<Property> properties,
    NumberFormat format,
    ThemeData theme,
  ) {
    if (commissions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.monetization_on_outlined,
        title: 'No commissions yet',
        subtitle: 'Referred sales that close successfully will earn payouts here.',
        theme: theme,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: commissions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comm = commissions[index];
        final property = properties.cast<Property?>().firstWhere((p) => p?.id == comm.propertyId, orElse: () => null);
        
        Color badgeColor;
        switch (comm.status) {
          case CommissionStatus.pending:
            badgeColor = Colors.orange;
            break;
          case CommissionStatus.approved:
            badgeColor = AppColors.success;
            break;
          case CommissionStatus.paid:
            badgeColor = Colors.teal;
            break;
          case CommissionStatus.disputed:
            badgeColor = AppColors.error;
            break;
        }

        // Calculation text
        String rateText = '';
        if (comm.commissionRate != null) {
          rateText = '${comm.commissionRate!.toStringAsFixed(1)}% of ${format.format(comm.salePrice)}';
        } else {
          rateText = 'Flat Payout Structure';
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      property?.title ?? 'Referred Sale Listing',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      comm.status.label.toUpperCase(),
                      style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EARNED PAYOUT', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(format.format(comm.commissionAmount), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accent, fontSize: 16)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('CALCULATION SPLIT', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(rateText, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBankDetailsCard(Profile? profile, ThemeData theme) {
    final hasBankDetails = profile?.bankName != null &&
        profile?.accountNumber != null &&
        profile?.accountName != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBankDetails ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasBankDetails
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasBankDetails ? Icons.account_balance_rounded : Icons.warning_amber_rounded,
              color: hasBankDetails ? AppColors.primary : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasBankDetails ? 'Payout Bank Account' : 'Missing Payout Details',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasBankDetails
                      ? '${profile!.bankName} · ${profile.accountNumber}\n${profile.accountName}'
                      : 'Configure your bank details to enable withdrawals.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _showBankDetailsDialog(profile),
            style: TextButton.styleFrom(
              foregroundColor: hasBankDetails ? AppColors.accent : AppColors.error,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            child: Text(hasBankDetails ? 'Edit' : 'Set Up'),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList(List<Transaction> transactions, NumberFormat format, ThemeData theme) {
    if (transactions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No transaction history',
        subtitle: 'Ledger debits and deposits will log here.',
        theme: theme,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isCredit = tx.type == TransactionType.credit;
        
        final color = isCredit ? AppColors.success : AppColors.error;
        final prefix = isCredit ? '+' : '-';
        final dateStr = DateFormat('MMM d, yyyy · HH:mm').format(tx.createdAt);

        // Show status badge for withdrawals
        Widget statusBadge = const SizedBox.shrink();
        if (tx.type == TransactionType.withdrawal) {
          Color statusColor;
          switch (tx.status) {
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
          statusBadge = Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.15)),
            ),
            child: Text(
              tx.status.label.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description ?? 'Wallet Transfer',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    statusBadge,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$prefix${format.format(tx.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
