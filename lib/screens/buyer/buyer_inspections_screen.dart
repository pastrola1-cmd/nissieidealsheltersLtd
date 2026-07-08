import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/inspection_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';

class BuyerInspectionsScreen extends ConsumerStatefulWidget {
  const BuyerInspectionsScreen({super.key});

  @override
  ConsumerState<BuyerInspectionsScreen> createState() => _BuyerInspectionsScreenState();
}

class _BuyerInspectionsScreenState extends ConsumerState<BuyerInspectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(inspectionProvider.notifier).loadInspections());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionProvider);
    final theme = Theme.of(context);
    final properties = ref.watch(propertyProvider).properties;

    // Filter inspections
    final upcomingInspections = state.inspections.where((i) =>
        i.status == InspectionStatus.pending ||
        i.status == InspectionStatus.confirmed).toList();

    final pastInspections = state.inspections.where((i) =>
        i.status == InspectionStatus.completed ||
        i.status == InspectionStatus.cancelled ||
        i.status == InspectionStatus.noShow).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Inspections'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Upcoming Visits'),
            Tab(text: 'Visit History'),
          ],
        ),
      ),
      body: state.isLoading && state.inspections.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInspectionList(upcomingInspections, properties, theme, isUpcoming: true),
                _buildInspectionList(pastInspections, properties, theme, isUpcoming: false),
              ],
            ),
    );
  }

  Widget _buildInspectionList(
    List<Inspection> inspections,
    List<Property> properties,
    ThemeData theme, {
    required bool isUpcoming,
  }) {
    if (inspections.isEmpty) {
      return _buildEmptyState(isUpcoming, theme);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(inspectionProvider.notifier).loadInspections();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(24.0),
        itemCount: inspections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final inspection = inspections[index];
          final property = properties.cast<Property?>().firstWhere((p) => p?.id == inspection.propertyId, orElse: () => null);
          return _buildInspectionCard(inspection, property, theme);
        },
      ),
    );
  }

  Widget _buildInspectionCard(Inspection inspection, Property? property, ThemeData theme) {
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
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(parsedDate);

    // Format Time slot label
    String timeLabel = inspection.scheduledTime;
    if (timeLabel == 'Morning') {
      timeLabel = 'Morning (9:00 AM - 12:00 PM)';
    } else if (timeLabel == 'Afternoon') {
      timeLabel = 'Afternoon (12:00 PM - 3:00 PM)';
    } else if (timeLabel == 'Evening') {
      timeLabel = 'Evening (3:00 PM - 6:00 PM)';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                  fontSize: 14,
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
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Property Info Row
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  image: property?.images.isNotEmpty == true
                      ? DecorationImage(
                          image: NetworkImage(property!.images.first),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: property?.images.isEmpty == true || property == null
                    ? const Icon(Icons.home_work_outlined, size: 20, color: AppColors.textTertiary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property?.title ?? 'Unknown Property Listing',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property?.location ?? 'No location listed',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Time slot details
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Notes (if exists)
          if (inspection.notes != null && inspection.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inspection.notes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isUpcoming, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUpcoming ? Icons.calendar_month_outlined : Icons.calendar_today_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isUpcoming ? 'No upcoming inspections' : 'No past inspection history',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isUpcoming
                  ? 'Book inspections from listing pages to visit property developments.'
                  : 'Your completed and cancelled inspections will show here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
