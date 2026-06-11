import 'campaign_assembler.dart';

enum MarketingPlatform { facebook, instagram, whatsapp, linkedin }

class FormattedCampaign {
  final String platform;
  final String formattedText;
  final int characterCount;
  final bool withinLimit;

  const FormattedCampaign({
    required this.platform,
    required this.formattedText,
    required this.characterCount,
    required this.withinLimit,
  });
}

class PlatformFormatter {
  static FormattedCampaign format(
    CampaignOutput output,
    MarketingPlatform platform,
    CampaignInput input, {
    String? linkUrl,
  }) {
    String text = '';
    int maxLength = 2000;

    final hook = CampaignAssembler.replacePlaceholders(output.hookBlock.template, input);
    final value = CampaignAssembler.replacePlaceholders(output.valueBlock.template, input);
    final proof = CampaignAssembler.replacePlaceholders(output.proofBlock.template, input);
    final cta = CampaignAssembler.replacePlaceholders(output.ctaBlock.template, input);

    switch (platform) {
      case MarketingPlatform.facebook:
        maxLength = 2000;
        text = '✨ DISCOVER IN ${input.city.toUpperCase()} ✨\n\n'
               '$hook\n\n'
               '🔑 key features & details:\n'
               '• $value\n\n'
               '🛡️ security & process:\n'
               '• $proof\n\n'
               '👉 NEXT STEPS:\n'
               '$cta';
        if (linkUrl != null) {
          text += '\n\nMore details: $linkUrl';
        }
        break;

      case MarketingPlatform.instagram:
        maxLength = 500;
        text = '$hook\n\n'
               '• $value\n'
               '• $proof\n\n'
               '$cta';
        if (linkUrl != null) {
          text += '\n\nLink: $linkUrl';
        }
        text += '\n\n#NigeriaRealEstate #LekkiHomes #PropertyInvestment #LagosProperty #AbujaHomes';
        break;

      case MarketingPlatform.whatsapp:
        maxLength = 300;
        text = 'Hello! Quick update:\n'
               '$hook\n\n'
               '$cta';
        if (linkUrl != null) {
          text += '\nView details here: $linkUrl';
        }
        break;

      case MarketingPlatform.linkedin:
        maxLength = 1000;
        text = '🏢 MARKET INTEL: ${input.propertyType} opportunities in ${input.city}.\n\n'
               '$hook\n\n'
               'Our latest analysis shows strong fundamentals:\n'
               '📈 Value Proposition: $value\n'
               '📊 Proof of Delivery: $proof\n\n'
               'Secure your allocation:\n'
               '➡️ $cta';
        if (linkUrl != null) {
          text += '\n\nLearn more: $linkUrl';
        }
        break;
    }

    text = _enforceTruncation(text, maxLength);

    return FormattedCampaign(
      platform: platform.name,
      formattedText: text,
      characterCount: text.length,
      withinLimit: text.length <= maxLength,
    );
  }

  static String _enforceTruncation(String text, int limit) {
    if (text.length <= limit) return text;
    final sub = text.substring(0, limit - 4);
    final lastSpace = sub.lastIndexOf(' ');
    if (lastSpace > limit / 2) {
      return '${sub.substring(0, lastSpace)}...';
    }
    return '$sub...';
  }
}
