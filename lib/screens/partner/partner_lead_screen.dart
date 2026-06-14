import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/property_provider.dart';

class PartnerLeadScreen extends ConsumerStatefulWidget {
  final String? initialStageFilter;
  const PartnerLeadScreen({super.key, this.initialStageFilter});

  @override
  ConsumerState<PartnerLeadScreen> createState() => _PartnerLeadScreenState();
}

class _PartnerLeadScreenState extends ConsumerState<PartnerLeadScreen> {
  final _searchController = TextEditingController();
  String _selectedStageFilter = 'All'; // 'All', 'New', 'Contacted', 'Inspection Booked', 'Negotiation', 'Closed', 'Lost'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final validStages = ['All', 'New', 'Contacted', 'Inspection Booked', 'Negotiation', 'Closed', 'Lost'];
    if (widget.initialStageFilter != null && validStages.contains(widget.initialStageFilter)) {
      _selectedStageFilter = widget.initialStageFilter!;
    }
  }

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

    // Cache properties to resolve listing names
    final properties = ref.watch(propertyProvider).properties;

    // Filter leads
    final filteredLeads = state.leads.where((lead) {
      final property = properties.cast<Property?>().firstWhere((p) => p?.id == lead.propertyId, orElse: () => null);

      final propTitle = property?.title.toLowerCase() ?? '';
      final buyerName = lead.buyerName.toLowerCase();
      final buyerPhone = lead.buyerPhone.toLowerCase();
      final buyerEmail = lead.buyerEmail?.toLowerCase() ?? '';

      final matchesSearch = propTitle.contains(_searchQuery) ||
          buyerName.contains(_searchQuery) ||
          buyerPhone.contains(_searchQuery) ||
          buyerEmail.contains(_searchQuery);

      final matchesStage = _selectedStageFilter == 'All' ||
          lead.stage.value.toLowerCase() == _selectedStageFilter.replaceAll(' ', '_').toLowerCase();

      return matchesSearch && matchesStage;
    }).toList();

    // Stats calculations
    final totalCount = state.leads.length;
    final activeCount = state.leads.where((l) =>
        l.stage == LeadStage.newLead ||
        l.stage == LeadStage.contacted ||
        l.stage == LeadStage.inspectionBooked ||
        l.stage == LeadStage.negotiation).length;
    final closedCount = state.leads.where((l) => l.stage == LeadStage.closed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Referrals'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/partner/leads/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Refer Buyer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                      active: activeCount,
                      closed: closedCount,
                      screenWidth: screenWidth,
                    ),
                    const SizedBox(height: 24),

                    // ── Filters & Search ──
                    _buildSearchAndFilters(theme),
                    const SizedBox(height: 24),

                    // ── Referred Leads List ──
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
                          return _buildLeadCard(lead, property, theme);
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
    required int active,
    required int closed,
    required double screenWidth,
  }) {
    final isMobile = screenWidth < 600;
    
    final cards = [
      _buildStatCard(
        title: 'Total Referred',
        value: total.toString(),
        icon: Icons.share_rounded,
        color: AppColors.primary,
        textColor: AppColors.textOnPrimary,
        isGradient: true,
      ),
      _buildStatCard(
        title: 'Active Pipeline',
        value: active.toString(),
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        textColor: AppColors.warningDark,
        isGradient: false,
      ),
      _buildStatCard(
        title: 'Closed Sales',
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
            setState(() {
              _searchQuery = val.trim().toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Search my referrals by buyer or property name...',
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

        // Pipeline stage filters
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

  Widget _buildLeadCard(Lead lead, Property? property, ThemeData theme) {
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

    return Ink(
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_outlined, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    'Via: ${lead.sourceChannel.toUpperCase()}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Text(
                'Status Date: $dateStr',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ],
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
              'No referred leads found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your property links to start generating leads.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/partner/leads/add'),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Register Buyer Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
