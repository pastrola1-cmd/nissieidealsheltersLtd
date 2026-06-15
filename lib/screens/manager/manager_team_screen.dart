import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/widgets/shimmer_loading.dart';
import 'package:ppn/widgets/empty_state.dart';

class ManagerTeamScreen extends ConsumerStatefulWidget {
  const ManagerTeamScreen({super.key});

  @override
  ConsumerState<ManagerTeamScreen> createState() => _ManagerTeamScreenState();
}

class _ManagerTeamScreenState extends ConsumerState<ManagerTeamScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _makeCall(String? phone, BuildContext context) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    try {
      await launchUrl(url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not place call: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String? email, BuildContext context) async {
    if (email == null || email.isEmpty) return;
    final url = Uri.parse('mailto:$email');
    try {
      await launchUrl(url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open email client: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketersAsync = ref.watch(agencyMarketersProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Team', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      body: marketersAsync.when(
        data: (marketers) {
          // Apply filtering based on search query
          final filteredMarketers = marketers.where((m) {
            final name = m.fullName?.toLowerCase() ?? '';
            final email = m.email?.toLowerCase() ?? '';
            final phone = m.phone?.toLowerCase() ?? '';
            return name.contains(_searchQuery) ||
                email.contains(_searchQuery) ||
                phone.contains(_searchQuery);
          }).toList();

          final totalCount = marketers.length;
          final activeCount = marketers.where((m) => m.status == PartnerStatus.approved).length;
          final suspendedCount = marketers.where((m) => m.status == PartnerStatus.suspended).length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyMarketersProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats Summary ──
                  _buildStatsRow(
                    total: totalCount,
                    active: activeCount,
                    suspended: suspendedCount,
                    screenWidth: screenWidth,
                  ),
                  const SizedBox(height: 24),

                  // ── Search Bar ──
                  _buildSearchBar(),
                  const SizedBox(height: 24),

                  // ── List Section ──
                  if (filteredMarketers.isEmpty)
                    _buildEmptyState(theme, marketers.isEmpty)
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredMarketers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final member = filteredMarketers[index];
                        return _buildTeamMemberCard(context, member, theme);
                      },
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24.0),
          child: ShimmerList(),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load team: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(agencyMarketersProvider),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Try Again'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int active,
    required int suspended,
    required double screenWidth,
  }) {
    final isMobile = screenWidth < 600;

    final cards = [
      _buildStatCard(
        title: 'Total Staff',
        value: total.toString(),
        icon: Icons.badge_outlined,
        color: AppColors.primary,
        isGradient: true,
      ),
      _buildStatCard(
        title: 'Active Agents',
        value: active.toString(),
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        isGradient: false,
      ),
      _buildStatCard(
        title: 'Suspended',
        value: suspended.toString(),
        icon: Icons.block_flipped,
        color: AppColors.error,
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
    required bool isGradient,
  }) {
    return Container(
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

  Widget _buildSearchBar() {
    return TextField(
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
        hintText: 'Search staff by name, email or phone...',
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
    );
  }

  Widget _buildTeamMemberCard(BuildContext context, Profile member, ThemeData theme) {
    final initials = member.fullName != null && member.fullName!.trim().isNotEmpty
        ? member.fullName!
            .trim()
            .split(RegExp(r'\s+'))
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'AG';

    final regDate = DateFormat('MMM d, yyyy').format(member.createdAt);
    final isSuspended = member.status == PartnerStatus.suspended;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Initials / Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
              image: member.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(member.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: member.avatarUrl == null
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

          // Member Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.fullName ?? 'Unnamed Agent',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSuspended ? AppColors.textSecondary : AppColors.textPrimary,
                          decoration: isSuspended ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSuspended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                        ),
                        child: const Text(
                          'SUSPENDED',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member.email ?? 'No email',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member.phone ?? 'No phone',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined: $regDate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Quick Action Icons
          Column(
            children: [
              if (member.phone != null && member.phone!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone_in_talk_outlined, color: AppColors.primary),
                  onPressed: () => _makeCall(member.phone, context),
                  tooltip: 'Call Agent',
                ),
              if (member.email != null && member.email!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.mail_outline_rounded, color: AppColors.accent),
                  onPressed: () => _sendEmail(member.email, context),
                  tooltip: 'Email Agent',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isListEmpty) {
    return EmptyState(
      icon: Icons.people_outline_rounded,
      title: isListEmpty ? 'No team members registered' : 'No matches found',
      description: isListEmpty
          ? 'Invite marketers or agents in the administrator panel to build your sales team.'
          : 'Try refining your search keyword or resetting filters.',
      actionLabel: isListEmpty ? null : 'Clear Search',
      onActionPressed: isListEmpty
          ? null
          : () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
    );
  }
}
