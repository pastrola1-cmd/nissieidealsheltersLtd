import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/partner_provider.dart';

class PartnerListScreen extends ConsumerStatefulWidget {
  const PartnerListScreen({super.key});

  @override
  ConsumerState<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends ConsumerState<PartnerListScreen> {
  final _searchController = TextEditingController();
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected', 'Suspended'
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
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
          partner.status.value.toLowerCase() == _selectedStatusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    // Stats calculations
    final totalCount = state.partners.length;
    final pendingCount = state.partners.where((p) => p.status == PartnerStatus.pending).length;
    final approvedCount = state.partners.where((p) => p.status == PartnerStatus.approved).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partners Directory'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      body: state.isLoading && state.partners.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () async {
                // Read current user profile to refresh partner list
                final companyId = ref.read(partnerProvider).partners.firstOrNull?.companyId;
                await ref.read(partnerProvider.notifier).loadPartners(companyId);
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
                      pending: pendingCount,
                      approved: approvedCount,
                      screenWidth: screenWidth,
                    ),
                    const SizedBox(height: 24),

                    // ── Filters & Search ──
                    _buildSearchAndFilters(theme),
                    const SizedBox(height: 24),

                    // ── Partners Directory List ──
                    if (state.errorMessage != null)
                      Center(
                        child: Text(
                          'Error: ${state.errorMessage}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      )
                    else if (filteredPartners.isEmpty)
                      _buildEmptyState(theme)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredPartners.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final partner = filteredPartners[index];
                          return _buildPartnerCard(context, partner, theme);
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
    required int pending,
    required int approved,
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
                title: 'Total Partners',
                value: total.toString(),
                icon: Icons.people_outline_rounded,
                color: AppColors.primary,
                textColor: AppColors.textOnPrimary,
                isGradient: true,
              ),
            ),
            if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 16),
            Expanded(
              flex: isMobile ? 0 : 1,
              child: _buildStatCard(
                title: 'Pending Review',
                value: pending.toString(),
                icon: Icons.hourglass_top_rounded,
                color: AppColors.warning,
                textColor: AppColors.warningDark,
                isGradient: false,
              ),
            ),
            if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 16),
            Expanded(
              flex: isMobile ? 0 : 1,
              child: _buildStatCard(
                title: 'Approved Partners',
                value: approved.toString(),
                icon: Icons.verified_user_outlined,
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
            hintText: 'Search partners by name, email or phone...',
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

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Pending', 'Approved', 'Rejected', 'Suspended'].map((status) {
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
                  elevation: 0,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerCard(BuildContext context, Profile partner, ThemeData theme) {
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

    final initials = partner.fullName != null && partner.fullName!.trim().isNotEmpty
        ? partner.fullName!
            .trim()
            .split(RegExp(r'\s+'))
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'PT';

    final regDate = DateFormat('MMM d, yyyy').format(partner.createdAt);

    return InkWell(
      onTap: () {
        context.push('/admin/partners/${partner.id}');
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Initials or Avatar
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

            // Partner Details
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.15)),
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
                Icons.people_outline_rounded,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No partners found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your status filters or check back later.',
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
