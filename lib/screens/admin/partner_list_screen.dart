import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/sms_service.dart';
import 'package:nissie_ideal_shelters/widgets/shimmer_loading.dart';
import 'package:nissie_ideal_shelters/widgets/empty_state.dart';

class PartnerListScreen extends ConsumerStatefulWidget {
  const PartnerListScreen({super.key});

  @override
  ConsumerState<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends ConsumerState<PartnerListScreen> {
  final _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  Timer? _debounceTimer;

  // ── Selection State ──
  final Set<String> _selectedPartnerIds = {};
  bool get _isSelectionMode => _selectedPartnerIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Apply filtering
    final filteredPartners = state.partners.where((partner) {
      final name = partner.fullName?.toLowerCase() ?? '';
      final phone = partner.phone?.toLowerCase() ?? '';
      final email = partner.email?.toLowerCase() ?? '';
      final matchesSearch = name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery);

      final matchesStatus = _selectedStatusFilter == 'All' ||
          partner.status.value.toLowerCase() ==
              _selectedStatusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    // Stats calculations
    final totalCount = state.partners.length;
    final pendingCount =
        state.partners.where((p) => p.status == PartnerStatus.pending).length;
    final approvedCount =
        state.partners.where((p) => p.status == PartnerStatus.approved).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedPartnerIds.clear()),
              )
            : null,
        title: Text(
          _isSelectionMode
              ? '${_selectedPartnerIds.length} Selected'
              : 'Partners Directory',
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(
                _selectedPartnerIds.length == filteredPartners.length
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
              ),
              tooltip: 'Select All',
              onPressed: () {
                setState(() {
                  if (_selectedPartnerIds.length == filteredPartners.length) {
                    _selectedPartnerIds.clear();
                  } else {
                    _selectedPartnerIds
                        .addAll(filteredPartners.map((p) => p.id));
                  }
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          state.isLoading && state.partners.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: ShimmerList(),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    final companyId = ref
                        .read(partnerProvider)
                        .partners
                        .firstOrNull
                        ?.companyId;
                    await ref
                        .read(partnerProvider.notifier)
                        .loadPartners(companyId);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        24, 24, 24, _isSelectionMode ? 100 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Stats Row (hidden in selection mode) ──
                        if (!_isSelectionMode) ...[
                          _buildStatsRow(
                            total: totalCount,
                            pending: pendingCount,
                            approved: approvedCount,
                            screenWidth: screenWidth,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Filters & Search ──
                        _buildSearchAndFilters(theme),
                        const SizedBox(height: 24),

                        // ── Hint text in selection mode ──
                        if (_isSelectionMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Long-press a card to select. Tap to toggle.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),

                        // ── Partners Directory List ──
                        if (state.errorMessage != null)
                          Center(
                            child: Text(
                              'Error: ${state.errorMessage}',
                              style:
                                  const TextStyle(color: AppColors.error),
                            ),
                          )
                        else if (filteredPartners.isEmpty)
                          _buildEmptyState(theme)
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredPartners.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final partner = filteredPartners[index];
                              return _buildPartnerCard(
                                  context, partner, theme);
                            },
                          ),
                      ],
                    ),
                  ),
                ),

