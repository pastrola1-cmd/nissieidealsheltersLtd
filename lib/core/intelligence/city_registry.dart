class CityIntelligence {
  final String id;
  final String name;
  final String state;
  final String marketPressure;
  final List<String> hookAngles;
  final List<String> valueAngles;
  final List<String> proofAngles;
  final List<String> ctaStyles;
  final List<String> neighborhoods;
  final String fallbackModel;

  const CityIntelligence({
    required this.id,
    required this.name,
    required this.state,
    required this.marketPressure,
    required this.hookAngles,
    required this.valueAngles,
    required this.proofAngles,
    required this.ctaStyles,
    required this.neighborhoods,
    this.fallbackModel = 'nigeria_default',
  });
}

class CityRegistry {
  static const _fallback = CityIntelligence(
    id: 'nigeria_default',
    name: 'Nigeria',
    state: 'Federal',
    marketPressure: 'value-first',
    hookAngles: ['Affordability', 'Smart choice', 'Secure investment'],
    valueAngles: ['General appreciation', 'Reliable developer', 'Peace of mind'],
    proofAngles: ['Verified title', 'Registered surveyor', 'Trusted developer'],
    ctaStyles: ['Educational-driven', 'Friendly-guided'],
    neighborhoods: ['Default Development'],
  );

  static final Map<String, CityIntelligence> _registry = {
    'lagos': const CityIntelligence(
      id: 'lagos',
      name: 'Lagos',
      state: 'Lagos State',
      marketPressure: 'scarcity + ROI pressure',
      hookAngles: ['FOMO', 'Scarcity', 'Before price increase', 'Lekki Corridor Access'],
      valueAngles: ['Appreciation rate', 'Rental yield', 'Location prestige', 'Instant Equity'],
      proofAngles: ['Sold out in 2 weeks', '94% occupancy rate', 'Fast-paced construction progress'],
      ctaStyles: ['Urgency-driven', 'Scarcity-driven'],
      neighborhoods: ['Lekki', 'Ikoyi', 'Victoria Island', 'Ibeju-Lekki', 'Chevron', 'Ketu-Epe'],
    ),
    'abuja': const CityIntelligence(
      id: 'abuja',
      name: 'Abuja',
      state: 'FCT',
      marketPressure: 'security + lifestyle prestige',
      hookAngles: ['Security', 'Prestige', 'Government area', 'Elite living'],
      valueAngles: ['Gated estate', 'Proximity to power', 'Diplomatic safety', 'Premium finishes'],
      proofAngles: ['High profile neighbors', 'Diplomatic zone certificate', 'Completed infrastructures'],
      ctaStyles: ['Prestige-driven', 'Warm lifestyle invitation'],
      neighborhoods: ['Maitama', 'Asokoro', 'Wuse', 'Gwarinpa', 'Guzape', 'Jabi'],
    ),
    'port_harcourt': const CityIntelligence(
      id: 'port_harcourt',
      name: 'Port Harcourt',
      state: 'Rivers State',
      marketPressure: 'cashflow + business opportunity',
      hookAngles: ['Cashflow', 'Business hub', 'Oil & Gas corridor', 'High Yields'],
      valueAngles: ['Rental income', 'Commercial potential', 'High liquidity', 'Industrial proximity'],
      proofAngles: ['High occupancy rates', 'Corporate leases guaranteed', 'Immediate cash generation'],
      ctaStyles: ['Cashflow-focused', 'Direct action'],
      neighborhoods: ['GRA Phase 1', 'GRA Phase 2', 'Peter Odili Road', 'Ada George', 'Trans-Amadi'],
    ),
  };

  static CityIntelligence get(String cityId) {
    return _registry[cityId.toLowerCase().trim()] ?? _fallback;
  }

  static CityIntelligence getFallback() => _fallback;

  static List<CityIntelligence> getAll() => _registry.values.toList();
}
