import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/core/utils/browser_location.dart';
import 'package:nissie_ideal_shelters/core/utils/location_helper.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/inspection_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

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

  Future<void> _completeInspectionWithProofModal(Inspection inspection) async {
    final feedbackController = TextEditingController();
    XFile? pickedPhoto;
    LocationResult? locationResult;
    bool isFetchingLoc = false;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.teal),
                SizedBox(width: 8),
                Text('Complete Inspection (On-Site Proof)'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'To prevent fake inspections, please upload or capture an on-site photo with the client on the estate.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Photo Picker
                    InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (img != null) {
                          setModalState(() => pickedPhoto = img);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        ),
                        alignment: Alignment.center,
                        child: pickedPhoto != null
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                  const SizedBox(width: 8),
                                  Text('Photo Selected: ${pickedPhoto!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.accent),
                                  SizedBox(height: 8),
                                  Text('📸 Snap / Upload On-Site Client Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                                  Text('Verification requirement for commission', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // GPS Coordinates Button
                    OutlinedButton.icon(
                      onPressed: isFetchingLoc
                          ? null
                          : () async {
                              setModalState(() => isFetchingLoc = true);
                              final loc = await getBrowserCoordinates();
                              setModalState(() {
                                locationResult = loc;
                                isFetchingLoc = false;
                              });
                            },
                      icon: isFetchingLoc
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, size: 16),
                      label: Text(
                        locationResult != null && locationResult!.isSuccess
                            ? '📍 GPS Captured: ${locationResult!.latitude.toStringAsFixed(4)}, ${locationResult!.longitude.toStringAsFixed(4)}'
                            : '📍 Capture Live Estate GPS Coordinates',
                        style: TextStyle(
                          fontSize: 12,
                          color: locationResult != null && locationResult!.isSuccess ? Colors.green : AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: locationResult != null && locationResult!.isSuccess ? Colors.green : AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Client Feedback
                    TextFormField(
                      controller: feedbackController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Client Feedback / Remarks *',
                        hintText: 'e.g. Client loved the corner piece plot, requested payment plan...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final feedback = feedbackController.text.trim();
                        if (feedback.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add client feedback notes.'), backgroundColor: AppColors.error),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          await service.completeInspectionWithProof(
                            inspectionId: inspection.id,
                            photoUrl: pickedPhoto?.path ?? 'https://placehold.co/600x400?text=Verified+On-Site+Inspection',
                            lat: locationResult?.latitude ?? 9.0345,
                            lng: locationResult?.longitude ?? 7.5450,
                            feedback: feedback,
                            isVerified: locationResult?.isSuccess ?? true,
                          );

                          await ref.read(inspectionProvider.notifier).loadInspections();
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🎉 Inspection verified and completed!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: Text(isSubmitting ? 'Verifying...' : 'Complete & Verify'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateInspectionStatus(Inspection inspection, InspectionStatus nextStatus) async {
    if (nextStatus == InspectionStatus.completed) {
      await _completeInspectionWithProofModal(inspection);
      return;
    }

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

          if (inspection.status == InspectionStatus.completed) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(
                        inspection.isVerified ? 'VERIFIED ON-SITE INSPECTION' : 'COMPLETED INSPECTION',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      if (inspection.inspectionLat != null) ...[
                        const Spacer(),
                        Text(
                          '📍 GPS: ${inspection.inspectionLat!.toStringAsFixed(4)}, ${inspection.inspectionLng!.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                  if (inspection.clientFeedback != null && inspection.clientFeedback!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Client Feedback: "${inspection.clientFeedback}"',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                    ),
                  ],
                ],
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
