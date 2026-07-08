import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/campaign_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';

class CampaignHistoryScreen extends ConsumerWidget {
  const CampaignHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignState = ref.watch(campaignProvider);
    final properties = ref.watch(propertyProvider).properties;
    final role = ref.watch(authProvider).profile?.role.value;

    // Aggregate metrics
    int totalShares = 0;
    int totalLeads = 0;
    int totalConversions = 0;
    final Map<String, int> platformEffectiveness = {};

    for (final c in campaignState.campaigns) {
      totalShares += c.shareCount;
      totalLeads += c.leadCount;
      totalConversions += c.conversionCount;

      // We weigh conversion slightly higher to measure "effectiveness"
      final score = c.leadCount + (c.conversionCount * 3);
      platformEffectiveness[c.platform] = (platformEffectiveness[c.platform] ?? 0) + score;
    }

    String mostEffectivePlatform = 'None';
    int maxScore = -1;
    platformEffectiveness.forEach((platform, score) {
      if (score > maxScore && score > 0) {
        maxScore = score;
        mostEffectivePlatform = platform.toUpperCase();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Campaign Logs History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: campaignState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : campaignState.campaigns.isEmpty
              ? _buildEmptyState(context, role)
              : ListView.builder(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: campaignState.campaigns.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSummaryDashboard(
                        context,
                        totalShares,
                        totalLeads,
                        totalConversions,
                        mostEffectivePlatform,
                      );
                    }

                    final campaign = campaignState.campaigns[index - 1];
                    final property = properties.where((p) => p.id == campaign.propertyId).firstOrNull;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCampaignCard(context, campaign, property),
                    );
                  },
                ),
    );
  }

  Widget _buildSummaryDashboard(
    BuildContext context,
    int shares,
    int leads,
    int conversions,
    String bestPlatform,
  ) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final stats = [
      _SummaryStat('Total Shares', shares.toString(), Icons.share_rounded, AppColors.info),
      _SummaryStat('Leads Captured', leads.toString(), Icons.person_search_rounded, AppColors.primary),
      _SummaryStat('Conversions', conversions.toString(), Icons.check_circle_outline_rounded, AppColors.success),
      _SummaryStat('Top Platform', bestPlatform, Icons.workspace_premium_rounded, AppColors.warning),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Campaign Performance Analytics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          isMobile
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, idx) => _buildStatTile(stats[idx]),
                )
              : Row(
                  children: stats
                      .map((s) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: _buildStatTile(s),
                            ),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildStatTile(_SummaryStat stat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(stat.icon, color: Colors.white.withValues(alpha: 0.8), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stat.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String? role) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: AppColors.accent,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Campaigns Generated Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Once you generate and save campaigns, they will be listed here for quick access.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/$role/campaigns/generator'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Generate First Campaign', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignCard(BuildContext context, Campaign campaign, Property? property) {
    final dateStr = DateFormat('yMMMMd').add_jm().format(campaign.createdAt.toLocal());
    final text = campaign.outputData['text'] as String? ?? '';
    final hook = campaign.outputData['hook'] as String? ?? 'Listing Marketing Copy';

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Platform Badge & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPlatformColor(campaign.platform).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getPlatformColor(campaign.platform).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    campaign.platform.toUpperCase(),
                    style: TextStyle(
                      color: _getPlatformColor(campaign.platform),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 2: Property Title (if any)
            Text(
              property?.title ?? 'General Listing Campaign',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Row 3: Hook/Text Preview
            Text(
              hook,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Performance Metrics
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricItem('Shares', campaign.shareCount.toString(), Icons.share_outlined),
                  _buildMetricItem('Leads', campaign.leadCount.toString(), Icons.person_search_outlined),
                  _buildMetricItem('Conversions', campaign.conversionCount.toString(), Icons.check_circle_outline_rounded),
                  _buildMetricItem(
                    'Conv. %',
                    campaign.leadCount > 0
                        ? '${(campaign.conversionCount / campaign.leadCount * 100).toStringAsFixed(1)}%'
                        : '0.0%',
                    Icons.analytics_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Row 4: Actions (View details, Copy, Share)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDetailsBottomSheet(context, campaign, property),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('View Full Copy & Stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 20),
                  tooltip: 'Copy text',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Campaign copy copied to clipboard!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.textSecondary, size: 20),
                  tooltip: 'Share',
                  onPressed: () {
                    Share.share(text, subject: 'Marketing Campaign');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showDetailsBottomSheet(BuildContext context, Campaign campaign, Property? property) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${campaign.platform.toUpperCase()} Copy Details',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                property?.title ?? 'General Listing Campaign',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Attribution Metrics',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricItem('Shares', campaign.shareCount.toString(), Icons.share_outlined),
                    _buildMetricItem('Leads', campaign.leadCount.toString(), Icons.person_search_outlined),
                    _buildMetricItem('Conversions', campaign.conversionCount.toString(), Icons.check_circle_outline_rounded),
                    _buildMetricItem(
                      'Conv. %',
                      campaign.leadCount > 0
                          ? '${(campaign.conversionCount / campaign.leadCount * 100).toStringAsFixed(1)}%'
                          : '0.0%',
                      Icons.analytics_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    campaign.outputData['text'] as String? ?? '',
                    style: const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: campaign.outputData['text'] as String? ?? ''));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Campaign copy copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Share.share(campaign.outputData['text'] as String? ?? '');
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Colors.blue[800]!;
      case 'instagram':
        return Colors.pink[700]!;
      case 'whatsapp':
        return Colors.green[700]!;
      case 'linkedin':
        return Colors.blue[900]!;
      default:
        return AppColors.primary;
    }
  }
}

class _SummaryStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _SummaryStat(this.label, this.value, this.icon, this.color);
}
