import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/sms_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/widgets/shimmer_loading.dart';
import 'package:nissie_ideal_shelters/widgets/empty_state.dart';

class AdminSmsPortalScreen extends ConsumerStatefulWidget {
  const AdminSmsPortalScreen({super.key});

  @override
  ConsumerState<AdminSmsPortalScreen> createState() => _AdminSmsPortalScreenState();
}

class _AdminSmsPortalScreenState extends ConsumerState<AdminSmsPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedGroup = 'leads'; // 'leads', 'partners', 'staff'
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _messageController.addListener(() {
      setState(() {
        _charCount = _messageController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smsState = ref.watch(smsCampaignProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    final isTermiiConfigured = authState.company?.termiiApiKey != null &&
        (authState.company?.termiiApiKey?.trim().isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SMS Campaign Portal'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(smsCampaignProvider.notifier).loadSmsCampaigns();
              ref.read(smsCampaignProvider.notifier).refreshWalletBalance();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Wallet / Balance Summary Card ──
          _buildBalanceBanner(smsState, isTermiiConfigured),

          // ── Premium Custom TabBar ──
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Compose Broadcast', icon: Icon(Icons.send_rounded, size: 18)),
                Tab(text: 'Campaign History', icon: Icon(Icons.history_rounded, size: 18)),
              ],
            ),
          ),

          // ── Tab View Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildComposeTab(smsState, isTermiiConfigured, theme),
                _buildHistoryTab(smsState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBanner(SmsCampaignState smsState, bool isConfigured) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.dashboardHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Termii Account Balance',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${smsState.currency} ${smsState.walletBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConfigured ? Colors.greenAccent : Colors.amberAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConfigured ? 'Live Sending Enabled' : 'Safe Console Simulation Mode',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => ref.read(smsCampaignProvider.notifier).refreshWalletBalance(),
            icon: const Icon(Icons.sync_rounded, size: 14, color: AppColors.accent),
            label: const Text('Sync', style: TextStyle(color: AppColors.accent, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeTab(SmsCampaignState smsState, bool isConfigured, ThemeData theme) {
    // Read count references
    final partners = ref.watch(partnerProvider).partners;
    final leads = ref.watch(leadProvider).leads;

    int recipientCount = 0;
    if (_selectedGroup == 'leads') {
      recipientCount = leads.where((l) => l.buyerPhone.isNotEmpty).length;
    } else if (_selectedGroup == 'partners') {
      recipientCount = partners.where((p) => p.phone != null && p.phone!.isNotEmpty).length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a Broadcast Campaign',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a target group and compose your message template below.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Target Group Select
            const Text(
              'Recipient Target Group',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGroupChip('Leads', 'leads', Icons.trending_up_rounded, recipientCount),
                const SizedBox(width: 12),
                _buildGroupChip('Partners', 'partners', Icons.handshake_rounded, recipientCount),
              ],
            ),
            const SizedBox(height: 24),

            // Campaign Title field
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Campaign Title (Internal Reference)',
                hintText: 'e.g. Promo July 2026 for Partners',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Message text field
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: 'Message Body',
                hintText: 'Type your campaign message here... Use {{name}} to personalize.',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                alignLabelWithHint: true,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a message';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tag: Use {{name}} for partner/buyer name.',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
                Text(
                  '$_charCount/160 chars',
                  style: TextStyle(
                    color: _charCount > 160 ? AppColors.error : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: smsState.isLoading || recipientCount == 0
                    ? null
                    : () => _handleSendBroadcast(recipientCount, partners, leads),
                icon: smsState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.campaign_rounded, size: 20),
                label: Text(
                  smsState.isLoading ? 'Sending Broadcast...' : 'Launch Broadcast to $recipientCount Contacts',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChip(String label, String value, IconData icon, int groupCount) {
    final isSelected = _selectedGroup == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGroup = value;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.accent : AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendBroadcast(int count, List<Profile> partners, List<Lead> leads) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm SMS Broadcast'),
        content: Text(
          'Are you sure you want to send this broadcast to all $count contacts in the "$_selectedGroup" target group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Launch Broadcast'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final List<({String? name, String phone, String? type})> recipients = [];

    if (_selectedGroup == 'leads') {
      for (final lead in leads) {
        if (lead.buyerPhone.isNotEmpty) {
          recipients.add((
            name: lead.buyerName,
            phone: lead.buyerPhone,
            type: 'lead',
          ));
        }
      }
    } else if (_selectedGroup == 'partners') {
      for (final p in partners) {
        if (p.phone != null && p.phone!.isNotEmpty) {
          recipients.add((
            name: p.fullName,
            phone: p.phone!,
            type: 'partner',
          ));
        }
      }
    }

    final ok = await ref.read(smsCampaignProvider.notifier).sendCampaign(
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          recipients: recipients,
        );

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Broadcast launched successfully! Check Campaign History tab for logs.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
        _titleController.clear();
        _messageController.clear();
        _tabController.animateTo(1); // switch to history tab
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to send broadcast: ${ref.read(smsCampaignProvider).errorMessage}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildHistoryTab(SmsCampaignState smsState) {
    if (smsState.isLoading && smsState.campaigns.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: ShimmerList(),
      );
    }

    if (smsState.campaigns.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: 'No campaigns found',
        description: 'Send your first bulk broadcast using the Compose tab.',
        actionLabel: 'Refresh',
        onActionPressed: () => ref.read(smsCampaignProvider.notifier).loadSmsCampaigns(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: smsState.campaigns.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final campaign = smsState.campaigns[index];
        final formattedDate = DateFormat('MMM d, yyyy @ h:mm a').format(campaign.createdAt);

        return Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: ExpansionTile(
            title: Text(
              campaign.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Sent: $formattedDate',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              child: const Icon(Icons.sms_outlined, color: AppColors.accent, size: 20),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip('Recipients: ${campaign.totalRecipients}', Colors.blue),
                  _buildStatusChip('Delivered: ${campaign.deliveredCount}', Colors.green),
                  _buildStatusChip('Failed: ${campaign.failedCount}', Colors.red),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Message Body:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  campaign.message,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
