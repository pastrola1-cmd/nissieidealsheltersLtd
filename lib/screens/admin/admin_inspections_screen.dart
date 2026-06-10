import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/inspection_provider.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/partner_provider.dart';
import 'package:ppn/providers/property_provider.dart';

class AdminInspectionsScreen extends ConsumerStatefulWidget {
  const AdminInspectionsScreen({super.key});

  @override
  ConsumerState<AdminInspectionsScreen> createState() => _AdminInspectionsScreenState();
}

class _AdminInspectionsScreenState extends ConsumerState<AdminInspectionsScreen> {
  final _searchController = TextEditingController();
  final _statusNoteController = TextEditingController();
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Confirmed', 'Completed', 'Cancelled', 'No Show'
  String _searchQuery = '';
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(inspectionProvider.notifier).loadInspections();
      ref.read(leadProvider.notifier).loadLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _statusNoteController.dispose();
    super.dispose();
  }

  Future<void> _updateInspectionStatus(Inspection inspection, InspectionStatus nextStatus) async {
    _statusNoteController.clear();
    final bool? confirmChange = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Transition to ${nextStatus.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to change status from ${inspection.status.label} to ${nextStatus.label}?'),
              const SizedBox(height: 16),
              TextField(
                controller: _statusNoteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Optional note/reason',
                  hintText: 'Enter reason for cancellation or confirmation details...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmChange == true) {
      setState(() => _isActionInProgress = true);
      final success = await ref.read(inspectionProvider.notifier).updateStatus(
            inspection.id,
            nextStatus,
            notes: _statusNoteController.text.trim().isEmpty ? null : _statusNoteController.text.trim(),
          );
      
      setState(() => _isActionInProgress = false);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Inspection status changed to ${nextStatus.label}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final error = ref.read(inspectionProvider).errorMessage ?? 'Failed to update status';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionProvider);
    final theme = Theme.of(context);

    // Resolvers
    final properties = ref.watch(propertyProvider).properties;
    final partners = ref.watch(partnerProvider).partners;
    final leads = ref.watch(leadProvider).leads;

    // Filtering
    final filtered = state.inspections.where((i) {
      final property = properties.cast<Property?>().firstWhere((p) => p?.id == i.propertyId, orElse: () => null);
      final partner = partners.cast<Profile?>().firstWhere((p) => p?.id == i.partnerId, orElse: () => null);
      final lead = leads.cast<Lead?>().firstWhere((l) => l?.id == i.leadId, orElse: () => null);

      final propTitle = property?.title.toLowerCase() ?? '';
      final partnerName = partner?.fullName?.toLowerCase() ?? '';
      final buyerName = lead?.buyerName.toLowerCase() ?? '';

      final matchesSearch = propTitle.contains(_searchQuery) ||
          partnerName.contains(_searchQuery) ||
          buyerName.contains(_searchQuery);

      final matchesStatus = _selectedStatusFilter == 'All' ||
          i.status.value.toLowerCase() == _selectedStatusFilter.replaceAll(' ', '_').toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Inspections'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.isLoading && state.inspections.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                // ── Search & Filter Panel ──
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search inspections by buyer, property, or agent...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
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
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All',
                            'Pending',
                            'Confirmed',
                            'Completed',
                            'Cancelled',
                            'No Show'
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
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                                ),
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Inspection list ──
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(inspectionProvider.notifier).loadInspections();
                    },
                    child: filtered.isEmpty
                        ? _buildEmptyState(theme)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final inspection = filtered[index];
                              final property = properties.cast<Property?>().firstWhere((p) => p?.id == inspection.propertyId, orElse: () => null);
                              final partner = partners.cast<Profile?>().firstWhere((p) => p?.id == inspection.partnerId, orElse: () => null);
                              final lead = leads.cast<Lead?>().firstWhere((l) => l?.id == inspection.leadId, orElse: () => null);
                              return _buildAdminInspectionCard(inspection, property, partner, lead, theme);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAdminInspectionCard(
    Inspection inspection,
    Property? property,
    Profile? partner,
    Lead? lead,
    ThemeData theme,
  ) {
    Color statusColor;
    switch (inspection.status) {
      case InspectionStatus.pending:
        statusColor = AppColors.info;
        break;
      case InspectionStatus.confirmed:
        statusColor = AppColors.success;
        break;
      case InspectionStatus.completed:
        statusColor = Colors.teal;
        break;
      case InspectionStatus.cancelled:
        statusColor = AppColors.error;
        break;
      case InspectionStatus.noShow:
        statusColor = AppColors.textTertiary;
        break;
    }

    // Format Date
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(inspection.scheduledDate);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final formattedDate = DateFormat('MMM d, yyyy').format(parsedDate);

    // Format Time slot label
    String timeLabel = inspection.scheduledTime;
    if (timeLabel == 'Morning') {
      timeLabel = 'Morning (9:00 AM - 12:00 PM)';
    } else if (timeLabel == 'Afternoon') {
      timeLabel = 'Afternoon (12:00 PM - 3:00 PM)';
    } else if (timeLabel == 'Evening') {
      timeLabel = 'Evening (3:00 PM - 6:00 PM)';
    }

    final buyerName = lead?.buyerName ?? 'Buyer Client';
    final buyerPhone = lead?.buyerPhone ?? 'No Phone';
    final partnerName = partner?.fullName ?? 'Direct Client';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status badge & date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                ),
                child: Text(
                  inspection.status.label.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Details grid
          _buildItemRow(label: 'BUYER', value: '$buyerName ($buyerPhone)', icon: Icons.person_outline_rounded),
          const SizedBox(height: 8),
          _buildItemRow(label: 'PROPERTY', value: property?.title ?? 'Unknown Property Listing', icon: Icons.home_work_outlined),
          const SizedBox(height: 8),
          _buildItemRow(label: 'AGENT', value: partnerName, icon: Icons.handshake_outlined),
          const SizedBox(height: 8),
          _buildItemRow(label: 'SLOT', value: timeLabel, icon: Icons.access_time_rounded),

          if (inspection.notes != null && inspection.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Notes: ${inspection.notes}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // Action Buttons
          if (inspection.status == InspectionStatus.pending || inspection.status == InspectionStatus.confirmed) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (_isActionInProgress)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else
              Row(
                children: [
                  if (inspection.status == InspectionStatus.pending) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateInspectionStatus(inspection, InspectionStatus.cancelled),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancel Visit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateInspectionStatus(inspection, InspectionStatus.confirmed),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  if (inspection.status == InspectionStatus.confirmed) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateInspectionStatus(inspection, InspectionStatus.noShow),
                        icon: const Icon(Icons.person_off_outlined, size: 16),
                        label: const Text('No-Show'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateInspectionStatus(inspection, InspectionStatus.cancelled),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateInspectionStatus(inspection, InspectionStatus.completed),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow({required String label, required String value, required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No inspections found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Inspections booked by buyer clients will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
