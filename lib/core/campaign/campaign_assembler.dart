import 'block_types.dart';
import 'strategy_engine.dart';

class CampaignInput {
  final String propertyType;
  final String city;
  final double price;
  final String audience;
  final String urgency;
  final List<String> features;
  final String? neighborhood;
  final int? unitsRemaining;

  const CampaignInput({
    required this.propertyType,
    required this.city,
    required this.price,
    required this.audience,
    required this.urgency,
    this.features = const [],
    this.neighborhood,
    this.unitsRemaining,
  });
}

class CampaignOutput {
  final CampaignBlock hookBlock;
  final CampaignBlock valueBlock;
  final CampaignBlock proofBlock;
  final CampaignBlock ctaBlock;
  final String assembledText;
  final Map<String, String> metadata;

  const CampaignOutput({
    required this.hookBlock,
    required this.valueBlock,
    required this.proofBlock,
    required this.ctaBlock,
    required this.assembledText,
    required this.metadata,
  });
}

class CampaignAssembler {
  static CampaignOutput generate(
    CampaignInput input, {
    bool shuffle = false,
    Map<String, double>? blockScores,
    List<String>? deactivatedBlockIds,
  }) {
    final hook = StrategyEngine.selectBlock(
      type: CampaignBlockType.hook,
      city: input.city,
      audience: input.audience,
      propertyType: input.propertyType,
      urgency: input.urgency,
      shuffle: shuffle,
      blockScores: blockScores,
      deactivatedBlockIds: deactivatedBlockIds,
    );

    final value = StrategyEngine.selectBlock(
      type: CampaignBlockType.value,
      city: input.city,
      audience: input.audience,
      propertyType: input.propertyType,
      urgency: input.urgency,
      shuffle: shuffle,
      blockScores: blockScores,
      deactivatedBlockIds: deactivatedBlockIds,
    );

    final proof = StrategyEngine.selectBlock(
      type: CampaignBlockType.proof,
      city: input.city,
      audience: input.audience,
      propertyType: input.propertyType,
      urgency: input.urgency,
      shuffle: shuffle,
      blockScores: blockScores,
      deactivatedBlockIds: deactivatedBlockIds,
    );

    final cta = StrategyEngine.selectBlock(
      type: CampaignBlockType.cta,
      city: input.city,
      audience: input.audience,
      propertyType: input.propertyType,
      urgency: input.urgency,
      shuffle: shuffle,
      blockScores: blockScores,
      deactivatedBlockIds: deactivatedBlockIds,
    );


    final String rawText = '${hook.template}\n\n${value.template}\n\n${proof.template}\n\n${cta.template}';
    final assembled = replacePlaceholders(rawText, input);

    return CampaignOutput(
      hookBlock: hook,
      valueBlock: value,
      proofBlock: proof,
      ctaBlock: cta,
      assembledText: assembled,
      metadata: {
        'hook_id': hook.id,
        'value_id': value.id,
        'proof_id': proof.id,
        'cta_id': cta.id,
        'strategy': '${input.city}_${input.audience}_${input.urgency}',
        'city': input.city,
        'property_type': input.propertyType,
      },
    );
  }

  static String replacePlaceholders(String text, CampaignInput input) {
    final formattedPrice = _formatCurrency(input.price);
    
    final currentMonth = DateTime.now().month;
    final targetQuarter = ((currentMonth - 1) ~/ 3) + 2; 
    final quarterStr = targetQuarter > 4 ? '1' : targetQuarter.toString();

    return text
        .replaceAll('{property_type}', input.propertyType)
        .replaceAll('{city}', input.city)
        .replaceAll('{price}', formattedPrice)
        .replaceAll('{neighborhood}', input.neighborhood ?? 'Prime Location')
        .replaceAll('{units_remaining}', (input.unitsRemaining ?? 3).toString())
        .replaceAll('{quarter}', quarterStr);
  }

  static String _formatCurrency(double amount) {
    if (amount >= 1000000000) {
      return '₦${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    }
    return '₦${amount.toStringAsFixed(0)}';
  }
}
