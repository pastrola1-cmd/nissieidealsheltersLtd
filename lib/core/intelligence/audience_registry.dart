class AudienceProfile {
  final String id;
  final String label;
  final List<String> intentSignals;
  final String messagingAngle;
  final String ctaStyle;
  final List<String> triggerWords;

  const AudienceProfile({
    required this.id,
    required this.label,
    required this.intentSignals,
    required this.messagingAngle,
    required this.ctaStyle,
    required this.triggerWords,
  });
}

class AudienceRegistry {
  static final Map<String, AudienceProfile> _registry = {
    'investor': const AudienceProfile(
      id: 'investor',
      label: 'Investor',
      intentSignals: ['ROI focus', 'Portfolio growth', 'Rental yield', 'Arbitrage'],
      messagingAngle: 'Numbers-driven, ROI-first, appreciation projection',
      ctaStyle: 'Direct action with urgency',
      triggerWords: ['returns', 'appreciation', 'yield', 'ROI', 'capital gains', 'passive income'],
    ),
    'family': const AudienceProfile(
      id: 'family',
      label: 'Family Homebuyer',
      intentSignals: ['Safety', 'Comfort', 'Schools', 'Space', 'Community'],
      messagingAngle: 'Emotion-driven, safety, lifestyle, community benefits',
      ctaStyle: 'Warm invitation, "Book a family visit"',
      triggerWords: ['safe', 'quiet', 'schools', 'garden', 'playground', 'family', 'secured', 'community'],
    ),
    'diaspora': const AudienceProfile(
      id: 'diaspora',
      label: 'Diaspora Buyer',
      intentSignals: ['Trust', 'Documentation', 'Transparency', 'Remote management'],
      messagingAngle: 'Trust-building, verified titles, stress-free transaction, remote property management',
      ctaStyle: '"We handle everything", transparent remote viewing cta',
      triggerWords: ['verified', 'title', 'governor\'s consent', 'C of O', 'secure payment', 'remote progress', 'hassle-free'],
    ),
    'luxury': const AudienceProfile(
      id: 'luxury',
      label: 'Luxury Buyer',
      intentSignals: ['Exclusivity', 'Status', 'High-end amenities', 'Prestige'],
      messagingAngle: 'Exclusivity, status symbol, architectural mastery, premium finishes',
      ctaStyle: 'Private viewing, limited allocation request',
      triggerWords: ['bespoke', 'luxury', 'penthouse', 'premium', 'private', 'masterpiece', 'curated', 'exclusive'],
    ),
    'first_time': const AudienceProfile(
      id: 'first_time',
      label: 'First-time Buyer',
      intentSignals: ['Simplicity', 'Guidance', 'Affordability', 'Flexible payments'],
      messagingAngle: 'Supportive, educational, flexible entry options, step-by-step guidance',
      ctaStyle: 'Let us guide you, get starter guide',
      triggerWords: ['affordable', 'payment plan', 'flexible', 'starter home', 'guides', 'easy entry', 'co-own'],
    ),
  };

  static AudienceProfile? get(String audienceId) {
    return _registry[audienceId.toLowerCase().trim()];
  }

  static List<AudienceProfile> getAll() => _registry.values.toList();
}
