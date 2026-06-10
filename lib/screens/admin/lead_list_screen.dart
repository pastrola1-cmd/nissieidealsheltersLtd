import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/providers/partner_provider.dart';

class LeadListScreen extends ConsumerStatefulWidget {
  const LeadListScreen({super.key});

  @override
  ConsumerState<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  final _searchController = TextEditingController();
  String _selectedStageFilter = 'All'; // 'All', 'New', 'Contacted', 'Inspection Booked', 'Negotiation', 'Closed', 'Lost'
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

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
        title: const Text('Leads Pipeline'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/admin/leads/add'),
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
        ],
      ),
      body: state.isLoading && state.leads.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(leadProvider.notifier).loadLeads();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats Row ──
                    _buildStatsRow(
                      total: totalCount,
                      newLeads: newCount,
                      closed: closedCount,
                      screenWidth: screenWidth,
                    ),
                    const SizedBox(height: 24),

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
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int newLeads,
    required int closed,
    required double screenWidth,
  }) {
    final isMobile = screenWidth < 600;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          children: [
            Expanded(
              flex: isMobile ? 0 : 1,
              child: _buildStatCard(
                title: 'Total Leads',
                value: total.toString(),
                icon: Icons.assignment_rounded,
                color: AppColors.primary,
                textColor: AppColors.textOnPrimary,
                isGradient: true,
              ),
            ),
            if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 16),
            Expanded(
              flex: isMobile ? 0 : 1,
              child: _buildStatCard(
                title: 'New',
                value: newLeads.toString(),
                icon: Icons.new_releases_outlined,
                color: AppColors.info,
                textColor: AppColors.info,
                isGradient: false,
              ),
            ),
            if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 16),
            Expanded(
              flex: isMobile ? 0 : 1,
              child: _buildStatCard(
                title: 'Closed Deals',
                value: closed.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                textColor: AppColors.successDark,
                isGradient: false,
              ),
            ),
          ],
        );
      },
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
            setState(() {
              _searchQuery = val.trim().toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Search leads by buyer, property, or partner...',
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

    return InkWell(
      onTap: () {
        context.push('/admin/leads/${lead.id}');
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
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
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No leads match your filter',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a manual lead or check shared partner links.',
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
