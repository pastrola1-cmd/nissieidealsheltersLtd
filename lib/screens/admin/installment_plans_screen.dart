import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/installment_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/services/pdf_receipt_service.dart';
import 'package:url_launcher/url_launcher.dart';

class InstallmentPlansScreen extends ConsumerStatefulWidget {
  const InstallmentPlansScreen({super.key});

  @override
  ConsumerState<InstallmentPlansScreen> createState() => _InstallmentPlansScreenState();
}

class _InstallmentPlansScreenState extends ConsumerState<InstallmentPlansScreen> {
  final _currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  String _filter = 'all'; // 'all', 'active', 'completed', 'overdue'

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentPlanProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final filteredPlans = state.plans.where((p) {
      if (_filter == 'active') return p.status == 'active';
      if (_filter == 'completed') return p.status == 'completed';
      if (_filter == 'overdue') return p.hasOverdue;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Installments & Cashflow Recovery',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Plans',
            onPressed: () => ref.read(paymentPlanProvider.notifier).loadPaymentPlans(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePlanDialog,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Installment Plan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: state.isLoading && state.plans.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () => ref.read(paymentPlanProvider.notifier).loadPaymentPlans(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 4 Executive KPI Cards ──
                    _buildKpiGrid(state, isMobile),
                    const SizedBox(height: 24),

                    // ── Filter Chips ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All Plans (${state.plans.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('active', 'Active (${state.totalActivePlans})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('overdue', 'Has Overdue (⚠️)'),
                          const SizedBox(width: 8),
                          _buildFilterChip('completed', 'Completed (✅)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Plans List ──
                    if (filteredPlans.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredPlans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (ctx, idx) => _buildPlanCard(filteredPlans[idx]),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiGrid(PaymentPlanState state, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: crossAxisCount == 4 ? 1.8 : 1.5,
          children: [
            _buildKpiCard(
              title: 'Active Plans',
              value: '${state.totalActivePlans}',
              subtitle: '${state.plans.length} Total Subscriptions',
              icon: Icons.assignment_outlined,
              color: AppColors.accent,
            ),
            _buildKpiCard(
              title: 'Inflow Expected',
              value: _currency.format(state.totalExpectedThisMonth),
              subtitle: 'Due this month',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF10B981),
            ),
            _buildKpiCard(
              title: 'Overdue Receivables',
              value: _currency.format(state.totalOverdueReceivables),
              subtitle: 'Requires Follow-up',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFEF4444),
            ),
            _buildKpiCard(
              title: 'Total Collected',
              value: _currency.format(state.totalCollectedToDate),
              subtitle: 'Lifetime collections',
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
      selectedColor: AppColors.accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accent : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildPlanCard(PaymentPlan plan) {
    final company = ref.read(authProvider).company;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.hasOverdue ? Colors.redAccent.withValues(alpha: 0.5) : AppColors.border,
          width: plan.hasOverdue ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.buyerName,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: plan.isCompleted
                                ? Colors.green.withValues(alpha: 0.12)
                                : (plan.hasOverdue ? Colors.red.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.12)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.isCompleted ? 'COMPLETED' : (plan.hasOverdue ? 'OVERDUE' : 'ACTIVE'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: plan.isCompleted ? Colors.green : (plan.hasOverdue ? Colors.red : Colors.blue),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.propertyName} ${plan.plotNumber != null ? '• Plot ${plan.plotNumber}' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_currency.format(plan.totalAmount), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  Text(
                    'Bal: ${_currency.format(plan.balanceAmount)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: plan.balanceAmount > 0 ? AppColors.error : AppColors.success),
                  ),
                ],
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Paid: ${_currency.format(plan.totalPaid)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('${(plan.progressPercent * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: plan.progressPercent,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(plan.isCompleted ? Colors.green : AppColors.accent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Plan Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (company != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => PdfReceiptService.generateAndPrintAllocationLetter(
                      company: company,
                      plan: plan,
                    ),
                    icon: const Icon(Icons.description_outlined, size: 14),
                    label: const Text('Allocation Letter', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => _sendWhatsAppReminder(plan),
                  icon: const Icon(Icons.send_rounded, size: 14, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp Reminder', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Milestone Timeline
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plan.milestones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) => _buildMilestoneRow(plan, plan.milestones[idx]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneRow(PaymentPlan plan, PaymentMilestone m) {
    final company = ref.read(authProvider).company;

    Color badgeColor = Colors.blue;
    String badgeText = 'PENDING';

    if (m.isPaid) {
      badgeColor = Colors.green;
      badgeText = 'PAID';
    } else if (m.isOverdue) {
      badgeColor = Colors.red;
      badgeText = 'OVERDUE';
    } else if (m.isPartial) {
      badgeColor = Colors.orange;
      badgeText = 'PARTIAL';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: m.isOverdue ? Colors.redAccent.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('${m.milestoneNumber}', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due: ${m.formattedDueDate}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                  ),
                  Text(
                    _currency.format(m.expectedAmount),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              if (!m.isPaid)
                ElevatedButton(
                  onPressed: () => _showLogPaymentDialog(m),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Log Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else if (company != null)
                IconButton(
                  icon: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.accent),
                  tooltip: 'Official Receipt PDF',
                  onPressed: () => PdfReceiptService.generateAndPrintReceipt(
                    company: company,
                    plan: plan,
                    milestone: m,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('No Payment Plans Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Create an installment plan for buyers paying in monthly milestones.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreatePlanDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Installment Plan'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogPaymentDialog(PaymentMilestone milestone) {
    final amountController = TextEditingController(text: milestone.remainingAmount.toStringAsFixed(0));
    final receiptController = TextEditingController(text: 'NIS/REC/${DateTime.now().year}/${DateTime.now().millisecondsSinceEpoch % 10000}');
    String method = 'Bank Transfer';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Log Milestone #${milestone.milestoneNumber} Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expected: ${_currency.format(milestone.expectedAmount)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount Paid (₦)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: receiptController,
              decoration: const InputDecoration(labelText: 'Receipt / Ref Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'POS / Card', child: Text('POS / Card')),
                DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              ],
              onChanged: (val) => method = val ?? 'Bank Transfer',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amount <= 0) return;

              Navigator.pop(ctx);
              final ok = await ref.read(paymentPlanProvider.notifier).logMilestonePayment(
                    milestoneId: milestone.id,
                    amount: amount,
                    receiptNumber: receiptController.text.trim(),
                    paymentMethod: method,
                  );

              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Payment recorded successfully!'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlanDialog() {
    final buyerNameCtrl = TextEditingController();
    final buyerPhoneCtrl = TextEditingController();
    final buyerEmailCtrl = TextEditingController();
    final propertyNameCtrl = TextEditingController();
    final plotCtrl = TextEditingController();
    final totalAmountCtrl = TextEditingController();
    final depositCtrl = TextEditingController(text: '0');
    int durationMonths = 6;
    DateTime startDate = DateTime.now();

    final propertiesState = ref.read(propertyProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final properties = propertiesState.properties;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Create New Installment Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: buyerNameCtrl,
                      decoration: const InputDecoration(labelText: 'Buyer Full Name *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: buyerPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Buyer Phone *', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: buyerEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Buyer Email', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (properties.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Select Estate / Property *', border: OutlineInputBorder()),
                        items: properties.map((p) => DropdownMenuItem(value: p.title, child: Text(p.title))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            propertyNameCtrl.text = val;
                          }
                        },
                      )
                    else
                      TextFormField(
                        controller: propertyNameCtrl,
                        decoration: const InputDecoration(labelText: 'Estate / Property Name *', border: OutlineInputBorder()),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: plotCtrl,
                      decoration: const InputDecoration(labelText: 'Plot Number (e.g. Plot 14, Block C)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: totalAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Total Price (₦) *', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: depositCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Initial Deposit (₦)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: durationMonths,
                      decoration: const InputDecoration(labelText: 'Installment Duration *', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 Months Installment')),
                        DropdownMenuItem(value: 6, child: Text('6 Months Installment')),
                        DropdownMenuItem(value: 12, child: Text('12 Months (1 Year)')),
                        DropdownMenuItem(value: 24, child: Text('24 Months (2 Years)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => durationMonths = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final name = buyerNameCtrl.text.trim();
                  final phone = buyerPhoneCtrl.text.trim();
                  final property = propertyNameCtrl.text.trim();
                  final total = double.tryParse(totalAmountCtrl.text.trim()) ?? 0.0;
                  final deposit = double.tryParse(depositCtrl.text.trim()) ?? 0.0;

                  if (name.isEmpty || phone.isEmpty || property.isEmpty || total <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all required fields.'), backgroundColor: AppColors.error),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  final ok = await ref.read(paymentPlanProvider.notifier).createPlan(
                        buyerName: name,
                        buyerPhone: phone,
                        buyerEmail: buyerEmailCtrl.text.trim().isNotEmpty ? buyerEmailCtrl.text.trim() : null,
                        propertyName: property,
                        plotNumber: plotCtrl.text.trim().isNotEmpty ? plotCtrl.text.trim() : null,
                        totalAmount: total,
                        initialDeposit: deposit,
                        durationMonths: durationMonths,
                        startDate: startDate,
                      );

                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🎉 Installment plan created with auto-milestones!'), backgroundColor: Colors.green),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                child: const Text('Create Plan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(PaymentPlan plan) async {
    final nextMilestone = plan.milestones.firstWhere(
      (m) => !m.isPaid,
      orElse: () => plan.milestones.first,
    );

    final cleanPhone = plan.buyerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = cleanPhone.startsWith('0') ? '234${cleanPhone.substring(1)}' : cleanPhone;

    final message = Uri.encodeComponent(
      'Dear ${plan.buyerName},\n\n'
      'This is a friendly reminder regarding your property subscription for *${plan.propertyName}* (${plan.plotNumber ?? "Plot Allocation"}).\n\n'
      '• Milestone #${nextMilestone.milestoneNumber} Due Date: *${nextMilestone.formattedDueDate}*\n'
      '• Amount Due: *${_currency.format(nextMilestone.expectedAmount)}*\n'
      '• Total Outstanding: *${_currency.format(plan.balanceAmount)}*\n\n'
      'Please proceed with payment to our official account and share your proof of payment for official receipt generation.\n\n'
      'Thank you,\nNissie Ideal Shelters Ltd',
    );

    final url = Uri.parse('https://wa.me/$formattedPhone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
