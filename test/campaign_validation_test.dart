import 'package:flutter_test/flutter_test.dart';
import 'package:ppn/core/intelligence/intelligence.dart';

void main() {
  group('Campaign Validation & Output Formatting Tests', () {
    final input = const CampaignInput(
      propertyType: 'Terrace',
      city: 'Lagos',
      price: 85000000.0,
      audience: 'Family',
      urgency: 'medium',
      neighborhood: 'Chevron',
      unitsRemaining: 2,
    );

    test('Validation detects fully valid campaign and returns isValid = true', () {
      final output = CampaignAssembler.generate(input);
      final result = ValidationEngine.validate(output, input);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
      expect(result.fixedOutput, isNull);
    });

    test('Validation catches empty blocks and auto-fixes them with fallbacks', () {
      final emptyBlock = const CampaignBlock(
        id: 'empty',
        type: CampaignBlockType.hook,
        template: '',
        applicableCities: ['all'],
        applicableAudiences: ['all'],
        applicablePropertyTypes: ['all'],
      );

      final output = CampaignOutput(
        hookBlock: emptyBlock, // hook is empty
        valueBlock: const CampaignBlock(id: 'val', type: CampaignBlockType.value, template: 'Value copy', applicableCities: ['all'], applicableAudiences: ['all'], applicablePropertyTypes: ['all']),
        proofBlock: const CampaignBlock(id: 'proof', type: CampaignBlockType.proof, template: 'Proof copy', applicableCities: ['all'], applicableAudiences: ['all'], applicablePropertyTypes: ['all']),
        ctaBlock: const CampaignBlock(id: 'cta', type: CampaignBlockType.cta, template: 'CTA copy', applicableCities: ['all'], applicableAudiences: ['all'], applicablePropertyTypes: ['all']),
        assembledText: '\n\nValue copy\n\nProof copy\n\nCTA copy',
        metadata: {},
      );

      final result = ValidationEngine.validate(output, input);

      expect(result.isValid, false);
      expect(result.errors, contains('Hook block is empty'));
      expect(result.fixedOutput, isNotNull);
      expect(result.fixedOutput!.hookBlock.id, 'fallback_hook');
      expect(result.fixedOutput!.assembledText, contains(FallbackBlocks.hook.template));
    });

    test('Validation detects and strips unresolved placeholders', () {
      final badOutput = CampaignOutput(
        hookBlock: const CampaignBlock(id: 'hook', type: CampaignBlockType.hook, template: 'Template with {missing_var}', applicableCities: ['all'], applicableAudiences: ['all'], applicablePropertyTypes: ['all']),
        valueBlock: const CampaignBlock(id: 'val', type: CampaignBlockType.value, template: 'Value copy', applicableCities: ['all'], applicableAudiences: ['all'], applicablePropertyTypes: ['all']),
        proofBlock: const CampaignBlock(id: 'proof', type: CampaignBlockType.proof, template: 'Proof copy', applicableCities: ['all'], applicableAudiences: ['all'], applicablePropertyTypes: ['all']),
        ctaBlock: const CampaignBlock(id: 'cta', type: CampaignBlockType.cta, template: 'CTA copy', applicableCities: ['all'], applicableAudiences: ['all'], applicablePropertyTypes: ['all']),
        assembledText: 'Template with {missing_var}\n\nValue copy\n\nProof copy\n\nCTA copy',
        metadata: {},
      );

      final result = ValidationEngine.validate(badOutput, input);

      expect(result.isValid, false);
      expect(result.errors, contains('Unresolved placeholders found in assembled text'));
      expect(result.fixedOutput, isNotNull);
      expect(result.fixedOutput!.assembledText, isNot(contains('{missing_var}')));
      expect(result.fixedOutput!.assembledText, contains('Template with'));
    });

    test('PlatformFormatter formats for Facebook, Instagram, WhatsApp, and LinkedIn with correct limits', () {
      final output = CampaignAssembler.generate(input);

      // Facebook
      final fb = PlatformFormatter.format(output, MarketingPlatform.facebook, input);
      expect(fb.platform, 'facebook');
      expect(fb.formattedText, contains('DISCOVER IN LAGOS'));
      expect(fb.withinLimit, true);

      // Instagram
      final ig = PlatformFormatter.format(output, MarketingPlatform.instagram, input);
      expect(ig.platform, 'instagram');
      expect(ig.formattedText, contains('#NigeriaRealEstate'));
      expect(ig.characterCount, lessThanOrEqualTo(500));
      expect(ig.withinLimit, true);

      // WhatsApp
      final wa = PlatformFormatter.format(output, MarketingPlatform.whatsapp, input, linkUrl: 'https://example.com/prop1');
      expect(wa.platform, 'whatsapp');
      expect(wa.formattedText, contains('Hello! Quick update:'));
      expect(wa.formattedText, contains('https://example.com/prop1'));
      expect(wa.characterCount, lessThanOrEqualTo(300));
      expect(wa.withinLimit, true);

      // LinkedIn
      final li = PlatformFormatter.format(output, MarketingPlatform.linkedin, input);
      expect(li.platform, 'linkedin');
      expect(li.formattedText, contains('MARKET INTEL: Terrace opportunities in Lagos.'));
      expect(li.characterCount, lessThanOrEqualTo(1000));
      expect(li.withinLimit, true);
    });

    test('PlatformFormatter truncates correctly on extreme overflow', () {
      final superLongBlock = CampaignBlock(
        id: 'super_long',
        type: CampaignBlockType.hook,
        template: 'A' * 600,
        applicableCities: const ['all'],
        applicableAudiences: const ['all'],
        applicablePropertyTypes: const ['all'],
      );

      final output = CampaignOutput(
        hookBlock: superLongBlock,
        valueBlock: FallbackBlocks.value,
        proofBlock: FallbackBlocks.proof,
        ctaBlock: FallbackBlocks.cta,
        assembledText: 'A' * 600,
        metadata: const {},
      );

      final ig = PlatformFormatter.format(output, MarketingPlatform.instagram, input);
      expect(ig.formattedText.length, lessThanOrEqualTo(500));
      expect(ig.formattedText.endsWith('...'), true);
    });
  });
}
