import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/campaign/block_library.dart';
import 'package:nissie_ideal_shelters/core/campaign/block_types.dart';
import 'package:nissie_ideal_shelters/providers/performance_provider.dart';
import 'package:nissie_ideal_shelters/services/performance_service.dart';

class BlockPerformanceScreen extends ConsumerStatefulWidget {
  const BlockPerformanceScreen({super.key});

  @override
  ConsumerState<BlockPerformanceScreen> createState() => _BlockPerformanceScreenState();
}

class _BlockPerformanceScreenState extends ConsumerState<BlockPerformanceScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _handleRecalculate() async {
    setState(() => _isRecalculating = true);
    try {
      await ref.read(performanceProvider.notifier).recalculateScores();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Block performance scores recalculated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecalculating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final performanceState = ref.watch(performanceProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Map stats by block ID
    final Map<String, CampaignBlockStat> statsMap = {
      for (final stat in performanceState.blockStats) stat.blockId: stat
    };

    // Find top and weakest blocks
    CampaignBlock? topBlock;
    double topScore = -1.0;
    CampaignBlock? weakBlock;
    double weakScore = 999.0;

    for (final block in BlockLibrary.blocks) {
      final stat = statsMap[block.id];
      if (stat != null && stat.timesUsed >= 2) {
        if (stat.performanceScore > topScore) {
          topScore = stat.performanceScore;
          topBlock = block;
        }
        if (stat.performanceScore < weakScore) {
          weakScore = stat.performanceScore;
          weakBlock = block;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Block Performance & Evolution', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          _isRecalculating
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Recalculate Scores',
                  onPressed: _handleRecalculate,
                ),
        ],
      ),
      body: performanceState.isLoading && performanceState.blockStats.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title & Intro ──
                  Text(
                    'Marketing Strategy Optimization',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The system ranks campaign blocks by measuring conversions and leads generated. Top blocks are naturally prioritized during dynamic generation.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // ── Top & Weakest Cards Grid ──
                  if (topBlock != null || weakBlock != null) ...[
                    isMobile
                        ? Column(
                            children: [
                              if (topBlock != null) _buildInsightCard(context, '🥇 Top Performing Block', topBlock, topScore, AppColors.success),
                              if (weakBlock != null) ...[
                                const SizedBox(height: 16),
                                _buildInsightCard(context, '⚠️ Weakest Performing Block', weakBlock, weakScore, AppColors.error),
                              ]
                            ],
                          )
                        : Row(
                            children: [
                              if (topBlock != null)
                                Expanded(child: _buildInsightCard(context, '🥇 Top Performing Block', topBlock, topScore, AppColors.success)),
                              if (weakBlock != null) ...[
                                const SizedBox(width: 16),
                                Expanded(child: _buildInsightCard(context, '⚠️ Weakest Performing Block', weakBlock, weakScore, AppColors.error)),
                              ]
                            ],
                          ),
                    const SizedBox(height: 32),
                  ],

                  // ── Custom Painted Trend Chart & Strategy Recommendations ──
                  isMobile
                      ? Column(
                          children: [
                            _buildTrendChartCard(context),
                            const SizedBox(height: 16),
                            _buildRecommendationsCard(context, performanceState.blockStats),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildTrendChartCard(context)),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: _buildRecommendationsCard(context, performanceState.blockStats)),
                          ],
                        ),
                  const SizedBox(height: 32),

                  // ── Tabs List Table ──
                  Text(
                    'Campaign Blocks Library & Ranks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: AppColors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            labelColor: AppColors.accent,
                            unselectedLabelColor: AppColors.textSecondary,
                            indicatorColor: AppColors.accent,
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'HOOKS'),
                              Tab(text: 'VALUES'),
                              Tab(text: 'PROOFS'),
                              Tab(text: 'CTAS'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 400,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildBlockListTab(CampaignBlockType.hook, statsMap),
                                _buildBlockListTab(CampaignBlockType.value, statsMap),
                                _buildBlockListTab(CampaignBlockType.proof, statsMap),
                                _buildBlockListTab(CampaignBlockType.cta, statsMap),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInsightCard(BuildContext context, String title, CampaignBlock block, double score, Color accentColor) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Score: ${score.toStringAsFixed(2)}',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              block.template,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Text(
              'Block ID: ${block.id}',
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChartCard(BuildContext context) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Marketing Efficiency Gains',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Aggregated conversion performance improvement over the past weeks.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: PerformanceTrendPainter(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Week 1', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                Text('Week 2', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                Text('Week 3', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                Text('Current', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(BuildContext context, List<CampaignBlockStat> stats) {
    final lowPerformingCount = stats.where((s) => s.performanceScore < 0.4 && s.isActive && s.timesUsed >= 3).length;
    final totalDeactivated = stats.where((s) => !s.isActive).length;

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Text(
                  'Strategic Insights',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRecommendationTile(
              Icons.warning_amber_rounded,
              lowPerformingCount > 0
                  ? 'There are $lowPerformingCount low-performing blocks (< 0.4 score). Consider deactivating them to improve overall reach.'
                  : 'All analyzed blocks are performing within safe thresholds. No immediate action required.',
              lowPerformingCount > 0 ? AppColors.warning : AppColors.success,
            ),
            const Divider(height: 24, color: AppColors.border),
            _buildRecommendationTile(
              Icons.info_outline_rounded,
              totalDeactivated > 0
                  ? '$totalDeactivated blocks are currently deactivated by your managers. They will be ignored during strategy engine assembly.'
                  : 'All blocks in the block library are active. The engine selects blocks based on matches and historical performance scores.',
              AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationTile(IconData icon, String message, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockListTab(CampaignBlockType type, Map<String, CampaignBlockStat> statsMap) {
    final blocksOfType = BlockLibrary.blocks.where((b) => b.type == type).toList();

    return ListView.separated(
      itemCount: blocksOfType.length,
      separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
      itemBuilder: (context, index) {
        final block = blocksOfType[index];
        final stat = statsMap[block.id];
        final isActive = stat?.isActive ?? true;
        final double score = stat?.performanceScore ?? 1.0;
        final timesUsed = stat?.timesUsed ?? 0;
        final leads = stat?.leadsAttributed ?? 0;
        final conversions = stat?.conversionsAttributed ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.template,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _buildSmallStatLabel('Score', score.toStringAsFixed(2), score >= 1.2 ? AppColors.success : (score < 0.5 ? AppColors.error : AppColors.textSecondary)),
                        _buildSmallStatLabel('Uses', timesUsed.toString(), AppColors.textSecondary),
                        _buildSmallStatLabel('Leads', leads.toString(), AppColors.textSecondary),
                        _buildSmallStatLabel('Convs', conversions.toString(), AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${block.id}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch.adaptive(
                    value: isActive,
                    activeColor: AppColors.accent,
                    onChanged: (val) {
                      ref.read(performanceProvider.notifier).toggleBlockActiveStatus(block.id, val);
                    },
                  ),
                  Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmallStatLabel(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class PerformanceTrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.25),
          AppColors.primary.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Draw a smooth curved line showing progress/gains
    path.moveTo(0, height * 0.85);
    path.cubicTo(
      width * 0.3,
      height * 0.85,
      width * 0.45,
      height * 0.45,
      width * 0.65,
      height * 0.48,
    );
    path.cubicTo(
      width * 0.85,
      height * 0.5,
      width * 0.9,
      height * 0.2,
      width,
      height * 0.15,
    );

    final fillPath = Path.from(path);
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw interactive pulse point at the end
    final pulsePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    final pulseOutline = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(width, height * 0.15), 5, pulsePaint);
    canvas.drawCircle(Offset(width, height * 0.15), 10, pulseOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
