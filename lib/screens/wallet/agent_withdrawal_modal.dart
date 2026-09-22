import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/wallet.dart';
import 'package:nissie_ideal_shelters/providers/wallet_provider.dart';
import 'package:nissie_ideal_shelters/services/paystack_service.dart';

class AgentWithdrawalModal extends ConsumerStatefulWidget {
  const AgentWithdrawalModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AgentWithdrawalModal(),
    );
  }

  @override
  ConsumerState<AgentWithdrawalModal> createState() => _AgentWithdrawalModalState();
}

class _AgentWithdrawalModalState extends ConsumerState<AgentWithdrawalModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  late NigerianBank _selectedBank;
  bool _isResolvingAccount = false;
  bool _isWithdrawing = false;
  bool _withdrawalSuccess = false;
  double? _withdrawnAmount;

  final List<NigerianBank> _banks = PaystackService.defaultBanks;

  @override
  void initState() {
    super.initState();
    _selectedBank = _banks.firstWhere(
      (b) => b.code == '058',
      orElse: () => _banks.first,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _onAccountNumberChanged(String val) async {
    final clean = val.trim();
    if (clean.length == 10) {
      setState(() => _isResolvingAccount = true);
      final result = await ref.read(paystackServiceProvider).resolveAccountNumber(
        accountNumber: clean,
        bankCode: _selectedBank.code,
      );
      if (mounted) {
        setState(() {
          _isResolvingAccount = false;
          if (result.isValid) {
            _accountNameController.text = result.accountName;
          }
        });
      }
    } else {
      if (_accountNameController.text.isNotEmpty) {
        setState(() => _accountNameController.clear());
      }
    }
  }

  Future<void> _handleWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final wallet = ref.read(walletProvider).wallet;

    if (amount < 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum withdrawal amount is ₦2,000'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (amount > wallet.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. Max available: ₦${NumberFormat('#,##0').format(wallet.balance)}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isWithdrawing = true);

    final success = await ref.read(walletProvider.notifier).requestWithdrawal(
      amount: amount,
      bankCode: _selectedBank.code,
      bankName: _selectedBank.name,
      accountNumber: _accountNumberController.text.trim(),
      accountName: _accountNameController.text.trim().isNotEmpty
          ? _accountNameController.text.trim()
          : 'Verified Agent Account',
    );

    if (mounted) {
      setState(() {
        _isWithdrawing = false;
        _withdrawalSuccess = success;
        _withdrawnAmount = amount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider).wallet;
    final currencyFormat = NumberFormat('#,##0.00');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _withdrawalSuccess ? _buildSuccessView() : _buildWithdrawalForm(wallet, currencyFormat),
        ),
      ),
    );
  }

  Widget _buildWithdrawalForm(Wallet wallet, NumberFormat currencyFormat) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance, color: Colors.green.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Bank Payout',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Instant Withdrawal to any Nigerian Commercial Bank',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Available balance card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Earnings for Payout',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${currencyFormat.format(wallet.balance)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    _amountController.text = wallet.balance.toStringAsFixed(0);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Withdraw All', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bank Selector
          const Text('Select Your Bank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          DropdownButtonFormField<NigerianBank>(
            value: _selectedBank,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _banks.map((bank) {
              return DropdownMenuItem<NigerianBank>(
                value: bank,
                child: Text(bank.name, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (bank) {
              if (bank != null) {
                setState(() => _selectedBank = bank);
                if (_accountNumberController.text.length == 10) {
                  _onAccountNumberChanged(_accountNumberController.text);
                }
              }
            },
          ),
          const SizedBox(height: 16),

          // Account Number (NUBAN)
          const Text('10-Digit NUBAN Account Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            onChanged: _onAccountNumberChanged,
            decoration: InputDecoration(
              hintText: 'e.g. 0123456789',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(Icons.numbers, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _isResolvingAccount
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            validator: (val) {
              if (val == null || val.trim().length != 10) {
                return 'Please enter a valid 10-digit NUBAN account number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Resolved Account Name
          if (_accountNameController.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account Name: ${_accountNameController.text}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Withdrawal Amount
          const Text('Amount to Withdraw (₦)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Min. ₦2,000',
              prefixText: '₦ ',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter withdrawal amount';
              final amt = double.tryParse(val.replaceAll(',', '').trim());
              if (amt == null || amt < 2000) return 'Minimum withdrawal is ₦2,000';
              if (amt > wallet.balance) return 'Amount exceeds available balance';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isWithdrawing ? null : _handleWithdrawal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isWithdrawing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Confirm & Transfer to Bank',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final currencyFormat = NumberFormat('#,##0.00');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 54),
        ),
        const SizedBox(height: 16),
        const Text(
          'Withdrawal Initiated!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Text(
          '₦${currencyFormat.format(_withdrawnAmount ?? 0)} is being transferred directly to your ${_selectedBank.name} account (${_accountNumberController.text}).',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
