import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/providers/partner_provider.dart';
import 'package:ppn/providers/earnings_provider.dart';

class LeadDetailScreen extends ConsumerStatefulWidget {
  final String leadId;
  const LeadDetailScreen({super.key, required this.leadId});

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  late final TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final lead = ref.read(leadProvider).leads.cast<Lead?>().firstWhere((l) => l?.id == widget.leadId, orElse: () => null);
    _notesController = TextEditingController(text: lead?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _changeStage(LeadStage stage) async {
    if (stage == LeadStage.closed) {
      final lead = ref.read(leadProvider).leads.cast<Lead?>().firstWhere((l) => l?.id == widget.leadId, orElse: () => null);
      final property = ref.read(propertyProvider).properties.cast<Property?>().firstWhere((p) => p?.id == lead?.propertyId, orElse: () => null);
      if (lead != null) {
        _showCloseLeadDialog(lead, property);
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Lead Stage?'),
        content: Text('Are you sure you want to update this lead stage to "${stage.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: stage == LeadStage.lost ? AppColors.error : AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    final success = await ref.read(leadProvider.notifier).updateStage(
          widget.leadId,
          stage,
          notes: _notesController.text.trim(),
        );
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lead stage updated to ${stage.label}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(leadProvider).errorMessage ?? 'Stage update failed';
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

  Future<void> _showCloseLeadDialog(Lead lead, Property? property) async {
    final hasPartner = lead.partnerId != null;
    final double listPrice = property?.price ?? 0.0;
    final double commValue = property?.commissionValue ?? 0.0;
    final bool isPercent = property?.commissionType == CommissionType.percentage;

    final priceController = TextEditingController(text: listPrice.toStringAsFixed(0));
    final dialogFormKey = GlobalKey<FormState>();

    double finalPrice = listPrice;
    double calculatedComm = isPercent ? (finalPrice * (commValue / 100)) : commValue;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void recalculate(String val) {
              final parsed = double.tryParse(val) ?? 0.0;
              setState(() {
                finalPrice = parsed;
                calculatedComm = isPercent ? (finalPrice * (commValue / 100)) : commValue;
              });
            }

            return AlertDialog(
              title: const Text('Close Deal & Log Payout'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter the final agreed sale price for this property transaction.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Final Sale Price (₦)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: recalculate,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Enter sale price';
                        if (double.tryParse(value) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (hasPartner) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Commission Rate:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text(
                            isPercent ? '${commValue.toStringAsFixed(1)}%' : 'Flat Fee',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Expected Payout:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text(
                            NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0).format(calculatedComm),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accent, fontSize: 15),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        '⚠️ Note: This is a direct buyer lead (no partner referral). Closing this deal will not generate a partner commission payout.',
                        style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (dialogFormKey.currentState?.validate() ?? false) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  child: const Text('Close Lead', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      bool success = false;
      if (hasPartner) {
        success = await ref.read(earningsProvider.notifier).closeLeadWithCommission(
              leadId: lead.id,
              salePrice: finalPrice,
              commissionAmount: calculatedComm,
              propertyId: property!.id,
              partnerId: lead.partnerId!,
              commissionRate: isPercent ? commValue : null,
            );
      } else {
        success = await ref.read(leadProvider.notifier).updateStage(lead.id, LeadStage.closed);
      }
      setState(() => _isSaving = false);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead successfully closed and finalized.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final error = ref.read(leadProvider).errorMessage ?? 'Failed to close lead';
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

  Future<void> _saveNotes(LeadStage currentStage) async {
    setState(() => _isSaving = true);
    final success = await ref.read(leadProvider.notifier).updateStage(
          widget.leadId,
          currentStage,
          notes: _notesController.text.trim(),
        );
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(leadProvider).errorMessage ?? 'Notes save failed';
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
    final leadState = ref.watch(leadProvider);
    final authState = ref.watch(authProvider);
    final currentRole = authState.profile?.role;

    final Lead? lead = leadState.leads.cast<Lead?>().firstWhere(
          (l) => l?.id == widget.leadId,
          orElse: () => null,
        );

    if (lead == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lead Details')),
        body: const Center(child: Text('Lead details loading or not found...')),
      );
    }

    final property = ref.watch(propertyProvider).properties.cast<Property?>().firstWhere(
          (p) => p?.id == lead.propertyId,
          orElse: () => null,
        );

    final partner = ref.watch(partnerProvider).partners.cast<Profile?>().firstWhere(
          (p) => p?.id == lead.partnerId,
          orElse: () => null,
        );

    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final regDate = DateFormat('MMMM d, yyyy').format(lead.createdAt);

    Color stageColor;
    switch (lead.stage) {
      case LeadStage.newLead:
        stageColor = AppColors.stageNew;
        break;
      case LeadStage.contacted:
        stageColor = AppColors.stageContacted;
        break;
      case LeadStage.inspectionBooked:
        stageColor = AppColors.stageInspection;
        break;
      case LeadStage.negotiation:
        stageColor = AppColors.stageNegotiation;
        break;
      case LeadStage.closed:
        stageColor = AppColors.stageClosed;
        break;
      case LeadStage.lost:
        stageColor = AppColors.stageLost;
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lead Overview'),
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
            // ── Primary Lead Info Card ──
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lead.buyerName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stageColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: stageColor.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          lead.stage.label.toUpperCase(),
                          style: TextStyle(
                            color: stageColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  _buildDetailRow(
                    label: 'BUYER PHONE',
                    value: lead.buyerPhone,
                    icon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'BUYER EMAIL',
                    value: lead.buyerEmail ?? 'No email listed',
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'REFERRED PROPERTY',
                    value: property?.title ?? 'Unknown Property Listing',
                    subtitle: property != null ? currencyFormat.format(property.price) : null,
                    icon: Icons.home_work_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'ATTRIBUTED PARTNER',
                    value: partner?.fullName ?? 'Direct Client',
                    subtitle: partner != null ? 'Code: ${partner.referralCode}' : null,
                    icon: Icons.handshake_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'SOURCE CHANNEL',
                    value: lead.sourceChannel.toUpperCase(),
                    icon: Icons.campaign_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'DATE INITIATED',
                    value: regDate,
                    icon: Icons.calendar_month_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildAssignedAgentRow(context, ref, lead, currentRole),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Pipeline stage Stepper Changer ──
            Text(
              'Pipeline Stage Changer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    if (_isSaving)
                      const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    else
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: LeadStage.values.map((stage) {
                          final isCurrent = lead.stage == stage;
                          return ChoiceChip(
                            label: Text(stage.label),
                            selected: isCurrent,
                            onSelected: (selected) {
                              if (selected && !isCurrent) {
                                if (stage == LeadStage.closed) {
                                  _showCloseLeadDialog(lead, property);
                                } else {
                                  _changeStage(stage);
                                }
                              }
                            },
                            selectedColor: stageColor,
                            backgroundColor: AppColors.background,
                            labelStyle: TextStyle(
                              color: isCurrent ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isCurrent ? stageColor : AppColors.border),
                            ),
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Pipeline Tracker Timeline ──
            Text(
              'Sales Stage Progress',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildTimelineNode(
                      title: 'New',
                      subtitle: 'Lead created in the system',
                      isCompleted: true,
                      isLast: false,
                    ),
                    _buildTimelineNode(
                      title: 'Contacted',
                      subtitle: 'Buyer details verified by admin',
                      isCompleted: _isStagePassed(lead.stage, LeadStage.contacted),
                      isLast: false,
                    ),
                    _buildTimelineNode(
                      title: 'Inspection Booked',
                      subtitle: 'Inspection scheduled with partner',
                      isCompleted: _isStagePassed(lead.stage, LeadStage.inspectionBooked),
                      isLast: false,
                    ),
                    _buildTimelineNode(
                      title: 'Negotiation',
                      subtitle: 'Buyer is discussing offer details',
                      isCompleted: _isStagePassed(lead.stage, LeadStage.negotiation),
                      isLast: false,
                    ),
                    _buildTimelineNode(
                      title: 'Closed / Finalized',
                      subtitle: 'Deal closed successfully or marked lost',
                      isCompleted: lead.stage == LeadStage.closed || lead.stage == LeadStage.lost,
                      isLast: true,
                      customLabelColor: lead.stage == LeadStage.lost ? AppColors.error : (lead.stage == LeadStage.closed ? AppColors.success : null),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Admin follow-up notes editor ──
            Text(
              'Follow-up & Notes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter lead negotiation logs, call history details...',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: () => _saveNotes(lead.stage),
                              icon: const Icon(Icons.save_rounded, size: 18),
                              label: const Text('Save Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  bool _isStagePassed(LeadStage current, LeadStage target) {
    const list = [
      LeadStage.newLead,
      LeadStage.contacted,
      LeadStage.inspectionBooked,
      LeadStage.negotiation,
      LeadStage.closed,
      LeadStage.lost,
    ];
    final currentIndex = list.indexOf(current);
    final targetIndex = list.indexOf(target);
    return currentIndex >= targetIndex || current == LeadStage.closed || current == LeadStage.lost;
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    String? subtitle,
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
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isLast,
    Color? customLabelColor,
  }) {
    final activeColor = customLabelColor ?? AppColors.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? activeColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? activeColor : AppColors.border,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Center(
                      child: Icon(Icons.check, size: 12, color: Colors.white),
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? activeColor : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? (customLabelColor ?? AppColors.textPrimary) : AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedAgentRow(BuildContext context, WidgetRef ref, Lead lead, UserRole? role) {
    final canAssign = role == UserRole.admin || role == UserRole.manager || role == UserRole.platformAdmin;
    
    if (!canAssign) {
      if (lead.assignedAgentId == null) {
        return _buildDetailRow(
          label: 'ASSIGNED AGENT',
          value: 'Unassigned',
          icon: Icons.person_outline,
        );
      }
      
      return FutureBuilder<Profile?>(
        future: ref.read(supabaseServiceProvider).getProfile(lead.assignedAgentId!),
        builder: (context, snapshot) {
          final name = snapshot.data?.fullName ?? 'Loading agent name...';
          return _buildDetailRow(
            label: 'ASSIGNED AGENT',
            value: name,
            icon: Icons.person_outline,
          );
        },
      );
    }
    
    final marketersAsync = ref.watch(agencyMarketersProvider);
    
    return marketersAsync.when(
      data: (agents) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.person_outline, size: 20, color: AppColors.textTertiary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ASSIGNED AGENT',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: lead.assignedAgentId,
                      isExpanded: true,
                      hint: const Text('Unassigned (Select Agent)', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned', style: TextStyle(fontSize: 14)),
                        ),
                        ...agents.map((agent) {
                          return DropdownMenuItem<String?>(
                            value: agent.id,
                            child: Text(agent.fullName ?? agent.email ?? '', style: const TextStyle(fontSize: 14)),
                          );
                        }),
                      ],
                      onChanged: (newAgentId) async {
                        final success = await ref.read(leadProvider.notifier).assignAgent(lead.id, newAgentId);
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Agent assigned successfully!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to assign agent.'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (err, stack) => Text('Error loading agents: $err'),
    );
  }
}
