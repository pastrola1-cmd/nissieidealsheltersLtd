import 'package:flutter_test/flutter_test.dart';
import 'package:nissie_ideal_shelters/core/intelligence/intelligence.dart';

void main() {
  group('Campaign Block System & Strategy Engine Tests', () {
    test('Selects exact city, audience, and type matches correctly', () {
      final block = StrategyEngine.selectBlock(
        type: CampaignBlockType.hook,
        city: 'Lagos',
        audience: 'Investor',
        propertyType: 'Apartment',
        urgency: 'high',
      );

      expect(block.id, 'hook_lagos_investor_fomo');
      expect(block.applicableCities, contains('lagos'));
      expect(block.applicableAudiences, contains('investor'));
      expect(block.urgencyLevel, 'high');
    });

    test('Selects exact audience matches across cities using all-city blocks', () {
      final block = StrategyEngine.selectBlock(
        type: CampaignBlockType.hook,
        city: 'Abuja',
        audience: 'Family',
        propertyType: 'Terrace',
        urgency: 'medium',
      );

      expect(block.id, 'hook_abuja_family_prestige');
      expect(block.applicableCities, contains('abuja'));
      expect(block.applicableAudiences, contains('family'));
    });

    test('Falls back to "all" matches when exact parameter has no custom block', () {
      final block = StrategyEngine.selectBlock(
        type: CampaignBlockType.hook,
        city: 'Kano',
        audience: 'Diaspora',
        propertyType: 'Detached',
        urgency: 'low',
      );

      expect(block.id, 'hook_diaspora_trust');
      expect(block.applicableCities, contains('all'));
      expect(block.applicableAudiences, contains('diaspora'));
    });

    test('StrategyEngine returns safety default fallback on complete mismatch', () {
      final block = StrategyEngine.selectBlock(
        type: CampaignBlockType.hook,
        city: 'Enugu',
        audience: 'Unknown',
        propertyType: 'Office',
        urgency: 'low',
      );

      expect(block.id, 'hook_nigeria_default');
    });

    test('CampaignAssembler generates campaign with 4 valid blocks', () {
      final input = CampaignInput(
        propertyType: 'Duplex',
        city: 'Lagos',
        price: 180000000.0,
        audience: 'Investor',
        urgency: 'high',
        neighborhood: 'Lekki Phase 1',
        unitsRemaining: 4,
      );

      final campaign = CampaignAssembler.generate(input);

      expect(campaign.hookBlock.id, 'hook_lagos_investor_fomo');
      expect(campaign.valueBlock.id, 'val_roi_appreciation');
      expect(campaign.proofBlock.id, 'proof_lagos_occupancy');
      expect(campaign.ctaBlock.id, 'cta_investor_urgency');

      // Verify placeholder replacements
      expect(campaign.assembledText, contains('Lagos'));
      expect(campaign.assembledText, contains('Duplex'));
      expect(campaign.assembledText, contains('Lekki Phase 1'));
      expect(campaign.assembledText, contains('4'));
      expect(campaign.assembledText, contains('₦180.0M')); // formatted price
      expect(campaign.assembledText, isNot(contains('{city}')));
      expect(campaign.assembledText, isNot(contains('{property_type}')));
      expect(campaign.assembledText, isNot(contains('{neighborhood}')));
      expect(campaign.assembledText, isNot(contains('{units_remaining}')));
    });

    test('CampaignAssembler handles large currency billions formatting correctly', () {
      final input = CampaignInput(
        propertyType: 'Penthouse',
        city: 'Abuja',
        price: 1250000000.0, // 1.25 Billion
        audience: 'Luxury',
        urgency: 'medium',
        neighborhood: 'Maitama',
      );

      final campaign = CampaignAssembler.generate(input);
      expect(campaign.assembledText, contains('₦1.3B')); // formatted to B
    });
  });
}
