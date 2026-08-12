import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/email_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/widgets/shimmer_loading.dart';
import 'package:nissie_ideal_shelters/widgets/empty_state.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';


class AdminEmailPortalScreen extends ConsumerStatefulWidget {
  const AdminEmailPortalScreen({super.key});

  @override
  ConsumerState<AdminEmailPortalScreen> createState() => _AdminEmailPortalScreenState();
}

class _AdminEmailPortalScreenState extends ConsumerState<AdminEmailPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _customEmailsController = TextEditingController();

  String _selectedGroup = 'leads'; // 'leads', 'partners', 'custom'
  String _selectedStageFilter = 'all'; // 'all' or specific stage name
  final List<String> _selectedIndividualIds = []; // empty means all matching targets selected

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _customEmailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailState = ref.watch(emailCampaignProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    final provider = authState.company?.emailProvider ?? 'simulation';
    final isConfigured = provider == 'simulation' ||
        (provider == 'brevo' && authState.company?.brevoApiKey != null && authState.company!.brevoApiKey!.trim().isNotEmpty) ||
        (provider == 'smtp' && authState.company?.smtpHost != null && authState.company!.smtpHost!.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Email Campaign Portal'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(emailCampaignProvider.notifier).loadEmailCampaigns();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Settings Summary Banner ──
          _buildConfigurationBanner(provider, isConfigured),

          // ── TabBar ──
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
                Tab(text: 'Compose Broadcast', icon: Icon(Icons.mark_as_unread_rounded, size: 18)),
                Tab(text: 'Campaign History', icon: Icon(Icons.history_rounded, size: 18)),
              ],
            ),
          ),

          // ── Tab View Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildComposeTab(emailState, isConfigured, theme),
                _buildHistoryTab(emailState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationBanner(String provider, bool isConfigured) {
    final String modeLabel = provider == 'simulation'
        ? 'SIMULATION MODE'
        : provider == 'brevo'
            ? 'BREVO (SENDINBLUE) API'
            : 'CUSTOM SMTP SERVER';

    final Color bannerColor = isConfigured
        ? (provider == 'simulation' ? Colors.orange : AppColors.accent)
        : AppColors.error;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bannerColor, bannerColor.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.2),
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
                  'EMAIL CAMPAIGN BROADCAST ENGINE',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  modeLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConfigured
                      ? 'Integrations connected successfully and ready for sending.'
                      : 'Configuration is missing. Please go to Admin Settings to configure SMTP/Brevo keys.',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConfigured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeTab(EmailCampaignState emailState, bool isConfigured, ThemeData theme) {
    final partners = ref.watch(partnerProvider).partners;
    final leads = ref.watch(leadProvider).leads;

    final leadsMatchingFilter = leads.where((l) {
      if (l.buyerEmail == null || l.buyerEmail!.isEmpty) return false;
      if (_selectedStageFilter != 'all' && l.stage.name != _selectedStageFilter) return false;
      return true;
    }).toList();

    final partnersWithEmail = partners.where((p) => p.email != null && p.email!.isNotEmpty).toList();

    int recipientCount = 0;
    if (_selectedGroup == 'leads') {
      recipientCount = _selectedIndividualIds.isEmpty ? leadsMatchingFilter.length : _selectedIndividualIds.length;
    } else if (_selectedGroup == 'partners') {
      recipientCount = _selectedIndividualIds.isEmpty ? partnersWithEmail.length : _selectedIndividualIds.length;
    } else if (_selectedGroup == 'custom') {
      recipientCount = _customEmailsController.text
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
              'Select a target group, apply filters or custom lists, and compose your email copy.',
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
                _buildGroupChip('Custom List', 'custom', Icons.alternate_email_rounded),
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
                    _selectedIndividualIds.clear();
                  });
                },
              ),
            ],

            // Individual Selector
            if (_selectedGroup == 'leads' || _selectedGroup == 'partners') ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  final targetList = _selectedGroup == 'leads' ? leadsMatchingFilter : partnersWithEmail;
                  _showContactSelectionModal(context, targetList);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, color: AppColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Individual Recipient Selection (Optional)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedIndividualIds.isEmpty
                                  ? 'All matching contacts will be targeted (${_selectedGroup == 'leads' ? leadsMatchingFilter.length : partnersWithEmail.length} total)'
                                  : '${_selectedIndividualIds.length} contact(s) selected manually',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: AppColors.accent, size: 18),
                    ],
                  ),
                ),
              ),
            ],

            // Custom Emails Input
            if (_selectedGroup == 'custom') ...[
              const SizedBox(height: 20),
              TextFormField(
                controller: _customEmailsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Custom Recipient Email Addresses',
                  hintText: 'Enter emails separated by commas (e.g. contact1@mail.com, contact2@mail.com)',
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
                    return 'Please enter at least one recipient email address.';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Internal Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Internal Campaign Title (for history tracking)',
                hintText: 'e.g. July Summer Property Promotion Broadcast',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a campaign title.';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Subject Line
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Email Subject Line',
                hintText: 'e.g. Check out our latest premium properties in Lekki!',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter an email subject line.';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Body Copy text box
            TextFormField(
              controller: _bodyController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'Email Message Body (Supports HTML)',
                hintText: 'Hello {{name}},\n\nWe are pleased to introduce our brand new housing estates...',
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
                  return 'Please compose your email body copy.';
                }
                return null;
              },
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tip: Use {{name}} to personalize greeting. e.g. "Dear {{name}}," becomes "Dear John,".',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Launch button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (isConfigured && !emailState.isLoading) ? () => _launchCampaign(recipientCount, leadsMatchingFilter, partnersWithEmail) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: emailState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  emailState.isLoading
                      ? 'Launching campaign broadcast...'
                      : 'Launch Broadcast to $recipientCount Recipient(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChip(String label, String groupValue, IconData icon) {
    final isSelected = _selectedGroup == groupValue;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGroup = groupValue;
            _selectedIndividualIds.clear();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.textSecondary, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchCampaign(int recipientCount, List<Lead> leadsMatchingFilter, List<Profile> partnersWithEmail) async {
    if (!_formKey.currentState!.validate()) return;

    if (recipientCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid email recipients target list identified.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Email Broadcast'),
        content: Text(
          'You are about to launch a marketing broadcast to $recipientCount recipient(s).\n\nDo you want to send this campaign now?',
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

    final List<({String? name, String email, String? type})> recipients = [];

    if (_selectedGroup == 'leads') {
      final targets = _selectedIndividualIds.isEmpty
          ? leadsMatchingFilter
          : leadsMatchingFilter.where((l) => _selectedIndividualIds.contains(l.id)).toList();
      for (final lead in targets) {
        if (lead.buyerEmail != null && lead.buyerEmail!.isNotEmpty) {
          recipients.add((
            name: lead.buyerName,
            email: lead.buyerEmail!,
            type: 'lead',
          ));
        }
      }
    } else if (_selectedGroup == 'partners') {
      final targets = _selectedIndividualIds.isEmpty
          ? partnersWithEmail
          : partnersWithEmail.where((p) => _selectedIndividualIds.contains(p.id)).toList();
      for (final p in targets) {
        if (p.email != null && p.email!.isNotEmpty) {
          recipients.add((
            name: p.fullName,
            email: p.email!,
            type: 'partner',
          ));
        }
      }
    } else if (_selectedGroup == 'custom') {
      final customEmails = _customEmailsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final email in customEmails) {
        recipients.add((
          name: 'Custom Recipient',
          email: email,
          type: 'custom',
        ));
      }
    }

    final ok = await ref.read(emailCampaignProvider.notifier).sendCampaign(
          subject: _subjectController.text.trim(),
          body: _bodyController.text.trim(),
          recipients: recipients,
        );

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Email broadcast launched successfully! Check Campaign History tab.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
        _titleController.clear();
        _subjectController.clear();
        _bodyController.clear();
        _customEmailsController.clear();
        _selectedIndividualIds.clear();
        _tabController.animateTo(1); // Switch to history tab
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to launch email broadcast: ${ref.read(emailCampaignProvider).errorMessage}'),
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
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by name or email...',
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
                              searchQuery = val.toLowerCase();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final c = contacts[index];
                            final String id = c.id;
                            final String name = c is Lead ? c.buyerName : c.fullName;
                            final String email = c is Lead ? (c.buyerEmail ?? '') : (c.email ?? '');

                            if (searchQuery.isNotEmpty &&
                                !name.toLowerCase().contains(searchQuery) &&
                                !email.toLowerCase().contains(searchQuery)) {
                              return const SizedBox.shrink();
                            }

                            final isChecked = _selectedIndividualIds.contains(id);

                            return CheckboxListTile(
                              value: isChecked,
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              activeColor: AppColors.accent,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    _selectedIndividualIds.add(id);
                                  } else {
                                    _selectedIndividualIds.remove(id);
                                  }
                                });
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _selectedIndividualIds.isEmpty
                                  ? 'Target All (${contacts.length})'
                                  : 'Target Selected (${_selectedIndividualIds.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(EmailCampaignState emailState) {
    if (emailState.isLoading && emailState.campaigns.isEmpty) {
      return const ShimmerList(itemCount: 4);
    }
    if (emailState.campaigns.isEmpty) {
      return const EmptyState(
        title: 'No Campaigns Dispatched Yet',
        description: 'Launch your first bulk email campaign from the Compose tab.',
        icon: Icons.mark_as_unread_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: emailState.campaigns.length,
      itemBuilder: (context, index) {
        final camp = emailState.campaigns[index];
        final formattedDate = camp.sentAt != null
            ? DateFormat('MMM dd, yyyy - hh:mm a').format(camp.sentAt!)
            : DateFormat('MMM dd, yyyy - hh:mm a').format(camp.createdAt);

        return Card(
          color: AppColors.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: ExpansionTile(
            title: Text(camp.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$formattedDate • ${camp.totalRecipients} Recipient(s)'),
            leading: Icon(
              camp.failedCount > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: camp.failedCount > 0 ? AppColors.error : AppColors.success,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Internal Campaign Details:',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Body Copy:\n${camp.body}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatChip('Total', camp.totalRecipients, Colors.blue),
                        _buildStatChip('Delivered', camp.deliveredCount, AppColors.success),
                        _buildStatChip('Failed', camp.failedCount, AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Link/Button to load individual message reports
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _viewRecipientReport(camp.id, camp.subject),
                        icon: const Icon(Icons.assessment_outlined),
                        label: const Text('View Detailed Delivery Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _viewRecipientReport(String campaignId, String subject) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Report',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: ref.read(supabaseServiceProvider).client
                      .from('email_messages')
                      .select()
                      .eq('campaign_id', campaignId)
                      .order('sent_at', ascending: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ShimmerList(itemCount: 4);
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('No recipient logs found.'));
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, idx) {
                        final log = list[idx];
                        final String name = log['recipient_name'] ?? 'Contact';
                        final String email = log['recipient_email'];
                        final String status = log['status'];
                        final String? errorMsg = log['error_message'];

                        return ListTile(
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email, style: const TextStyle(fontSize: 12)),
                              if (errorMsg != null)
                                Text('Error: $errorMsg', style: const TextStyle(color: AppColors.error, fontSize: 11)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (status == 'delivered' ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: status == 'delivered' ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
