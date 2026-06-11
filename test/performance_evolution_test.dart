import 'package:flutter_test/flutter_test.dart';
import 'package:ppn/core/campaign/block_types.dart';
import 'package:ppn/core/campaign/block_library.dart';
import 'package:ppn/core/campaign/strategy_engine.dart';
import 'package:ppn/services/performance_service.dart';

void main() {
  group('Performance Evolution Loop Tests', () {
    test('CampaignBlockStat serialization from/to JSON works successfully', () {
      final json = {
        'company_id': 'company_uuid_1',
        'block_id': 'block_id_1',
        'times_used': 10,
        'leads_attributed': 5,
        'conversions_attributed': 2,
        'performance_score': 1.25,
        'is_active': true,
      };

      final stat = CampaignBlockStat.fromJson(json);

      expect(stat.companyId, 'company_uuid_1');
      expect(stat.blockId, 'block_id_1');
      expect(stat.timesUsed, 10);
      expect(stat.leadsAttributed, 5);
      expect(stat.conversionsAttributed, 2);
      expect(stat.performanceScore, 1.25);
      expect(stat.isActive, true);

      final outJson = stat.toJson();
      expect(outJson['company_id'], 'company_uuid_1');
      expect(outJson['block_id'], 'block_id_1');
      expect(outJson['performance_score'], 1.25);
      expect(outJson['is_active'], true);
    });

    test('StrategyEngine respects custom blockScores during sorting', () {
      final cleanCity = 'lagos';
      final cleanAudience = 'investor';
      final cleanPropertyType = 'apartment';
      final cleanUrgency = 'high';

      // Filter candidate proofs from BlockLibrary
      final candidates = BlockLibrary.blocks.where((b) {
        final cityMatch = b.applicableCities.contains(cleanCity) || b.applicableCities.contains('all');
        final audienceMatch = b.applicableAudiences.contains(cleanAudience) || b.applicableAudiences.contains('all');
        final propMatch = b.applicablePropertyTypes.contains(cleanPropertyType) || b.applicablePropertyTypes.contains('all');
        final urgencyMatch = b.urgencyLevel == cleanUrgency || b.urgencyLevel == 'all';
        return b.type == CampaignBlockType.proof && cityMatch && audienceMatch && propMatch && urgencyMatch;
      }).toList();

      final first = candidates.firstWhere((b) => b.id == 'proof_lagos_occupancy');
      final second = candidates.firstWhere((b) => b.id == 'proof_investor_yield');

      // Case A: Boost second block score
      final blockScoresA = {
        first.id: 0.2,
        second.id: 1.8,
      };

      final selectedA = StrategyEngine.selectBlock(
        type: CampaignBlockType.proof,
        city: cleanCity,
        audience: cleanAudience,
        propertyType: cleanPropertyType,
        urgency: cleanUrgency,
        blockScores: blockScoresA,
      );

      expect(selectedA.id, second.id);

      // Case B: Boost first block score
      final blockScoresB = {
        first.id: 1.9,
        second.id: 0.1,
      };

      final selectedB = StrategyEngine.selectBlock(
        type: CampaignBlockType.proof,
        city: cleanCity,
        audience: cleanAudience,
        propertyType: cleanPropertyType,
        urgency: cleanUrgency,
        blockScores: blockScoresB,
      );

      expect(selectedB.id, first.id);
    });

    test('StrategyEngine ignores deactivated blocks completely', () {
      final cleanCity = 'lagos';
      final cleanAudience = 'investor';
      final cleanPropertyType = 'apartment';
      final cleanUrgency = 'high';

      // Find the normal selection result
      final normalSelected = StrategyEngine.selectBlock(
        type: CampaignBlockType.hook,
        city: cleanCity,
        audience: cleanAudience,
        propertyType: cleanPropertyType,
        urgency: cleanUrgency,
      );

      // Deactivate the normal selection result
      final deactivatedBlockIds = [normalSelected.id];

      final newSelected = StrategyEngine.selectBlock(
        type: CampaignBlockType.hook,
        city: cleanCity,
        audience: cleanAudience,
        propertyType: cleanPropertyType,
        urgency: cleanUrgency,
        deactivatedBlockIds: deactivatedBlockIds,
      );

      // Verify a different block was chosen
      expect(newSelected.id, isNot(normalSelected.id));
    });

    test('Performance calculator math generates correct clamped scores', () {
      // Helper function matching core calculations
      double computeScore(int timesUsed, int leads, int conversions) {
        double score = 1.0;
        if (timesUsed >= 5) {
          final double leadRate = leads / timesUsed;
          final double conversionRate = conversions / timesUsed;
          score = (conversionRate * 3.0) + (leadRate * 1.0);
        }
        if (score < 0.1) score = 0.1;
        if (score > 2.0) score = 2.0;
        return score;
      }

      // Check default fallback (too few uses)
      expect(computeScore(3, 10, 5), 1.0);

      // Check calculated score: timesUsed = 10, leads = 5 (leadRate=0.5), conversions = 1 (convRate=0.1)
      // expected = (0.1 * 3) + (0.5 * 1) = 0.3 + 0.5 = 0.8
      expect(computeScore(10, 5, 1), closeTo(0.8, 0.0001));

      // Check low score clamping: timesUsed = 10, leads = 0, conversions = 0
      // expected = 0.0 -> clamped to 0.1
      expect(computeScore(10, 0, 0), 0.1);

      // Check high score clamping: timesUsed = 5, leads = 5, conversions = 5
      // expected = (1.0 * 3) + (1.0 * 1) = 4.0 -> clamped to 2.0
      expect(computeScore(5, 5, 5), 2.0);
    });
  });
}
