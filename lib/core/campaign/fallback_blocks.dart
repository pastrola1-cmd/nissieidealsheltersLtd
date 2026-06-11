import 'block_types.dart';

class FallbackBlocks {
  static const CampaignBlock hook = CampaignBlock(
    id: 'fallback_hook',
    type: CampaignBlockType.hook,
    template: '🏡 Looking for a perfect real estate opportunity in Nigeria? Check out this listing.',
    applicableCities: ['all'],
    applicableAudiences: ['all'],
    applicablePropertyTypes: ['all'],
  );

  static const CampaignBlock value = CampaignBlock(
    id: 'fallback_val',
    type: CampaignBlockType.value,
    template: '✨ Features prime location advantages, quality construction, secure environment, and long-term value.',
    applicableCities: ['all'],
    applicableAudiences: ['all'],
    applicablePropertyTypes: ['all'],
  );

  static const CampaignBlock proof = CampaignBlock(
    id: 'fallback_proof',
    type: CampaignBlockType.proof,
    template: '✅ Fully documented and verified property with immediate milestone allocation options.',
    applicableCities: ['all'],
    applicableAudiences: ['all'],
    applicablePropertyTypes: ['all'],
  );

  static const CampaignBlock cta = CampaignBlock(
    id: 'fallback_cta',
    type: CampaignBlockType.cta,
    template: '📞 Contact us today via Call or WhatsApp to request details or book a site tour.',
    applicableCities: ['all'],
    applicableAudiences: ['all'],
    applicablePropertyTypes: ['all'],
  );
}
