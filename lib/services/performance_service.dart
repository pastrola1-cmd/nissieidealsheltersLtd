import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ppn/config/supabase_config.dart';
import 'package:ppn/models/models.dart';

class CampaignBlockStat {
  final String companyId;
  final String blockId;
  final int timesUsed;
  final int leadsAttributed;
  final int conversionsAttributed;
  final double performanceScore;
  final bool isActive;

  const CampaignBlockStat({
    required this.companyId,
    required this.blockId,
    required this.timesUsed,
    required this.leadsAttributed,
    required this.conversionsAttributed,
    required this.performanceScore,
    this.isActive = true,
  });

  factory CampaignBlockStat.fromJson(Map<String, dynamic> json) {
    return CampaignBlockStat(
      companyId: json['company_id'] as String,
      blockId: json['block_id'] as String,
      timesUsed: json['times_used'] as int? ?? 0,
      leadsAttributed: json['leads_attributed'] as int? ?? 0,
      conversionsAttributed: json['conversions_attributed'] as int? ?? 0,
      performanceScore: (json['performance_score'] as num? ?? 1.0).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'block_id': blockId,
      'times_used': timesUsed,
      'leads_attributed': leadsAttributed,
      'conversions_attributed': conversionsAttributed,
      'performance_score': performanceScore,
      'is_active': isActive,
    };
  }

  CampaignBlockStat copyWith({
    String? companyId,
    String? blockId,
    int? timesUsed,
    int? leadsAttributed,
    int? conversionsAttributed,
    double? performanceScore,
    bool? isActive,
  }) {
    return CampaignBlockStat(
      companyId: companyId ?? this.companyId,
      blockId: blockId ?? this.blockId,
      timesUsed: timesUsed ?? this.timesUsed,
      leadsAttributed: leadsAttributed ?? this.leadsAttributed,
      conversionsAttributed: conversionsAttributed ?? this.conversionsAttributed,
      performanceScore: performanceScore ?? this.performanceScore,
      isActive: isActive ?? this.isActive,
    );
  }
}

class PerformanceService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<CampaignBlockStat>> getBlockStats(String companyId) async {
    final response = await _client
        .from('campaign_block_stats')
        .select()
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(response)
        .map((json) => CampaignBlockStat.fromJson(json))
        .toList();
  }

  Future<void> updateBlockActiveStatus(String companyId, String blockId, bool isActive) async {
    await _client.from('campaign_block_stats').upsert({
      'company_id': companyId,
      'block_id': blockId,
      'is_active': isActive,
    }, onConflict: 'company_id,block_id');
  }

  Future<void> recalculateBlockScores(String companyId) async {
    // 1. Fetch all campaigns for the company
    final campaignsData = await _client
        .from('campaigns')
        .select()
        .eq('company_id', companyId);
    final campaigns = List<Map<String, dynamic>>.from(campaignsData)
        .map((json) => Campaign.fromJson(json))
        .toList();

    // 2. Aggregate counts per block from campaign output_data
    final Map<String, int> timesUsedMap = {};
    final Map<String, int> leadsMap = {};
    final Map<String, int> conversionsMap = {};

    for (final campaign in campaigns) {
      final hookId = campaign.outputData['hook_id'] as String?;
      final valueId = campaign.outputData['value_id'] as String?;
      final proofId = campaign.outputData['proof_id'] as String?;
      final ctaId = campaign.outputData['cta_id'] as String?;

      final blockIds = [hookId, valueId, proofId, ctaId].whereType<String>();

      for (final id in blockIds) {
        timesUsedMap[id] = (timesUsedMap[id] ?? 0) + 1;
        leadsMap[id] = (leadsMap[id] ?? 0) + campaign.leadCount;
        conversionsMap[id] = (conversionsMap[id] ?? 0) + campaign.conversionCount;
      }
    }

    // 3. Fetch current block stats to preserve 'is_active' status
    final currentStats = await getBlockStats(companyId);
    final Map<String, bool> activeStatusMap = {
      for (final stat in currentStats) stat.blockId: stat.isActive
    };

    // 4. Calculate scores and prepare upsert records
    final List<Map<String, dynamic>> recordsToUpsert = [];
    final allBlockIds = timesUsedMap.keys.toSet();

    for (final id in allBlockIds) {
      final timesUsed = timesUsedMap[id] ?? 0;
      final leads = leadsMap[id] ?? 0;
      final conversions = conversionsMap[id] ?? 0;

      double score = 1.0;
      if (timesUsed >= 5) {
        final double leadRate = leads / timesUsed;
        final double conversionRate = conversions / timesUsed;
        score = (conversionRate * 3.0) + (leadRate * 1.0);
      }

      // Clamp score between 0.1 and 2.0
      if (score < 0.1) score = 0.1;
      if (score > 2.0) score = 2.0;

      recordsToUpsert.add({
        'company_id': companyId,
        'block_id': id,
        'times_used': timesUsed,
        'leads_attributed': leads,
        'conversions_attributed': conversions,
        'performance_score': score,
        'is_active': activeStatusMap[id] ?? true,
      });
    }

    // 5. Upsert to Supabase
    if (recordsToUpsert.isNotEmpty) {
      await _client.from('campaign_block_stats').upsert(recordsToUpsert);
    }
  }
}

final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return PerformanceService();
});
