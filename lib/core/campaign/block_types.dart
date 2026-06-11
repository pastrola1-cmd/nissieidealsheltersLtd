enum CampaignBlockType { hook, value, proof, cta }

class CampaignBlock {
  final String id;
  final CampaignBlockType type;
  final String template;
  final List<String> applicableCities;        // e.g., ['lagos', 'all']
  final List<String> applicableAudiences;     // e.g., ['investor', 'all']
  final List<String> applicablePropertyTypes; // e.g., ['apartment', 'all']
  final String urgencyLevel;                  // 'low', 'medium', 'high', or 'all'
  final double performanceScore;              // defaults to 1.0

  const CampaignBlock({
    required this.id,
    required this.type,
    required this.template,
    required this.applicableCities,
    required this.applicableAudiences,
    required this.applicablePropertyTypes,
    this.urgencyLevel = 'all',
    this.performanceScore = 1.0,
  });
}
