import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/analytics_provider.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/widgets/goals_dashboard_list.dart';

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends ConsumerState<AnalyticsDashboardScreen> {
  String _sortBy = 'leads'; // 'leads', 'conversions', 'rate'

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analyticsProvider.notifier).loadAnalytics());
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsStateProvider);
    final userProfile = ref.watch(authProvider).profile;
    final isManager = userProfile?.role == UserRole.manager;
    final rolePath = isManager ? 'manager' : 'admin';

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Agency Analytics',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export CSV Report',
            onPressed: () => _exportAnalyticsCSV(context, analytics, isManager),
          ),
        ],
      ),
      body: analytics.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(analyticsProvider.notifier).loadAnalytics(),
              color: AppColors.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector Chips
                    _buildPeriodSelector(analytics),
                    const SizedBox(height: 24),

                    // KPIs Summary Cards Grid
                    _buildKpisGrid(analytics, isManager, isMobile),
                    const SizedBox(height: 28),

                    // Goals Section (Horizontal list of goal cards)
                    const GoalsDashboardList(),
                    const SizedBox(height: 28),

                    // Pipeline Funnel Widget
                    _buildFunnelChart(context, analytics, rolePath),
                    const SizedBox(height: 28),

                    // Monthly Revenue Trend Chart (Hidden for managers)
                    if (!isManager) ...[
                      _buildRevenueTrendChart(analytics),
                      const SizedBox(height: 28),
                    ],

                    // Staff Performance Table Card
                    _buildStaffLeaderboardCard(analytics),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(AnalyticsState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalyticsPeriod.values.map((p) {
          final isSelected = state.period == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(_getPeriodLabel(p)),
              selected: isSelected,
              onSelected: (_) => ref.read(analyticsProvider.notifier).setPeriod(p),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpisGrid(AnalyticsState state, bool isManager, bool isMobile) {
    final leadDelta = _calculateDelta(state.totalLeadsCurrent.toDouble(), state.totalLeadsPrevious.toDouble());
    final convDelta = _calculateDelta(state.conversionRateCurrent, state.conversionRatePrevious);
    final revDelta = _calculateDelta(state.revenueCurrent, state.revenuePrevious);

    final kpis = [
      _KpiData(
        title: 'Total Leads',
        value: state.totalLeadsCurrent.toString(),
        icon: Icons.trending_up_rounded,
        color: AppColors.primary,
        delta: leadDelta,
        unit: 'leads',
      ),
      _KpiData(
        title: 'Conversion Rate',
        value: '${state.conversionRateCurrent.toStringAsFixed(1)}%',
        icon: Icons.percent_rounded,
        color: AppColors.success,
        delta: convDelta,
        unit: '%',
      ),
      if (!isManager)
        _KpiData(
          title: 'Closed Revenue',
          value: '₦${_formatCompact(state.revenueCurrent)}',
          icon: Icons.monetization_on_outlined,
          color: Colors.teal,
          delta: revDelta,
          unit: 'revenue',
        ),
      _KpiData(
        title: 'Active Campaigns',
        value: state.activeCampaignsCount.toString(),
        icon: Icons.auto_awesome_rounded,
        color: AppColors.accent,
        delta: 0.0,
        unit: '',
        isCampaign: true,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isMobile ? 1.25 : 1.4,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(kpi.icon, color: kpi.color, size: 24),
                    if (kpi.delta != 0.0)
                      Row(
                        children: [
                          Icon(
                            kpi.delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: kpi.delta > 0 ? AppColors.success : AppColors.error,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${kpi.delta.abs().toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: kpi.delta > 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        kpi.value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kpi.title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (kpi.isCampaign)
                        const Text(
                          'Total templates run',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        )
                      else if (kpi.delta == 0.0)
                        const Text(
                          'Flat pace vs last',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        )
                      else
                        Text(
                          'vs last period',
                          style: TextStyle(
                            fontSize: 10,
                            color: kpi.delta > 0 ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFunnelChart(BuildContext context, AnalyticsState state, String rolePath) {
    final theme = Theme.of(context);
    final totalLeads = state.pipelineFunnel.values.fold<int>(0, (sum, val) => sum + val);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Funnel Conversion',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Drop-off rate and count at each stage of the sales pipeline.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (totalLeads == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    'No active leads found in this period.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...LeadStage.values.map((stage) {
                final count = state.pipelineFunnel[stage] ?? 0;
                final percentage = totalLeads == 0 ? 0.0 : count / totalLeads;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      context.go('/$rolePath/leads?stage=${stage.label}');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStageColor(stage),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  stage.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$count leads (${(percentage * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 12,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(_getStageColor(stage)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTrendChart(AnalyticsState state) {
    if (state.revenueTrend.isEmpty) return const SizedBox.shrink();

    // Find maximum monthly revenue to scale the visual columns
    final maxRevenue = state.revenueTrend.fold<double>(0.0, (max, m) => m.revenue > max ? m.revenue : max);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Closed Sales Volume Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sum of property sales values over the last 6 months.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: state.revenueTrend.map((m) {
                  final columnHeight = maxRevenue > 0 ? (m.revenue / maxRevenue) * 110 : 0.0;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          m.revenue > 0 ? '₦${_formatCompact(m.revenue)}' : '₦0',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: columnHeight + 4, // minimum 4px height
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: AppColors.successGradient,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          m.monthLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffLeaderboardCard(AnalyticsState state) {
    final staff = List<StaffPerformance>.from(state.staffPerformance);
    
    // Sort staff list locally based on selected parameter
    if (_sortBy == 'leads') {
      staff.sort((a, b) => b.leadsHandled.compareTo(a.leadsHandled));
    } else if (_sortBy == 'conversions') {
      staff.sort((a, b) => b.conversions.compareTo(a.conversions));
    } else if (_sortBy == 'rate') {
      staff.sort((a, b) => b.conversionRate.compareTo(a.conversionRate));
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Staff Performance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                // Sorting Controls
                DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                  items: const [
                    DropdownMenuItem(value: 'leads', child: Text('Sort by Leads')),
                    DropdownMenuItem(value: 'conversions', child: Text('Sort by Deals')),
                    DropdownMenuItem(value: 'rate', child: Text('Sort by Conv %')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _sortBy = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tracks marketing activity and conversions per agent.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (staff.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No marketing staff registered yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: staff.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final s = staff[index];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.leadsHandled} Leads Handled',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${s.conversions} Closed',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.conversionRate.toStringAsFixed(1)}% Conversion',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: s.conversionRate >= 10.0 ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel(AnalyticsPeriod p) {
    switch (p) {
      case AnalyticsPeriod.today:
        return 'Today';
      case AnalyticsPeriod.thisWeek:
        return 'This Week';
      case AnalyticsPeriod.thisMonth:
        return 'This Month';
      case AnalyticsPeriod.thisQuarter:
        return 'This Quarter';
    }
  }

  double _calculateDelta(double current, double previous) {
    if (previous == 0.0) return 0.0;
    return ((current - previous) / previous) * 100;
  }

  String _formatCompact(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  Color _getStageColor(LeadStage stage) {
    switch (stage) {
      case LeadStage.newLead:
        return AppColors.stageNew;
      case LeadStage.contacted:
        return AppColors.stageContacted;
      case LeadStage.inspectionBooked:
        return AppColors.stageInspection;
      case LeadStage.negotiation:
        return AppColors.stageNegotiation;
      case LeadStage.closed:
        return AppColors.stageClosed;
      case LeadStage.lost:
        return AppColors.stageLost;
    }
  }

  Future<void> _exportAnalyticsCSV(BuildContext context, AnalyticsState state, bool isManager) async {
    try {
      final csvBuffer = StringBuffer();
      
      csvBuffer.writeln('ScaleWealth Estate Analytics Report');
      csvBuffer.writeln('Period,${state.startDate.toIso8601String().split('T').first} to ${state.endDate.toIso8601String().split('T').first}');
      csvBuffer.writeln();

      csvBuffer.writeln('KEY PERFORMANCE INDICATORS');
      csvBuffer.writeln('Metric,Current value,Previous value');
      csvBuffer.writeln('Total Leads,${state.totalLeadsCurrent},${state.totalLeadsPrevious}');
      csvBuffer.writeln('Conversion Rate,${state.conversionRateCurrent.toStringAsFixed(2)}%,${state.conversionRatePrevious.toStringAsFixed(2)}%');
      if (!isManager) {
        csvBuffer.writeln('Closed Sales Volume,₦${state.revenueCurrent},₦${state.revenuePrevious}');
      }
      csvBuffer.writeln('Active Campaigns,${state.activeCampaignsCount},N/A');
      csvBuffer.writeln();

      csvBuffer.writeln('SALES FUNNEL PIPELINE');
      csvBuffer.writeln('Stage,Leads Count');
      for (final stage in LeadStage.values) {
        csvBuffer.writeln('${stage.label},${state.pipelineFunnel[stage] ?? 0}');
      }
      csvBuffer.writeln();

      csvBuffer.writeln('STAFF PERFORMANCE LEADERBOARD');
      csvBuffer.writeln('Agent Name,Leads Handled,Deals Closed,Conversion Rate');
      for (final s in state.staffPerformance) {
        csvBuffer.writeln('${s.name},${s.leadsHandled},${s.conversions},${s.conversionRate.toStringAsFixed(2)}%');
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/agency_analytics_report.csv');
      await file.writeAsString(csvBuffer.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'ScaleWealth Estate Analytics Report',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double delta;
  final String unit;
  final bool isCampaign;

  _KpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.delta,
    required this.unit,
    this.isCampaign = false,
  });
}

// Global Provider Extension
final analyticsStateProvider = Provider<AnalyticsState>((ref) {
  return ref.watch(analyticsProvider);
});
