import 'block_types.dart';
import 'block_library.dart';

class StrategyEngine {
  static CampaignBlock selectBlock({
    required CampaignBlockType type,
    required String city,
    required String audience,
    required String propertyType,
    required String urgency,
    bool shuffle = false,
    Map<String, double>? blockScores,
    List<String>? deactivatedBlockIds,
  }) {
    final cleanCity = city.toLowerCase().trim();
    final cleanAudience = audience.toLowerCase().trim();
    final cleanPropertyType = propertyType.toLowerCase().trim();
    final cleanUrgency = urgency.toLowerCase().trim();

    // 1. Filter blocks by type and active status
    final allOfType = BlockLibrary.blocks.where((b) {
      if (deactivatedBlockIds != null && deactivatedBlockIds.contains(b.id)) {
        return false;
      }
      return b.type == type;
    }).toList();

    // 2. Filter candidates: each category must match the clean parameter OR 'all'
    final candidates = allOfType.where((b) {
      final cityMatch = b.applicableCities.contains(cleanCity) || b.applicableCities.contains('all');
      final audienceMatch = b.applicableAudiences.contains(cleanAudience) || b.applicableAudiences.contains('all');
      final propMatch = b.applicablePropertyTypes.contains(cleanPropertyType) || b.applicablePropertyTypes.contains('all');
      final urgencyMatch = b.urgencyLevel == cleanUrgency || b.urgencyLevel == 'all';
      return cityMatch && audienceMatch && propMatch && urgencyMatch;
    }).toList();

    // 3. Score candidates to prioritize exact matches over 'all' fallbacks
    final scoredCandidates = candidates.map((b) {
      int score = 0;
      if (b.applicableCities.contains(cleanCity)) score += 10;
      if (b.applicableAudiences.contains(cleanAudience)) score += 10;
      if (b.applicablePropertyTypes.contains(cleanPropertyType)) score += 10;
      if (b.urgencyLevel == cleanUrgency) score += 5;
      return _ScoredBlock(b, score);
    }).toList();

    // 4. Sort by score desc, then by performanceScore desc
    scoredCandidates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      
      final double scoreA = blockScores?[a.block.id] ?? a.block.performanceScore;
      final double scoreB = blockScores?[b.block.id] ?? b.block.performanceScore;
      return scoreB.compareTo(scoreA);
    });

    if (scoredCandidates.isNotEmpty) {
      if (shuffle && scoredCandidates.length > 1) {
        // Pick randomly from candidates that share the highest score
        final highestScore = scoredCandidates.first.score;
        final topTies = scoredCandidates.where((sc) => sc.score == highestScore).toList();
        final randomIndex = DateTime.now().millisecond % topTies.length;
        return topTies[randomIndex].block;
      }
      return scoredCandidates.first.block;
    }

    // 5. Safety fallback lookup
    return BlockLibrary.blocks.firstWhere(
      (b) => b.type == type && b.id.contains('default'),
      orElse: () => BlockLibrary.blocks.firstWhere((b) => b.type == type),
    );
  }
}

class _ScoredBlock {
  final CampaignBlock block;
  final int score;
  _ScoredBlock(this.block, this.score);
}
