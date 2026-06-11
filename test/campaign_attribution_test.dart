import 'package:flutter_test/flutter_test.dart';
import 'package:ppn/core/campaign/platform_formatter.dart';
import 'package:ppn/core/campaign/block_types.dart';
import 'package:ppn/core/campaign/campaign_assembler.dart';
import 'package:ppn/models/models.dart';

void main() {
  group('Campaign Tracking & Attribution Tests', () {
    test('Campaign model converts from/to JSON successfully with tracking fields', () {
      final json = {
        'id': 'campaign_123',
        'company_id': 'company_abc',
        'property_id': 'property_xyz',
        'created_by': 'user_789',
        'input_data': <String, dynamic>{'city': 'lagos'},
        'output_data': <String, dynamic>{'text': 'Some formatted copy'},
        'platform': 'facebook',
        'created_at': '2026-06-11T12:00:00.000Z',
        'share_count': 15,
        'lead_count': 4,
        'conversion_count': 2,
      };

      final campaign = Campaign.fromJson(json);

      expect(campaign.id, 'campaign_123');
      expect(campaign.companyId, 'company_abc');
      expect(campaign.propertyId, 'property_xyz');
      expect(campaign.createdBy, 'user_789');
      expect(campaign.inputData['city'], 'lagos');
      expect(campaign.outputData['text'], 'Some formatted copy');
      expect(campaign.platform, 'facebook');
      expect(campaign.createdAt.year, 2026);
      expect(campaign.shareCount, 15);
      expect(campaign.leadCount, 4);
      expect(campaign.conversionCount, 2);

      final outJson = campaign.toJson();
      expect(outJson['id'], 'campaign_123');
      expect(outJson['share_count'], 15);
      expect(outJson['lead_count'], 4);
      expect(outJson['conversion_count'], 2);
    });

    test('Campaign model handles fallback values for missing tracking fields', () {
      final json = {
        'id': 'campaign_123',
        'company_id': 'company_abc',
        'input_data': <String, dynamic>{},
        'output_data': <String, dynamic>{},
        'platform': 'facebook',
        'created_at': '2026-06-11T12:00:00.000Z',
      };

      final campaign = Campaign.fromJson(json);

      expect(campaign.shareCount, 0);
      expect(campaign.leadCount, 0);
      expect(campaign.conversionCount, 0);
    });

    test('Lead model converts from/to JSON successfully with campaignId', () {
      final json = {
        'id': 'lead_123',
        'company_id': 'company_abc',
        'buyer_name': 'Adebayo Johnson',
        'buyer_phone': '+2348011112222',
        'source_channel': 'whatsapp',
        'stage': 'new',
        'campaign_id': 'campaign_999',
        'created_at': '2026-06-11T12:00:00.000Z',
        'updated_at': '2026-06-11T12:00:00.000Z',
      };

      final lead = Lead.fromJson(json);

      expect(lead.id, 'lead_123');
      expect(lead.buyerName, 'Adebayo Johnson');
      expect(lead.campaignId, 'campaign_999');

      final outJson = lead.toJson();
      expect(outJson['id'], 'lead_123');
      expect(outJson['campaign_id'], 'campaign_999');
    });

    test('PlatformFormatter appends link containing campaign ID correctly', () {
      final hookBlock = CampaignBlock(
        id: 'h1',
        type: CampaignBlockType.hook,
        template: 'Check this out!',
        applicableCities: const ['all'],
        applicableAudiences: const ['all'],
        applicablePropertyTypes: const ['all'],
      );
      final valueBlock = CampaignBlock(
        id: 'v1',
        type: CampaignBlockType.value,
        template: 'High ROI property',
        applicableCities: const ['all'],
        applicableAudiences: const ['all'],
        applicablePropertyTypes: const ['all'],
      );
      final proofBlock = CampaignBlock(
        id: 'p1',
        type: CampaignBlockType.proof,
        template: 'Verified C of O',
        applicableCities: const ['all'],
        applicableAudiences: const ['all'],
        applicablePropertyTypes: const ['all'],
      );
      final ctaBlock = CampaignBlock(
        id: 'c1',
        type: CampaignBlockType.cta,
        template: 'DM us now',
        applicableCities: const ['all'],
        applicableAudiences: const ['all'],
        applicablePropertyTypes: const ['all'],
      );

      final output = CampaignOutput(
        hookBlock: hookBlock,
        valueBlock: valueBlock,
        proofBlock: proofBlock,
        ctaBlock: ctaBlock,
        assembledText: 'Check this out!\nHigh ROI property\nVerified C of O\nDM us now',
        metadata: const {},
      );

      final input = CampaignInput(
        propertyType: 'apartment',
        city: 'lagos',
        price: 50000000.0,
        audience: 'investor',
        urgency: 'medium',
        features: const ['Gym'],
      );

      final linkUrl = 'https://scalewealth.com/properties/prop_123?ref=AGENT123&camp=CAMP777';

      // Check Facebook
      final formattedFb = PlatformFormatter.format(
        output,
        MarketingPlatform.facebook,
        input,
        linkUrl: linkUrl,
      );
      expect(formattedFb.formattedText, contains('More details: $linkUrl'));

      // Check Instagram
      final formattedIg = PlatformFormatter.format(
        output,
        MarketingPlatform.instagram,
        input,
        linkUrl: linkUrl,
      );
      expect(formattedIg.formattedText, contains('Link: $linkUrl'));

      // Check WhatsApp
      final formattedWa = PlatformFormatter.format(
        output,
        MarketingPlatform.whatsapp,
        input,
        linkUrl: linkUrl,
      );
      expect(formattedWa.formattedText, contains('View details here: $linkUrl'));

      // Check LinkedIn
      final formattedLi = PlatformFormatter.format(
        output,
        MarketingPlatform.linkedin,
        input,
        linkUrl: linkUrl,
      );
      expect(formattedLi.formattedText, contains('Learn more: $linkUrl'));
    });
  });
}
