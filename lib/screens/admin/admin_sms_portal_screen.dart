import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
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
  final _customNumbersController = TextEditingController();
  
  String _selectedGroup = 'leads'; // 'leads', 'partners', 'custom'
  String _selectedStageFilter = 'all'; // 'all' or specific stage name
  final List<String> _selectedIndividualIds = []; // empty means all matching targets selected
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
    _customNumbersController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _customNumbersController.dispose();
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
                  'SmartSMS Solutions Live Balance',
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

    final leadsMatchingFilter = leads.where((l) {
      if (l.buyerPhone.isEmpty) return false;
      if (_selectedStageFilter != 'all' && l.stage.name != _selectedStageFilter) return false;
      return true;
    }).toList();

    final partnersWithPhone = partners.where((p) => p.phone != null && p.phone!.isNotEmpty).toList();

    int recipientCount = 0;
    if (_selectedGroup == 'leads') {
      recipientCount = _selectedIndividualIds.isEmpty ? leadsMatchingFilter.length : _selectedIndividualIds.length;
    } else if (_selectedGroup == 'partners') {
      recipientCount = _selectedIndividualIds.isEmpty ? partnersWithPhone.length : _selectedIndividualIds.length;
    } else if (_selectedGroup == 'custom') {
      recipientCount = _customNumbersController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList()
          .length;
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
              'Select a target group, apply filters or custom lists, and compose your message.',
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
                _buildGroupChip('Leads', 'leads', Icons.trending_up_rounded),
                const SizedBox(width: 8),
                _buildGroupChip('Partners', 'partners', Icons.handshake_rounded),
                const SizedBox(width: 8),
                _buildGroupChip('Custom', 'custom', Icons.phone_android_rounded),
              ],
            ),

            // Pipeline Stage Filter
            if (_selectedGroup == 'leads') ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedStageFilter,
                decoration: InputDecoration(
                  labelText: 'Filter by Pipeline Stage',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Pipeline Stages')),
                  ...LeadStage.values.map((stage) {
                    return DropdownMenuItem(value: stage.name, child: Text(stage.label));
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedStageFilter = val ?? 'all';
                    _selectedIndividualIds.clear(); // Reset custom selections when filter changes
                  });
                },
              ),
            ],

            // Select Specific Leads / Partners Selector Button
            if (_selectedGroup == 'leads' || _selectedGroup == 'partners') ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  final targetList = _selectedGroup == 'leads' ? leadsMatchingFilter : partnersWithPhone;
                  _showContactSelectionModal(context, targetList);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedIndividualIds.isEmpty
                              ? 'Targeting all ${_selectedGroup == 'leads' ? 'matching leads' : 'partners'} (Tap to select specific)'
                              : 'Targeting ${_selectedIndividualIds.length} specific ${_selectedGroup == 'leads' ? 'leads' : 'partners'}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],

            // Custom numbers field
            if (_selectedGroup == 'custom') ...[
              const SizedBox(height: 20),
              TextFormField(
                controller: _customNumbersController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Custom Phone Numbers (comma-separated)',
                  hintText: 'e.g. +2348012345678, +2348098765432, 08022223333',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (val) {
                  if (_selectedGroup == 'custom' && (val == null || val.trim().isEmpty)) {
                    return 'Please enter at least one phone number';
                  }
                  return null;
                },
              ),
            ],
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
              decoration: InputDecoration(
                labelText: 'Message Body',
                hintText: 'Type your campaign message here... Use {{name}} to personalize.',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
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
            Builder(builder: (context) {
              final pages = _charCount == 0 ? 0 : (_charCount <= 160 ? 1 : ((_charCount - 1) ~/ 153) + 1);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tag: Use {{name}} for partner/buyer name.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                  Text(
                    '$_charCount chars ($pages SMS page${pages == 1 ? '' : 's'})',
                    style: TextStyle(
                      color: pages > 1 ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 32),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: smsState.isLoading || recipientCount == 0
                    ? null
                    : () => _handleSendBroadcast(recipientCount, partnersWithPhone, leadsMatchingFilter),
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

  Widget _buildGroupChip(String label, String value, IconData icon) {
    final isSelected = _selectedGroup == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGroup = value;
            _selectedStageFilter = 'all';
            _selectedIndividualIds.clear();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
              Icon(icon, color: isSelected ? AppColors.accent : AppColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendBroadcast(int count, List<Profile> partnersWithPhone, List<Lead> leadsMatchingFilter) async {
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
      final targets = _selectedIndividualIds.isEmpty 
          ? leadsMatchingFilter 
          : leadsMatchingFilter.where((l) => _selectedIndividualIds.contains(l.id)).toList();
      for (final lead in targets) {
        if (lead.buyerPhone.isNotEmpty) {
          recipients.add((
            name: lead.buyerName,
            phone: lead.buyerPhone,
            type: 'lead',
          ));
        }
      }
    } else if (_selectedGroup == 'partners') {
      final targets = _selectedIndividualIds.isEmpty 
          ? partnersWithPhone 
          : partnersWithPhone.where((p) => _selectedIndividualIds.contains(p.id)).toList();
      for (final p in targets) {
        if (p.phone != null && p.phone!.isNotEmpty) {
          recipients.add((
            name: p.fullName,
            phone: p.phone!,
            type: 'partner',
          ));
        }
      }
    } else if (_selectedGroup == 'custom') {
      final customNumbers = _customNumbersController.text
          .split(RegExp(r'[\s,\n;\r]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final rawNum in customNumbers) {
        String digits = rawNum.replaceAll(RegExp(r'\D'), '');
        if (digits.startsWith('0') && digits.length == 11) {
          digits = '234${digits.substring(1)}';
        } else if (digits.length == 10 && RegExp(r'^[789]').hasMatch(digits)) {
          digits = '234$digits';
        }

        if (digits.length >= 10 && digits.length <= 15) {
          recipients.add((
            name: 'Custom Recipient ($digits)',
            phone: digits,
            type: 'custom',
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
        _customNumbersController.clear();
        _selectedIndividualIds.clear();
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

  void _showContactSelectionModal(BuildContext context, List<dynamic> contacts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            String searchQuery = '';
            
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Recipients',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  _selectedIndividualIds.clear();
                                });
                                setState(() {});
                              },
                              child: const Text('Reset / Select All', style: TextStyle(color: AppColors.accent)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val.trim().toLowerCase();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: StatefulBuilder(
                          builder: (context, setListState) {
                            final filtered = contacts.where((c) {
                              final name = (c is Lead ? c.buyerName : (c as Profile).fullName ?? 'Unnamed').toLowerCase();
                              final phone = (c is Lead ? c.buyerPhone : (c as Profile).phone ?? '').toLowerCase();
                              return name.contains(searchQuery) || phone.contains(searchQuery);
                            }).toList();
                            
                            if (filtered.isEmpty) {
                              return const Center(child: Text('No contacts found', style: TextStyle(color: AppColors.textSecondary)));
                            }
                            
                            return ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final contact = filtered[index];
                                final id = contact.id;
                                final name = contact is Lead ? contact.buyerName : (contact as Profile).fullName ?? 'Unnamed';
                                final phone = contact is Lead ? contact.buyerPhone : (contact as Profile).phone ?? 'No phone';
                                
                                final isChecked = _selectedIndividualIds.contains(id);
                                
                                return CheckboxListTile(
                                  value: isChecked,
                                  activeColor: AppColors.accent,
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        _selectedIndividualIds.add(id);
                                      } else {
                                        _selectedIndividualIds.remove(id);
                                      }
                                    });
                                    setListState(() {});
                                    setState(() {});
                                  },
                                );
                              },
                            );
                          }
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Confirm (${_selectedIndividualIds.isEmpty ? contacts.length : _selectedIndividualIds.length} Selected)'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
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
