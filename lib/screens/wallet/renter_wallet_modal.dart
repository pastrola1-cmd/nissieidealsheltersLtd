import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/wallet_provider.dart';
import 'package:nissie_ideal_shelters/services/paystack_service.dart';

class RenterWalletModal extends ConsumerStatefulWidget {
  const RenterWalletModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RenterWalletModal(),
    );
  }

  @override
  ConsumerState<RenterWalletModal> createState() => _RenterWalletModalState();
}

class _RenterWalletModalState extends ConsumerState<RenterWalletModal> {
  final _amountController = TextEditingController();
  bool _isFunding = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleFund(double amount) async {
    setState(() => _isFunding = true);
    final paystack = ref.read(paystackServiceProvider);
    final refCode = paystack.generateReference();
    final authState = ref.read(authProvider);
    final email = authState.profile?.email ?? 'renter@nissie.com';

    await paystack.launchPaystackCheckout(
      email: email,
      amountInNaira: amount,
      reference: refCode,
      userId: authState.profile?.id,
      onError: (msg) {
        if (mounted) {
          setState(() => _isFunding = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
          );
        }
      },
      onSuccess: (verifiedRef) async {
        final success = await ref.read(walletProvider.notifier).fundWallet(
          amount: amount,
          method: 'Paystack Card / Transfer',
          reference: verifiedRef,
        );
        if (mounted) {
          setState(() => _isFunding = false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('₦${NumberFormat('#,##0').format(amount)} successfully deposited via Paystack! (Ref: $verifiedRef)'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _amountController.clear();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ref.read(walletProvider).errorMessage ??
                      'Deposit not confirmed. If you were charged, it will appear shortly.',
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      },
      onCancel: () {
        if (mounted) {
          setState(() => _isFunding = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final transactions = walletState.transactions;
    final currencyFormat = NumberFormat('#,##0.00');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nissie Digital Wallet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Real Deposits & Automated Site Tour Payments',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Balance Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
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
                              'AVAILABLE CASH BALANCE',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.1,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                                  SizedBox(width: 4),
                                  Text('Active', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '₦${currencyFormat.format(wallet.balance)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (wallet.ledgerBalance > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.lock_clock, size: 14, color: Colors.amberAccent.shade100),
                              const SizedBox(width: 6),
                              Text(
                                '₦${currencyFormat.format(wallet.ledgerBalance)} held in pending site tour deposits',
                                style: TextStyle(fontSize: 12, color: Colors.amberAccent.shade100),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Fund Buttons
                  const Text('Quick Deposit / Fund Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildPresetChip(3000, '₦3,000 (1 Tour)'),
                      _buildPresetChip(6000, '₦6,000 (2 Tours)'),
                      _buildPresetChip(10000, '₦10,000 (3 Tours)'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Custom Deposit Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter custom amount in ₦',
                            prefixText: '₦ ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isFunding
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.add_card, color: Colors.white, size: 18),
                        label: const Text('Deposit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: _isFunding
                            ? null
                            : () {
                                final parsed = double.tryParse(_amountController.text.replaceAll(',', '').trim());
                                if (parsed != null && parsed >= 500) {
                                  _handleFund(parsed);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid deposit amount (min ₦500)')),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Transaction History Header
                  const Text('Wallet Activity & Real Deposits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),

                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...transactions.map((tx) => _buildTransactionTile(tx)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(double amount, String label) {
    return InkWell(
      onTap: _isFunding ? null : () => _handleFund(amount),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(dynamic tx) {
    final isInflow = tx.isInflow as bool;
    final amount = tx.amount as double;
    final description = tx.description as String? ?? 'Wallet Transaction';
    final dateStr = DateFormat('dd MMM, hh:mm a').format(tx.createdAt as DateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isInflow ? Colors.green.shade50 : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isInflow ? Icons.arrow_downward : Icons.arrow_upward,
              color: isInflow ? Colors.green.shade700 : Colors.red.shade700,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(
            '${isInflow ? '+' : '-'}₦${NumberFormat('#,##0').format(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isInflow ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
