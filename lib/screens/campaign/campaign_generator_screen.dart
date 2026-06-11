import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/campaign/campaign_assembler.dart';
import 'package:ppn/core/campaign/validation_engine.dart';
import 'package:ppn/core/campaign/platform_formatter.dart';
import 'package:ppn/core/intelligence/audience_registry.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/providers/campaign_provider.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/providers/performance_provider.dart';

class CampaignGeneratorScreen extends ConsumerStatefulWidget {
  final String? propertyId;
  const CampaignGeneratorScreen({super.key, this.propertyId});

  @override
  ConsumerState<CampaignGeneratorScreen> createState() => _CampaignGeneratorScreenState();
}

class _CampaignGeneratorScreenState extends ConsumerState<CampaignGeneratorScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String? _selectedPropertyId;
  String? _selectedCity;
  String? _selectedAudience;
  String _urgencyLevel = 'medium';
  final _neighborhoodController = TextEditingController();
  final _unitsRemainingController = TextEditingController();
  final List<String> _selectedFeatures = [];

  bool _isGenerating = false;
  CampaignOutput? _generatedOutput;
  Map<MarketingPlatform, FormattedCampaign> _formattedCampaigns = {};
  TabController? _tabController;
  CampaignInput? _currentInput;
  final Map<MarketingPlatform, Campaign> _savedCampaigns = {};

  final List<String> _availableFeatures = [
    '24hr Security',
    'Swimming Pool',
    'Gym',
    'Gated Estate',
    'Uninterrupted Power',
    'Fully Furnished',
    'Water Treatment',
    'Ample Parking',
    'Boy\'s Quarter',
    'Smart Home Automations',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedPropertyId = widget.propertyId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedPropertyId != null) {
        _populateFieldsFromProperty(_selectedPropertyId!);
      }
    });
  }

  @override
  void dispose() {
    _neighborhoodController.dispose();
    _unitsRemainingController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _populateFieldsFromProperty(String propertyId) {
    final properties = ref.read(propertyProvider).properties;
    final property = properties.where((p) => p.id == propertyId).firstOrNull;

    if (property != null) {
      setState(() {
        _selectedPropertyId = propertyId;
        _selectedAudience = property.targetAudience;
        
        // Auto-detect city from location
        final location = property.location?.toLowerCase() ?? '';
        if (location.contains('lagos')) {
          _selectedCity = 'lagos';
        } else if (location.contains('abuja')) {
          _selectedCity = 'abuja';
        } else if (location.contains('port harcourt') || location.contains('ph')) {
          _selectedCity = 'port harcourt';
        } else {
          _selectedCity = 'nigeria_default';
        }

        // Extrapolate neighborhood if comma-separated
        if (property.location != null && property.location!.contains(',')) {
          _neighborhoodController.text = property.location!.split(',').first.trim();
        } else {
          _neighborhoodController.text = property.location ?? '';
        }

        // Extrapolate features from description
        _selectedFeatures.clear();
        final desc = property.description?.toLowerCase() ?? '';
        if (desc.contains('security') || desc.contains('cctv') || desc.contains('gate')) {
          _selectedFeatures.add('24hr Security');
        }
        if (desc.contains('pool') || desc.contains('swim')) {
          _selectedFeatures.add('Swimming Pool');
        }
        if (desc.contains('gym') || desc.contains('fitness')) {
          _selectedFeatures.add('Gym');
        }
        if (desc.contains('power') || desc.contains('generator') || desc.contains('light')) {
          _selectedFeatures.add('Uninterrupted Power');
        }
        if (desc.contains('parking') || desc.contains('car')) {
          _selectedFeatures.add('Ample Parking');
        }
      });
    }
  }

  Future<void> _handleGenerate({bool shuffle = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a property listing.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final properties = ref.read(propertyProvider).properties;
    final property = properties.firstWhere((p) => p.id == _selectedPropertyId);

    setState(() => _isGenerating = true);

    // Give a small visual feedback of generation
    await Future.delayed(const Duration(milliseconds: 600));

    final input = CampaignInput(
      propertyType: property.description?.toLowerCase().contains('land') == true ? 'land' : 'apartment',
      city: _selectedCity ?? 'nigeria_default',
      price: property.price,
      audience: _selectedAudience ?? 'all',
      urgency: _urgencyLevel,
      features: _selectedFeatures,
      neighborhood: _neighborhoodController.text.trim().isEmpty ? null : _neighborhoodController.text.trim(),
      unitsRemaining: int.tryParse(_unitsRemainingController.text),
    );

    final performanceState = ref.read(performanceProvider);
    final Map<String, double> blockScores = {
      for (final stat in performanceState.blockStats) stat.blockId: stat.performanceScore
    };
    final List<String> deactivatedBlockIds = performanceState.blockStats
        .where((s) => !s.isActive)
        .map((s) => s.blockId)
        .toList();

    // 1. Generate Raw Output
    final rawOutput = CampaignAssembler.generate(
      input,
      shuffle: shuffle,
      blockScores: blockScores,
      deactivatedBlockIds: deactivatedBlockIds,
    );

    // 2. Validate and Repair
    final validation = ValidationEngine.validate(rawOutput, input);
    final finalOutput = validation.isValid ? rawOutput : validation.fixedOutput!;

    // 3. Format across all 4 Platforms
    final formattedMap = <MarketingPlatform, FormattedCampaign>{};
    for (final platform in MarketingPlatform.values) {
      formattedMap[platform] = PlatformFormatter.format(
        finalOutput,
        platform,
        input,
        linkUrl: _buildReferralUrl(property),
      );
    }

    setState(() {
      _currentInput = input;
      _savedCampaigns.clear();
      _generatedOutput = finalOutput;
      _formattedCampaigns = formattedMap;
      _isGenerating = false;
    });
  }

  String _buildReferralUrl(Property property) {
    final profile = ref.read(authProvider).profile;
    final origin = kIsWeb ? Uri.base.origin : 'https://scalewealth.com';
    final refCode = profile?.referralCode ?? 'PPN-STAFF';
    return '$origin/properties/${property.id}?ref=$refCode';
  }

  Future<Campaign?> _getOrSaveCampaign(MarketingPlatform platform) async {
    if (_generatedOutput == null) return null;
    if (_savedCampaigns.containsKey(platform)) {
      return _savedCampaigns[platform];
    }

    final formatted = _formattedCampaigns[platform];
    if (formatted == null) return null;

    final campaign = await ref.read(campaignProvider.notifier).saveCampaign(
      propertyId: _selectedPropertyId,
      inputData: {
        'city': _selectedCity,
        'audience': _selectedAudience,
        'urgency': _urgencyLevel,
        'features': _selectedFeatures,
        'neighborhood': _neighborhoodController.text.trim(),
        'units_remaining': _unitsRemainingController.text.trim(),
      },
      outputData: {
        'hook_id': _generatedOutput!.hookBlock.id,
        'value_id': _generatedOutput!.valueBlock.id,
        'proof_id': _generatedOutput!.proofBlock.id,
        'cta_id': _generatedOutput!.ctaBlock.id,
        'hook': _generatedOutput!.hookBlock.template,
        'value': _generatedOutput!.valueBlock.template,
        'proof': _generatedOutput!.proofBlock.template,
        'cta': _generatedOutput!.ctaBlock.template,
        'text': formatted.formattedText,
      },
      platform: platform.name,
    );

    if (campaign != null) {
      _savedCampaigns[platform] = campaign;
      ref.read(performanceProvider.notifier).recalculateScores();
    }
    return campaign;
  }

  String _getFormattedTextForAction(MarketingPlatform platform, Campaign campaign) {
    if (_generatedOutput == null || _currentInput == null) return '';
    final properties = ref.read(propertyProvider).properties;
    final property = properties.firstWhere((p) => p.id == _selectedPropertyId);

    final baseReferralUrl = _buildReferralUrl(property);
    final trackingUrl = '$baseReferralUrl&camp=${campaign.id}';

    final updatedFormatted = PlatformFormatter.format(
      _generatedOutput!,
      platform,
      _currentInput!,
      linkUrl: trackingUrl,
    );

    setState(() {
      _formattedCampaigns[platform] = updatedFormatted;
    });

    return updatedFormatted.formattedText;
  }

  Future<void> _handleCopy(MarketingPlatform platform) async {
    if (_generatedOutput == null) return;

    final campaign = await _getOrSaveCampaign(platform);
    String textToCopy = '';

    if (campaign != null) {
      textToCopy = _getFormattedTextForAction(platform, campaign);
      try {
        await ref.read(supabaseServiceProvider).logCampaignShare(campaign.id, platform.name);
      } catch (e) {
        debugPrint('Failed to log campaign share: $e');
      }
    } else {
      textToCopy = _formattedCampaigns[platform]?.formattedText ?? '';
    }

    if (textToCopy.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${platform.name.toUpperCase()} copy copied to clipboard!${campaign != null ? " (Tracking link enabled)" : ""}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(MarketingPlatform platform) async {
    if (_generatedOutput == null) return;

    final campaign = await _getOrSaveCampaign(platform);
    String textToShare = '';

    if (campaign != null) {
      textToShare = _getFormattedTextForAction(platform, campaign);
      try {
        await ref.read(supabaseServiceProvider).logCampaignShare(campaign.id, platform.name);
      } catch (e) {
        debugPrint('Failed to log campaign share: $e');
      }
    } else {
      textToShare = _formattedCampaigns[platform]?.formattedText ?? '';
    }

    if (textToShare.isNotEmpty) {
      await Share.share(
        textToShare,
        subject: 'REOS Marketing Campaign',
      );
    }
  }

  Future<void> _saveCampaignToHistory(MarketingPlatform platform) async {
    if (_savedCampaigns.containsKey(platform)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${platform.name.toUpperCase()} campaign is already saved to history logs!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final campaign = await _getOrSaveCampaign(platform);
    if (mounted) {
      if (campaign != null) {
        _getFormattedTextForAction(platform, campaign);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${platform.name.toUpperCase()} campaign saved to history logs!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save campaign to database.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final properties = ref.watch(propertyProvider).properties;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Campaign Generator', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Nav to History
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Campaign Logs',
            onPressed: () {
              final role = ref.read(authProvider).profile?.role.value;
              context.push('/$role/campaigns');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // ── Form Card ──
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campaign Configurations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Select Property Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedPropertyId,
                        decoration: _inputDecoration(label: 'Select Property *', icon: Icons.home_work_outlined),
                        items: properties.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.title} (₦${_formatPrice(p.price)})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        validator: (val) => val == null ? 'Property is required' : null,
                        onChanged: (val) {
                          if (val != null) {
                            _populateFieldsFromProperty(val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // City Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: _inputDecoration(label: 'Target City *', icon: Icons.location_city_outlined),
                        items: const [
                          DropdownMenuItem(value: 'lagos', child: Text('Lagos (FOMO/Scarcity)')),
                          DropdownMenuItem(value: 'abuja', child: Text('Abuja (Security/Prestige)')),
                          DropdownMenuItem(value: 'port harcourt', child: Text('Port Harcourt (ROI/Cashflow)')),
                          DropdownMenuItem(value: 'nigeria_default', child: Text('Nigeria (General Fallback)')),
                        ],
                        validator: (val) => val == null ? 'City is required' : null,
                        onChanged: (val) => setState(() => _selectedCity = val),
                      ),
                      const SizedBox(height: 16),

                      // Target Audience Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedAudience,
                        decoration: _inputDecoration(label: 'Target Audience *', icon: Icons.track_changes_outlined),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('General Audience')),
                          ...AudienceRegistry.getAll().map((profile) {
                            return DropdownMenuItem(
                              value: profile.id,
                              child: Text(profile.label),
                            );
                          }),
                        ],
                        validator: (val) => val == null ? 'Audience is required' : null,
                        onChanged: (val) => setState(() => _selectedAudience = val),
                      ),
                      const SizedBox(height: 16),

                      // Neighborhood
                      TextFormField(
                        controller: _neighborhoodController,
                        decoration: _inputDecoration(label: 'Neighborhood (e.g. Lekki Phase 1)', icon: Icons.map_outlined),
                      ),
                      const SizedBox(height: 16),

                      // Units Remaining
                      TextFormField(
                        controller: _unitsRemainingController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _inputDecoration(label: 'Units Remaining (optional)', icon: Icons.numbers_outlined),
                      ),
                      const SizedBox(height: 16),

                      // Urgency Selector
                      const Text(
                        'Urgency Pressure Angle',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['low', 'medium', 'high'].map((urg) {
                          final isSelected = _urgencyLevel == urg;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(urg.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? Colors.white : AppColors.textSecondary)),
                                selected: isSelected,
                                selectedColor: AppColors.accent,
                                backgroundColor: AppColors.background,
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onSelected: (val) {
                                  if (val) setState(() => _urgencyLevel = urg);
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Features chips
                      const Text(
                        'Include Listing Features',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableFeatures.map((feature) {
                          final isSelected = _selectedFeatures.contains(feature);
                          return FilterChip(
                            label: Text(feature, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedFeatures.add(feature);
                                } else {
                                  _selectedFeatures.remove(feature);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Generate Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _isGenerating
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : ElevatedButton.icon(
                      onPressed: () => _handleGenerate(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Generate Copy & Layouts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
            ),

            if (_generatedOutput != null) ...[
              const SizedBox(height: 32),
              // Header for Results
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Formatted Output Layouts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Shuffler / Regenerate
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary),
                    tooltip: 'Shuffle template blocks',
                    onPressed: () => _handleGenerate(shuffle: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // TabBar & TabBarView
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.accent,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.accent,
                        dividerColor: Colors.transparent,
                        tabs: MarketingPlatform.values.map((p) {
                          return Tab(text: p.name.toUpperCase());
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 340,
                        child: TabBarView(
                          controller: _tabController,
                          children: MarketingPlatform.values.map((platform) {
                            final campaign = _formattedCampaigns[platform];
                            if (campaign == null) return const SizedBox.shrink();

                            return _buildPlatformTab(platform, campaign);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformTab(MarketingPlatform platform, FormattedCampaign campaign) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Character count indicator & Limit compliance badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${campaign.characterCount} Characters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: campaign.withinLimit ? AppColors.textSecondary : AppColors.error,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: campaign.withinLimit ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                campaign.withinLimit ? 'COMPLIANT' : 'OVER LIMIT',
                style: TextStyle(
                  color: campaign.withinLimit ? AppColors.success : AppColors.error,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Text display container
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                campaign.formattedText,
                style: const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action Toolbar
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleCopy(platform),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleShare(platform),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveCampaignToHistory(platform),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Log'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '', decimalDigits: 0);
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(1)}B';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    }
    return currencyFormat.format(price);
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }
}
