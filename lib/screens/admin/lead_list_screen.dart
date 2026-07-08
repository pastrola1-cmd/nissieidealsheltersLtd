import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/widgets/shimmer_loading.dart';
import 'package:nissie_ideal_shelters/widgets/empty_state.dart';
import 'package:nissie_ideal_shelters/services/sms_service.dart';

class LeadListScreen extends ConsumerStatefulWidget {
  final String? initialStageFilter;
  const LeadListScreen({super.key, this.initialStageFilter});

  @override
  ConsumerState<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  final _searchController = TextEditingController();
  String _selectedStageFilter = 'All'; 
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final validStages = ['All', 'New', 'Contacted', 'Inspection Booked', 'Negotiation', 'Closed', 'Lost'];
    if (widget.initialStageFilter != null && validStages.contains(widget.initialStageFilter)) {
      _selectedStageFilter = widget.initialStageFilter!;
    }
  }

  // Selection state
  final Set<String> _selectedLeadIds = {};
  bool get _isSelectionMode => _selectedLeadIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final authState = ref.watch(authProvider);
    final role = authState.profile?.role;
    final routePrefix = role == UserRole.manager
        ? '/manager/leads'
        : role == UserRole.marketer
            ? '/marketer/leads'
            : '/admin/leads';

    // Cache providers for name resolutions
    final properties = ref.watch(propertyProvider).properties;
    final partners = ref.watch(partnerProvider).partners;

    // Apply filtering
    final filteredLeads = state.leads.where((lead) {
      final property = properties.cast<Property?>().firstWhere((p) => p?.id == lead.propertyId, orElse: () => null);
      final partner = partners.cast<Profile?>().firstWhere((p) => p?.id == lead.partnerId, orElse: () => null);

      final propTitle = property?.title.toLowerCase() ?? '';
      final partnerName = partner?.fullName?.toLowerCase() ?? '';
      final buyerName = lead.buyerName.toLowerCase();
      final buyerPhone = lead.buyerPhone.toLowerCase();
      final buyerEmail = lead.buyerEmail?.toLowerCase() ?? '';

      final matchesSearch = propTitle.contains(_searchQuery) ||
          partnerName.contains(_searchQuery) ||
          buyerName.contains(_searchQuery) ||
          buyerPhone.contains(_searchQuery) ||
          buyerEmail.contains(_searchQuery);

      final matchesStage = _selectedStageFilter == 'All' ||
          lead.stage.value.toLowerCase() == _selectedStageFilter.replaceAll(' ', '_').toLowerCase();

      return matchesSearch && matchesStage;
    }).toList();

    // Stats calculations
    final totalCount = state.leads.length;
    final newCount = state.leads.where((l) => l.stage == LeadStage.newLead).length;
    final closedCount = state.leads.where((l) => l.stage == LeadStage.closed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedLeadIds.clear()),
              )
            : null,
        title: Text(_isSelectionMode ? '${_selectedLeadIds.length} Selected' : 'Leads Pipeline'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(
                _selectedLeadIds.length == filteredLeads.length
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
              ),
              tooltip: 'Select All',
              onPressed: () {
                setState(() {
                  if (_selectedLeadIds.length == filteredLeads.length) {
                    _selectedLeadIds.clear();
                  } else {
                    _selectedLeadIds.addAll(filteredLeads.map((l) => l.id));
                  }
                });
              },
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => context.push('$routePrefix/add'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Lead'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ]
        ],
      ),
      body: Stack(
        children: [
          state.isLoading && state.leads.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: ShimmerList(),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(leadProvider.notifier).loadLeads();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(24, 24, 24, _isSelectionMode ? 100 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Stats Row ──
                        if (!_isSelectionMode) ...[
                          _buildStatsRow(
                            total: totalCount,
                            newLeads: newCount,
                            closed: closedCount,
                            screenWidth: screenWidth,
                          ),
                          const SizedBox(height: 20),
                          // Import & Export Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('$routePrefix/import'),
                                  icon: const Icon(Icons.file_upload_outlined, size: 16, color: AppColors.primary),
                                  label: const Text('Import CSV', style: TextStyle(color: AppColors.primary)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('$routePrefix/export'),
                                  icon: const Icon(Icons.file_download_outlined, size: 16, color: AppColors.primary),
                                  label: const Text('Export CSV', style: TextStyle(color: AppColors.primary)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Filters & Search ──
                        _buildSearchAndFilters(theme),
                        const SizedBox(height: 24),

                        // ── Leads pipeline List ──
                        if (state.errorMessage != null)
                          Center(
                            child: Text(
                              'Error: ${state.errorMessage}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          )
                        else if (filteredLeads.isEmpty)
                          _buildEmptyState(theme)
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredLeads.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final lead = filteredLeads[index];
                              final property = properties.cast<Property?>().firstWhere((p) => p?.id == lead.propertyId, orElse: () => null);
                              final partner = partners.cast<Profile?>().firstWhere((p) => p?.id == lead.partnerId, orElse: () => null);
                              return _buildLeadCard(context, lead, property, partner, theme);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
          
          // Bulk Action Toolbar
          if (_isSelectionMode)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: _buildBulkActionToolbar(context, filteredLeads),
            ),
        ],
      ),
    );
  }

  Widget _buildBulkActionToolbar(BuildContext context, List<Lead> filteredLeads) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolbarButton(
            icon: Icons.sms_outlined,
            label: 'SMS',
            onTap: () => _showBulkSmsDialog(context, filteredLeads),
          ),
          _buildToolbarButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Assign',
            onTap: () => _showBulkAssignDialog(context),
          ),
          _buildToolbarButton(
            icon: Icons.playlist_add_check_rounded,
            label: 'Stage',
            onTap: () => _showBulkStageDialog(context),
          ),
          _buildToolbarButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppColors.error,
            onTap: () => _showBulkDeleteDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bulk Dialogs ──

  Future<void> _showBulkSmsDialog(BuildContext context, List<Lead> filteredLeads) async {
    final smsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    final selectedLeads = filteredLeads.where((l) => _selectedLeadIds.contains(l.id)).toList();
    final phoneNumbers = selectedLeads.map((l) => l.buyerPhone).where((p) => p.isNotEmpty).toList();

    if (phoneNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid phone numbers found for selected leads.')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.sms_rounded, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Send Bulk SMS (${phoneNumbers.length})'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the message you want to broadcast to these leads:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: smsController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type your message here...',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => isSending = true);

                      final company = ref.read(authProvider).company;
                      final apiKey = company?.termiiApiKey;
                      final senderId = company?.termiiSenderId ?? 'Nissie';

                      final service = ref.read(smsServiceProvider);
                      final sentCount = await service.sendBulkSms(
                        phoneNumbers: phoneNumbers,
                        message: smsController.text.trim(),
                        apiKey: apiKey,
                        senderId: senderId,
                      );

                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }

                      if (mounted) {
                        final isLive = apiKey != null && apiKey.trim().isNotEmpty;
                        final modeMsg = isLive 
                            ? 'Successfully sent $sentCount / ${phoneNumbers.length} SMS via Termii!'
                            : 'Simulation Mode: Simulated sending $sentCount SMS to console.';
                        
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(modeMsg),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: isLive ? AppColors.success : AppColors.info,
                          ),
                        );
                        setState(() => _selectedLeadIds.clear());
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send SMS'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkAssignDialog(BuildContext context) async {
    final marketers = ref.read(agencyMarketersProvider).value ?? [];
    String? selectedAgentId;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Assign Agent'),
          content: DropdownButtonFormField<String?>(
            value: selectedAgentId,
            decoration: const InputDecoration(labelText: 'Select Agent'),
            items: [
              const DropdownMenuItem<String?>(value: 'unassign', child: Text('Unassigned Leads')),
              ...marketers.map((m) => DropdownMenuItem<String?>(
                    value: m.id,
                    child: Text(m.fullName ?? m.email ?? ''),
                  )),
            ],
            onChanged: (val) => setDialogState(() => selectedAgentId = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedAgentId == null
                  ? null
                  : () async {
                      Navigator.pop(dialogCtx);
                      final success = await ref.read(leadProvider.notifier).bulkUpdateLeads(
                            leadIds: _selectedLeadIds.toList(),
                            assignedAgentId: selectedAgentId,
                          );
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Leads assigned successfully!')),
                        );
                        setState(() => _selectedLeadIds.clear());
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkStageDialog(BuildContext context) async {
    LeadStage? selectedStage;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Change Stage'),
          content: DropdownButtonFormField<LeadStage?>(
            value: selectedStage,
            decoration: const InputDecoration(labelText: 'Select Lead Stage'),
            items: LeadStage.values
                .map((stage) => DropdownMenuItem<LeadStage?>(
                      value: stage,
                      child: Text(stage.label),
                    ))
                .toList(),
            onChanged: (val) => setDialogState(() => selectedStage = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedStage == null
                  ? null
                  : () async {
                      Navigator.pop(dialogCtx);
                      final success = await ref.read(leadProvider.notifier).bulkUpdateLeads(
                            leadIds: _selectedLeadIds.toList(),
                            stage: selectedStage,
                          );
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Leads stage updated successfully!')),
                        );
                        setState(() => _selectedLeadIds.clear());
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Bulk Deletion', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete the ${_selectedLeadIds.length} selected leads? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await ref.read(leadProvider.notifier).bulkDeleteLeads(_selectedLeadIds.toList());
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Leads deleted successfully!')),
                );
                setState(() => _selectedLeadIds.clear());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Existing Elements ──

  Widget _buildStatsRow({
    required int total,
    required int newLeads,
    required int closed,
    required double screenWidth,
  }) {
    final isMobile = screenWidth < 600;
    
    final cards = [
      _buildStatCard(
        title: 'Total Leads',
        value: total.toString(),
        icon: Icons.assignment_rounded,
        color: AppColors.primary,
        textColor: AppColors.textOnPrimary,
        isGradient: true,
      ),
      _buildStatCard(
        title: 'New',
        value: newLeads.toString(),
        icon: Icons.new_releases_outlined,
        color: AppColors.info,
        textColor: AppColors.info,
        isGradient: false,
      ),
      _buildStatCard(
        title: 'Closed Deals',
        value: closed.toString(),
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        textColor: AppColors.successDark,
        isGradient: false,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 12),
          cards[1],
          const SizedBox(height: 12),
          cards[2],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color textColor,
    required bool isGradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGradient ? null : AppColors.surface,
        gradient: isGradient ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(16),
        border: isGradient ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGradient ? Colors.white12 : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isGradient ? Colors.white : color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isGradient ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isGradient ? Colors.white : AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (val) {
            if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'Search leads by buyer, property, or partner...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pipeline Stage Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'All',
              'New',
              'Contacted',
              'Inspection Booked',
              'Negotiation',
              'Closed',
              'Lost'
            ].map((stage) {
              final isSelected = _selectedStageFilter == stage;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(stage),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStageFilter = stage;
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
                  elevation: 0,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadCard(
    BuildContext context,
    Lead lead,
    Property? property,
    Profile? partner,
    ThemeData theme,
  ) {
    final authState = ref.read(authProvider);
    final role = authState.profile?.role;
    final routePrefix = role == UserRole.manager
        ? '/manager/leads'
        : role == UserRole.marketer
            ? '/marketer/leads'
            : '/admin/leads';

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

    final dateStr = DateFormat('MMM d, yyyy').format(lead.updatedAt);
    final isSelected = _selectedLeadIds.contains(lead.id);

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedLeadIds.remove(lead.id);
            } else {
              _selectedLeadIds.add(lead.id);
            }
          });
        } else {
          context.push('$routePrefix/${lead.id}');
        }
      },
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedLeadIds.remove(lead.id);
          } else {
            _selectedLeadIds.add(lead.id);
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.03) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    if (isSelected) {
                      _selectedLeadIds.remove(lead.id);
                    } else {
                      _selectedLeadIds.add(lead.id);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row (Buyer name & Stage badge)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lead.buyerName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIntentBadge(lead.intentScore),
                          const SizedBox(width: 6),
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
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Property details
                  Row(
                    children: [
                      const Icon(Icons.home_work_outlined, size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          property?.title ?? 'Unknown Property Listing',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Partner details
                  Row(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            text: 'Referred by: ',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: theme.textTheme.bodyMedium?.fontFamily),
                            children: [
                              TextSpan(
                                text: partner?.fullName ?? 'Direct Client',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Footer Row (Phone & Date)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 6),
                          Text(
                            lead.buyerPhone,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        'Updated: $dateStr',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntentBadge(String score) {
    Color color;
    IconData icon;
    switch (score.toLowerCase()) {
      case 'hot':
        color = const Color(0xFFE53935); // Crimson red
        icon = Icons.local_fire_department_rounded;
        break;
      case 'warm':
        color = const Color(0xFFFB8C00); // Warm orange
        icon = Icons.whatshot_rounded;
        break;
      case 'cold':
      default:
        color = const Color(0xFF1E88E5); // Cold blue
        icon = Icons.ac_unit_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            score.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState(ThemeData theme) {
    return EmptyState(
      icon: Icons.assignment_turned_in_outlined,
      title: 'No leads match your filter',
      description: 'Create a manual lead or check shared partner links.',
      actionLabel: 'Reset Filters',
      onActionPressed: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _selectedStageFilter = 'All';
        });
      },
    );
  }
}
