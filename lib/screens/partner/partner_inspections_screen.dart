import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/inspection_provider.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/property_provider.dart';

class PartnerInspectionsScreen extends ConsumerStatefulWidget {
  const PartnerInspectionsScreen({super.key});

  @override
  ConsumerState<PartnerInspectionsScreen> createState() => _PartnerInspectionsScreenState();
}

class _PartnerInspectionsScreenState extends ConsumerState<PartnerInspectionsScreen> {
  final _searchController = TextEditingController();
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Confirmed', 'Completed', 'Cancelled', 'No Show'
  String _searchQuery = '';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionProvider);
    final theme = Theme.of(context);

    // Resolvers
    final properties = ref.watch(propertyProvider).properties;
    final leads = ref.watch(leadProvider).leads;

    // Filter by search & status
    final filtered = state.inspections.where((i) {
      final property = properties.cast<Property?>().firstWhere((p) => p?.id == i.propertyId, orElse: () => null);
      final lead = leads.cast<Lead?>().firstWhere((l) => l?.id == i.leadId, orElse: () => null);

      final propTitle = property?.title.toLowerCase() ?? '';
      final buyerName = lead?.buyerName.toLowerCase() ?? '';

      final matchesSearch = propTitle.contains(_searchQuery) || buyerName.contains(_searchQuery);

      final matchesStatus = _selectedStatusFilter == 'All' ||
          i.status.value.toLowerCase() == _selectedStatusFilter.replaceAll(' ', '_').toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    // Alert Banner calculation
    final pendingCount = state.inspections.where((i) => i.status == InspectionStatus.pending).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Referred Inspections'),
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
                // ── Alerts Banner ──
                if (pendingCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      border: Border(bottom: BorderSide(color: AppColors.warning.withValues(alpha: 0.2))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.warningDark, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have $pendingCount pending inspection request${pendingCount > 1 ? 's' : ''} from referred leads. Reach out to coordinate with the admin.',
                            style: const TextStyle(
                              color: AppColors.warningDark,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          hintText: 'Search inspections by buyer or property...',
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
                              final lead = leads.cast<Lead?>().firstWhere((l) => l?.id == inspection.leadId, orElse: () => null);
                              return _buildPartnerInspectionCard(inspection, property, lead, theme);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPartnerInspectionCard(
    Inspection inspection,
    Property? property,
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

          _buildItemRow(label: 'BUYER', value: '$buyerName ($buyerPhone)', icon: Icons.person_outline_rounded),
          const SizedBox(height: 8),
          _buildItemRow(label: 'PROPERTY', value: property?.title ?? 'Unknown Property Listing', icon: Icons.home_work_outlined),
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
              'No referred inspections found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Property inspections booked by your referred leads will show here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