          // ── Bulk Action Toolbar ──
          if (_isSelectionMode)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: _buildBulkActionToolbar(context, filteredPartners),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bulk Action Toolbar
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildBulkActionToolbar(
      BuildContext context, List<Profile> filteredPartners) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
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
            onTap: () => _showBulkSmsDialog(context, filteredPartners),
          ),
          _buildToolbarButton(
            icon: Icons.verified_user_outlined,
            label: 'Approve',
            color: AppColors.success,
            onTap: () => _showBulkApproveDialog(context, filteredPartners),
          ),
          _buildToolbarButton(
            icon: Icons.block_rounded,
            label: 'Suspend',
            color: AppColors.warning,
            onTap: () => _showBulkSuspendDialog(context),
          ),
          _buildToolbarButton(
            icon: Icons.delete_outline_rounded,
            label: 'Reject',
            color: AppColors.error,
            onTap: () => _showBulkRejectDialog(context),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bulk Dialogs
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _showBulkSmsDialog(
      BuildContext context, List<Profile> filteredPartners) async {
    final smsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    final selectedPartners = filteredPartners
        .where((p) => _selectedPartnerIds.contains(p.id))
        .toList();
    final phoneNumbers = selectedPartners
        .map((p) => p.phone ?? '')
        .where((phone) => phone.trim().isNotEmpty)
        .toList();

    if (phoneNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No valid phone numbers found for selected partners.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sms_rounded,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send Bulk SMS',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'Sending to ${phoneNumbers.length} partner${phoneNumbers.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Type a message to broadcast via Termii SMS:',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: smsController,
                  maxLines: 5,
                  maxLength: 160,
                  decoration: InputDecoration(
                    hintText: 'Hello {{name}}, this is Nissie...',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Use {{name}} to personalise with partner\'s first name.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: isSending
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      setDialogState(() => isSending = true);

                      final company = ref.read(authProvider).company;
                      final apiKey = company?.termiiApiKey;
                      final senderId =
                          company?.termiiSenderId ?? 'Nissie';

                      final smsService = ref.read(smsServiceProvider);
                      final rawMessage = smsController.text.trim();

                      // Personalise {{name}} per recipient
                      int sentCount = 0;
                      for (final partner in selectedPartners) {
                        if ((partner.phone ?? '').trim().isEmpty) continue;
                        final firstName =
                            partner.fullName?.split(' ').first ?? 'Partner';
                        final personalised =
                            rawMessage.replaceAll('{{name}}', firstName);

                        if (apiKey == null || apiKey.trim().isEmpty) {
                          // Simulation - count as sent
                          sentCount++;
                        } else {
                          final ok = await smsService.sendSms(
                            to: partner.phone!,
                            message: personalised,
                            apiKey: apiKey,
                            senderId: senderId,
                          );
                          if (ok) sentCount++;
                        }
                      }

                      // Simulation mode still needs a brief pause
                      if (apiKey == null || apiKey.trim().isEmpty) {
                        await Future.delayed(
                            const Duration(milliseconds: 300));
                      }

                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                      if (mounted) {
                        final isLive =
                            apiKey != null && apiKey.trim().isNotEmpty;
                        final modeMsg = isLive
                            ? '✅ Sent $sentCount / ${phoneNumbers.length} SMS via Termii!'
                            : '🔵 Simulation: $sentCount messages printed to console.';

                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(modeMsg),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor:
                                isLive ? AppColors.success : AppColors.info,
                          ),
                        );
                        setState(() => _selectedPartnerIds.clear());
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(isSending ? 'Sending...' : 'Send SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkApproveDialog(
      BuildContext context, List<Profile> filteredPartners) async {
    final selectedPartners = filteredPartners
        .where((p) => _selectedPartnerIds.contains(p.id))
        .toList();
    final pendingOnes =
        selectedPartners.where((p) => p.status == PartnerStatus.pending).toList();

    if (pendingOnes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending partners in your selection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.success),
            const SizedBox(width: 10),
            Text('Approve ${pendingOnes.length} Partner${pendingOnes.length == 1 ? '' : 's'}'),
          ],
        ),
        content: Text(
          'This will approve ${pendingOnes.length} pending partner${pendingOnes.length == 1 ? '' : 's'} and generate their referral codes. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final company = ref.read(authProvider).company;
    final companyName = company?.name ?? 'Nissie';
    int approvedCount = 0;
    int failedCount = 0;

    for (final partner in pendingOnes) {
      final ok = await ref.read(partnerProvider.notifier).approvePartner(
            partner.id,
            partner.fullName ?? 'Partner',
            companyName,
          );
      if (ok) {
        approvedCount++;
      } else {
        failedCount++;
      }
    }

    if (mounted) {
      final msg = failedCount == 0
          ? '✅ Successfully approved $approvedCount partner${approvedCount == 1 ? '' : 's'}!'
          : '⚠️ Approved $approvedCount, failed $failedCount (plan limit may have been reached).';
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              failedCount == 0 ? AppColors.success : AppColors.warning,
        ),
      );
      setState(() => _selectedPartnerIds.clear());
    }
  }

  Future<void> _showBulkSuspendDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Confirm Suspension',
                style: TextStyle(color: AppColors.warning)),
          ],
        ),
        content: Text(
          'Are you sure you want to suspend ${_selectedPartnerIds.length} selected partner${_selectedPartnerIds.length == 1 ? '' : 's'}? They will lose access to the platform immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ids = _selectedPartnerIds.toList();
    int successCount = 0;
    for (final id in ids) {
      final ok =
          await ref.read(partnerProvider.notifier).suspendPartner(id);
      if (ok) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
              '⚠️ Suspended $successCount / ${ids.length} partner${ids.length == 1 ? '' : 's'}.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
        ),
      );
      setState(() => _selectedPartnerIds.clear());
    }
  }

  Future<void> _showBulkRejectDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error),
            SizedBox(width: 10),
            Text('Confirm Rejection',
                style: TextStyle(color: AppColors.error,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to reject ${_selectedPartnerIds.length} selected partner${_selectedPartnerIds.length == 1 ? '' : 's'}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ids = _selectedPartnerIds.toList();
    int successCount = 0;
    for (final id in ids) {
      final ok =
          await ref.read(partnerProvider.notifier).rejectPartner(id);
      if (ok) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Rejected $successCount / ${ids.length} partner${ids.length == 1 ? '' : 's'}.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _selectedPartnerIds.clear());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI Builders
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStatsRow({
    required int total,
    required int pending,
    required int approved,
    required double screenWidth,
  }) {
    final isMobile = screenWidth < 600;

    final cards = [
      _buildStatCard(
        title: 'Total Partners',
        value: total.toString(),
        icon: Icons.people_outline_rounded,
        color: AppColors.primary,
        textColor: AppColors.textOnPrimary,
        isGradient: true,
      ),
      _buildStatCard(
        title: 'Pending Review',
        value: pending.toString(),
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        textColor: AppColors.warningDark,
        isGradient: false,
      ),
      _buildStatCard(
        title: 'Approved Partners',
        value: approved.toString(),
        icon: Icons.verified_user_outlined,
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
              color: isGradient
                  ? Colors.white12
                  : color.withValues(alpha: 0.08),
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
                  color: isGradient
                      ? Colors.white70
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color:
                      isGradient ? Colors.white : AppColors.textPrimary,
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
            _debounceTimer =
                Timer(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'Search partners by name, email or phone...',
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'All',
              'Pending',
              'Approved',
              'Rejected',
              'Suspended'
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
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border),
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

  Widget _buildPartnerCard(
      BuildContext context, Profile partner, ThemeData theme) {
    Color badgeColor;
    switch (partner.status) {
      case PartnerStatus.pending:
        badgeColor = AppColors.warning;
        break;
      case PartnerStatus.approved:
        badgeColor = AppColors.success;
        break;
      case PartnerStatus.rejected:
        badgeColor = AppColors.error;
        break;
      case PartnerStatus.suspended:
        badgeColor = AppColors.textSecondary;
        break;
    }

    final initials = partner.fullName != null &&
            partner.fullName!.trim().isNotEmpty
        ? partner.fullName!
            .trim()
            .split(RegExp(r'\s+'))
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'PT';

    final regDate = DateFormat('MMM d, yyyy').format(partner.createdAt);
    final isSelected = _selectedPartnerIds.contains(partner.id);

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedPartnerIds.remove(partner.id);
            } else {
              _selectedPartnerIds.add(partner.id);
            }
          });
        } else {
          context.push('/admin/partners/${partner.id}');
        }
      },
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedPartnerIds.remove(partner.id);
          } else {
            _selectedPartnerIds.add(partner.id);
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // ── Checkbox (selection mode) or Avatar ──
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() {
                    if (isSelected) {
                      _selectedPartnerIds.remove(partner.id);
                    } else {
                      _selectedPartnerIds.add(partner.id);
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
            ] else ...[
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                  image: partner.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(partner.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: partner.avatarUrl == null
                    ? Center(
                        child: Text(
                          initials,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
            ],

            // ── Partner Details ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partner.fullName ?? 'Unnamed Partner',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          partner.status.label.toUpperCase(),
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    partner.email ?? 'No email',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        partner.phone ?? 'No phone',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Registered: $regDate',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
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

  Widget _buildEmptyState(ThemeData theme) {
    return EmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No partners found',
      description:
          'Try changing your status filters or check back later.',
      actionLabel: 'Reset Filters',
      onActionPressed: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _selectedStatusFilter = 'All';
        });
      },
    );
  }
}
