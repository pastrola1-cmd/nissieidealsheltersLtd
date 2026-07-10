import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/report_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

// ─── Staff List Provider ───

/// Fetches all staff members (managers + marketers) for the current company.
final allStaffProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
  final authState = ref.watch(authProvider);
  final companyId = authState.profile?.companyId;
  if (companyId == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  final managers = await service.getProfilesByRole(UserRole.manager, companyId: companyId);
  final marketers = await service.getProfilesByRole(UserRole.marketer, companyId: companyId);
  return [...managers, ...marketers]..sort(
    (a, b) => a.createdAt.compareTo(b.createdAt),
  );
});

// ─── Staff Weekly Performance Provider ───

/// Aggregates the last 7 days of daily reports to compile per-staff KPIs.
final staffWeeklyPerformanceProvider = FutureProvider.autoDispose<List<StaffPerformance>>((ref) async {
  final notifier = ref.read(reportProvider.notifier);
  final Map<String, StaffPerformance> map = {};

  for (int i = 0; i < 7; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    final report = await notifier.fetchReportForDate(date);
    if (report == null) continue;

    for (final s in report.topStaff) {
      if (map.containsKey(s.profileId)) {
        final prev = map[s.profileId]!;
        final totalLeads = prev.leadsHandled + s.leadsHandled;
        final totalConv = prev.conversions + s.conversions;
        map[s.profileId] = StaffPerformance(
          profileId: s.profileId,
          name: s.name,
          leadsHandled: totalLeads,
          conversions: totalConv,
          conversionRate: totalLeads == 0 ? 0 : (totalConv / totalLeads) * 100,
        );
      } else {
        map[s.profileId] = s;
      }
    }
  }

  return map.values.toList()..sort((a, b) => b.conversions.compareTo(a.conversions));
});

// ─── Screen ───

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteStaff(Profile staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Staff Member'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove "${staff.fullName ?? staff.email}" from your team?',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will remove their profile and revoke access. Any leads they added will remain.',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.delete('profiles', staff.id);
      ref.invalidate(allStaffProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.fullName ?? "Staff"} has been removed.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete staff: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(allStaffProvider);
    final performanceAsync = ref.watch(staffWeeklyPerformanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Staff Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Invite New Staff',
            color: AppColors.accent,
            onPressed: () => context.push('/admin/invite-staff'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'All Staff'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: All Staff List ──
          staffAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(
              child: Text('Failed to load staff: $e', style: const TextStyle(color: AppColors.error)),
            ),
            data: (allStaff) {
              final managers = allStaff.where((p) => p.role == UserRole.manager).toList();
              final marketers = allStaff.where((p) => p.role == UserRole.marketer).toList();

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(allStaffProvider),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildSummaryBanner(
                        totalManagers: managers.length,
                        totalMarketers: marketers.length,
                      ),
                    ),

                    if (managers.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(
                          theme,
                          icon: Icons.manage_accounts_rounded,
                          label: 'Managers',
                          count: managers.length,
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildStaffCard(managers[index], performanceAsync),
                          childCount: managers.length,
                        ),
                      ),
                    ],

                    if (marketers.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(
                          theme,
                          icon: Icons.person_pin_rounded,
                          label: 'Agents / Marketers',
                          count: marketers.length,
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildStaffCard(marketers[index], performanceAsync),
                          childCount: marketers.length,
                        ),
                      ),
                    ],

                    if (allStaff.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: AppColors.textTertiary),
                              SizedBox(height: 12),
                              Text(
                                'No staff members yet',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tap the + icon to invite your first staff member.',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                  ],
                ),
              );
            },
          ),

          // ── Tab 2: Performance (Last 7 Days) ──
          performanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(
              child: Text('Failed to load performance: $e', style: const TextStyle(color: AppColors.error)),
            ),
            data: (performances) {
              if (performances.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insights_rounded, size: 64, color: AppColors.textTertiary),
                      SizedBox(height: 12),
                      Text(
                        'No performance data yet',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Data will appear after daily reports are compiled.',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(staffWeeklyPerformanceProvider),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Aggregated performance for the last 7 days',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...performances.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final perf = entry.value;
                      return _buildPerformanceCard(perf, rank);
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner({required int totalManagers, required int totalMarketers}) {
    final total = totalManagers + totalMarketers;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Staff Members',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    _badgeStat('Managers', totalManagers),
                    _badgeStat('Agents', totalMarketers),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_rounded, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _badgeStat(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, {required IconData icon, required String label, required int count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Profile staff, AsyncValue<List<StaffPerformance>> performanceAsync) {
    final initials = (staff.fullName?.isNotEmpty == true)
        ? staff.fullName!.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase()
        : (staff.email?.isNotEmpty == true ? staff.email![0].toUpperCase() : '?');

    final roleLabel = staff.role == UserRole.manager ? 'Manager' : 'Agent / Marketer';
    final roleColor = staff.role == UserRole.manager ? AppColors.info : AppColors.success;

    // Find matching performance
    StaffPerformance? perfData;
    if (performanceAsync.hasValue) {
      try {
        perfData = performanceAsync.value!.firstWhere((p) => p.profileId == staff.id);
      } catch (_) {
        perfData = null;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.8),
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: staff.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            staff.avatarUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                initials,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                // Name and role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.fullName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staff.email ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Performance row (if data exists)
            if (perfData != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _perfStat('Leads', perfData.leadsHandled.toString(), Icons.person_search_outlined),
                    _divider(),
                    _perfStat('Conversions', perfData.conversions.toString(), Icons.handshake_outlined),
                    _divider(),
                    _perfStat('Conv. Rate', '${perfData.conversionRate.toStringAsFixed(0)}%', Icons.trending_up_rounded),
                  ],
                ),
              ),
            ] else if (performanceAsync.hasValue) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
                  SizedBox(width: 4),
                  Text(
                    'No activity recorded in the last 7 days',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ],

            // Footer: phone + join date + delete
            const SizedBox(height: 12),
            Row(
              children: [
                if (staff.phone != null) ...[
                  const Icon(Icons.phone_outlined, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    staff.phone!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  'Joined ${DateFormat('MMM yyyy').format(staff.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  tooltip: 'Remove Staff',
                  onPressed: () => _confirmDeleteStaff(staff),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _perfStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: AppColors.border);
  }

  Widget _buildPerformanceCard(StaffPerformance perf, int rank) {
    final isTopThree = rank <= 3;
    final medalColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];
    final medalColor = isTopThree ? medalColors[rank - 1] : AppColors.textTertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTopThree ? medalColor.withValues(alpha: 0.4) : AppColors.border,
          width: isTopThree ? 1.5 : 1,
        ),
        boxShadow: isTopThree
            ? [BoxShadow(color: medalColor.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank Medal
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: medalColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isTopThree
                    ? Icon(Icons.emoji_events_rounded, color: medalColor, size: 22)
                    : Text(
                        '#$rank',
                        style: TextStyle(
                          color: medalColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Staff Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    perf.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Progress bar showing conversion rate
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (perf.conversionRate / 100).clamp(0.0, 1.0),
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTopThree ? medalColor : AppColors.accent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${perf.conversions} deals',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${perf.leadsHandled} leads · ${perf.conversionRate.toStringAsFixed(0)}% rate',
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
