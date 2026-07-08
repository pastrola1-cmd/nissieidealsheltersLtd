import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/utils/js_helper.dart';
import 'package:nissie_ideal_shelters/services/whatsapp_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

bool isCustomDomain(String hostname) {
  if (hostname.isEmpty) return false;
  final lower = hostname.toLowerCase();
  
  final excluded = [
    'localhost',
    '127.0.0.1',
    'scalewealth.app',
    'scalewealth.co',
    'scalewealth.com',
    'property-partner-network-94301.web.app',
    'property-partner-network-94301.firebaseapp.com',
  ];
  
  if (excluded.contains(lower)) return false;
  
  for (final domain in excluded) {
    if (domain != 'localhost' && domain != '127.0.0.1' && lower.endsWith('.$domain')) {
      return false;
    }
  }
  
  return true;
}

class LandingPageScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String? referralCode;
  final String? campaignId;

  const LandingPageScreen({
    super.key,
    required this.propertyId,
    this.referralCode,
    this.campaignId,
  });

  @override
  ConsumerState<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends ConsumerState<LandingPageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _pageController = PageController();
  final _scrollController = ScrollController();

  int _currentPage = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _submittedSuccessfully = false;

  Property? _property;
  Company? _company;
  Map<String, dynamic>? _landingPageConfig;
  LandingPageVariant? _selectedVariant;

  String _selectedPurpose = 'Investment';
  String? _selectedBudget;
  bool _consentChecked = true;

  // Tracking properties
  String? _submittedLeadId;
  int _timeOnPageSeconds = 0;
  Timer? _timeOnPageTimer;
  final Set<int> _scrollMilestones = {};
  String? _youtubeId;
  String? _webPlayerViewType;
  bool _isYouTube = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _timeOnPageTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);

      final hostname = getBrowserHostname();
      final isCustom = isCustomDomain(hostname);

      if (isCustom) {
        _company = await service.getCompanyByDomain(hostname);
        if (_company != null) {
          _property = await service.getPropertyByLpSlug(_company!.id, widget.propertyId);
        }
      } else {
        if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(widget.propertyId)) {
          _property = await service.getProperty(widget.propertyId);
        } else {
          final lpGlob = await service.getLandingPageBySlugGlobally(widget.propertyId);
          if (lpGlob != null) {
            _property = await service.getProperty(lpGlob['property_id']);
          }
        }
        if (_property != null) {
          _company = await service.getCompany(_property!.companyId);
        }
      }

      if (_property != null) {
        // Initialize default budget options based on property price first to prevent empty items dropdown crash
        _initializeBudgetOptions();

        // Initialize FB Pixel if ID is present and tracking is configured
        if (_company?.fbPixelId != null && _company!.fbPixelId!.isNotEmpty) {
          try {
            initFacebookPixel(_company!.fbPixelId!);
            final viewEventId = _generateEventId();
            trackFacebookPixel(
              'ViewContent',
              eventId: viewEventId,
              data: {
                'content_name': _property!.title,
                'content_type': 'product',
                'value': _property!.price.toDouble(),
                'currency': 'NGN',
              },
            );
            if (_company?.fbCapiToken != null && _company!.fbCapiToken!.isNotEmpty) {
              trackFacebookCapi(
                pixelId: _company!.fbPixelId!,
                capiToken: _company!.fbCapiToken!,
                eventName: 'ViewContent',
                eventId: viewEventId,
                sourceUrl: Uri.base.toString(),
                leadName: 'Anonymous Visitor',
                leadPhone: '',
                propertyValue: _property!.price.toDouble(),
                propertyName: _property!.title,
              );
            }
          } catch (e) {
            debugPrint('Error initializing Facebook Pixel/CAPI: $e');
          }
        }

        // Fetch optional Landing Page customization configs
        try {
          _landingPageConfig = await service.getLandingPageByPropertyId(_property!.id);

          if (_landingPageConfig != null) {
            final lpId = _landingPageConfig!['id'] as String;
            
            // Increment landing page view count
            await service.incrementLandingPageView(lpId);

            // A/B Testing Variant traffic splitting
            try {
              final variants = await service.getLandingPageVariants(lpId);
              if (variants.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                final variantKey = 'lp_variant_$lpId';
                String? assignedCode = prefs.getString(variantKey);

                LandingPageVariant? selected;
                if (assignedCode != null) {
                  final matches = variants.where((v) => v.variantCode == assignedCode).toList();
                  if (matches.isNotEmpty) {
                    selected = matches.first;
                  }
                }

                if (selected == null) {
                  final random = math.Random();
                  selected = variants[random.nextInt(variants.length)];
                  await prefs.setString(variantKey, selected.variantCode);
                }

                setState(() {
                  _selectedVariant = selected;
                });

                // Record variant view engagement securely
                await service.recordVariantEngagement(
                  variantId: selected.id,
                  isLead: false,
                );
              }
            } catch (ve) {
              debugPrint('Error handling A/B testing variant: $ve');
            }
          }
        } catch (e) {
          debugPrint('Error loading landing page customization config: $e');
        }

        // Initialize video player variables
        if (_property!.videoUrl != null && _property!.videoUrl!.isNotEmpty) {
          _youtubeId = extractYouTubeId(_property!.videoUrl!);
          if (_youtubeId != null) {
            _isYouTube = true;
            _webPlayerViewType = 'youtube-player-$_youtubeId';
            if (kIsWeb) {
              registerYouTubePlayerView(_webPlayerViewType!, _youtubeId!);
            }
          } else if (_property!.videoUrl!.toLowerCase().endsWith('.mp4') ||
              _property!.videoUrl!.toLowerCase().endsWith('.webm')) {
            _isYouTube = false;
            _webPlayerViewType = 'html5-player-${_property!.videoUrl!.hashCode}';
            if (kIsWeb) {
              registerHtml5VideoPlayerView(_webPlayerViewType!, _property!.videoUrl!);
            }
          }
        }

        // Initialize tracking (return visits, etc.)
        await _initTracking();
      }
    } catch (e) {
      debugPrint('Error loading landing page data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _budgetOptions = [];

  bool get _isLand {
    if (_property == null) return false;
    final title = _property!.title.toLowerCase();
    final desc = (_property!.description ?? '').toLowerCase();
    return title.contains('land') ||
        title.contains('plot') ||
        title.contains('acre') ||
        title.contains('hectare') ||
        title.contains('site') ||
        desc.contains('plot size') ||
        desc.contains('sqm') ||
        desc.contains('zoning') ||
        desc.contains('allocation');
  }

  void _initializeBudgetOptions() {
    if (_property == null) return;
    final price = _property!.price.toDouble();

    if (price < 10000000) {
      _budgetOptions = ['Under ₦5M', '₦5M - ₦10M', '₦10M - ₦20M', '₦20M+'];
    } else if (price < 50000000) {
      _budgetOptions = ['Under ₦20M', '₦20M - ₦50M', '₦50M - ₦100M', '₦100M+'];
    } else {
      _budgetOptions = ['Under ₦50M', '₦50M - ₦100M', '₦100M - ₦200M', '₦200M+'];
    }
    _selectedBudget = _budgetOptions[1];
  }

  String _generateEventId() {
    final random = math.Random();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _submitLead() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the consent terms to proceed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final consentText =
          'By submitting this form, you agree to be contacted via WhatsApp, phone, or email regarding ${_property?.title ?? 'this property'}.';

      final leadNotes = 'Purpose: $_selectedPurpose. Budget: $_selectedBudget. '
          '${_notesController.text.isNotEmpty ? 'Message: ${_notesController.text}' : ''}';

      // Submit lead securely via the SECURITY DEFINER postgres function and get lead ID
      final leadId = await service.submitPublicLead(
        companyId: _property!.companyId,
        propertyId: _property!.id,
        buyerName: _nameController.text.trim(),
        buyerPhone: _phoneController.text.trim(),
        buyerEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        notes: leadNotes,
        consentText: consentText,
        ipAddress: kIsWeb ? Uri.base.host : 'App Client',
        userAgent: kIsWeb ? 'Web Browser' : 'Mobile Client',
        sourceLandingPageId: _landingPageConfig?['id'],
      );

      // Track lead conversion event
      if (_company?.fbPixelId != null && _company!.fbPixelId!.isNotEmpty) {
        final leadEventId = _generateEventId();
        trackFacebookPixel(
          'Lead',
          eventId: leadEventId,
          data: {
            'content_name': _property!.title,
            'value': _property!.price.toDouble(),
            'currency': 'NGN',
          },
        );
        if (_company?.fbCapiToken != null && _company!.fbCapiToken!.isNotEmpty) {
          trackFacebookCapi(
            pixelId: _company!.fbPixelId!,
            capiToken: _company!.fbCapiToken!,
            eventName: 'Lead',
            eventId: leadEventId,
            sourceUrl: Uri.base.toString(),
            leadName: _nameController.text.trim(),
            leadPhone: _phoneController.text.trim(),
            leadEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
            propertyValue: _property!.price.toDouble(),
            propertyName: _property!.title,
          );
        }
      }

      // Save lead ID to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lp_lead_id_${widget.propertyId}', leadId);
      setState(() {
        _submittedLeadId = leadId;
      });

      // Record variant lead engagement securely if a variant is selected
      if (_selectedVariant != null) {
        try {
          await service.recordVariantEngagement(
            variantId: _selectedVariant!.id,
            isLead: true,
          );
        } catch (ve) {
          debugPrint('Error recording variant lead engagement: $ve');
        }
      }

      // Submit all pre-submission accumulated signals to the database
      final localVisits = prefs.getInt('lp_visit_count_${widget.propertyId}') ?? 1;
      final localVideo = prefs.getInt('lp_max_video_progress_${widget.propertyId}') ?? 0;
      final localScroll = prefs.getInt('lp_max_scroll_depth_${widget.propertyId}') ?? 0;
      final localTime = prefs.getInt('lp_time_on_page_${widget.propertyId}') ?? 0;

      if (localVisits > 0) {
        await service.logLeadEngagement(
          leadId: leadId,
          signalType: 'page_visit',
          signalValue: DateTime.now().toIso8601String(),
        );
        for (int i = 1; i < localVisits; i++) {
          await service.logLeadEngagement(
            leadId: leadId,
            signalType: 'page_visit',
            signalValue: DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
          );
        }
      }

      if (localVideo > 0) {
        await service.logLeadEngagement(
          leadId: leadId,
          signalType: 'video_progress',
          signalValue: localVideo.toString(),
        );
      }

      if (localScroll > 0) {
        await service.logLeadEngagement(
          leadId: leadId,
          signalType: 'scroll_depth',
          signalValue: localScroll.toString(),
        );
      }

      if (localTime > 0) {
        await service.logLeadEngagement(
          leadId: leadId,
          signalType: 'time_on_page',
          signalValue: localTime.toString(),
        );
      }

      // Trigger Meta WhatsApp transactional brochure auto-send
      if (_company?.whatsappEnabled == true) {
        final brochureUrl = _property!.images.isNotEmpty ? 'https://pdfobject.com/pdf/sample.pdf' : '';
        ref.read(whatsAppServiceProvider).sendTemplateMessage(
          companyId: _property!.companyId,
          leadId: leadId,
          recipientPhone: _phoneController.text.trim(),
          leadName: _nameController.text.trim(),
          propertyTitle: _property!.title,
          brochureUrl: brochureUrl,
          videoUrl: _property!.videoUrl,
        );
      }

      setState(() {
        _submittedSuccessfully = true;
      });

      // Show success popup or proceed to redirect
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your inquiry has been logged successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting lead: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _launchWhatsAppChat() async {
    if (_property == null || _company == null) return;

    final companyPhone = _company!.phone ?? '';
    if (companyPhone.isEmpty) return;

    // Normalize phone number (remove spaces, symbols, leading zero)
    String cleanPhone = companyPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = '234${cleanPhone.substring(1)}';
    }

    final message = 'Hi, I am interested in booking an inspection for the property: *${_property!.title}* '
        '(${_property!.location ?? ''}). Please share details.';

    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch WhatsApp chat.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _launchVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open video link.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_property == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_work_outlined, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text('Listing no longer active or available.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    if (_company != null && !_company!.lpModuleEnabled) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text('This feature is currently disabled.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('The hosting agency has not enabled the Landing Pages module.',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final headline = _selectedVariant?.headline ?? _landingPageConfig?['headline'] ?? 'Exclusive Offer: ${_property!.title}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // ── TOP LOGO HEADER ──
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (_company?.logoUrl != null && _company!.logoUrl!.isNotEmpty)
                    Image.network(_company!.logoUrl!, height: 40)
                  else
                    const Icon(Icons.real_estate_agent_rounded, color: AppColors.accent, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    _company?.name ?? 'ScaleWealth Estate',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            // ── MAIN LANDING CONTENT ──
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildListingShowcase(theme, currencyFormat, headline)),
                            const SizedBox(width: 32),
                            Expanded(flex: 2, child: _buildLeadFormCard(theme)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildListingShowcase(theme, currencyFormat, headline),
                            const SizedBox(height: 32),
                            _buildLeadFormCard(theme),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ── FOOTER ──
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Text(
                    _company?.name ?? 'ScaleWealth Estate',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _company?.email ?? 'info@scalewealth.com',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    '© 2026 ${_company?.name ?? 'ScaleWealth Estate'}. All rights reserved.',
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'NDPR Compliant. By submitting your details on this page, you agree to our privacy terms and data usage policies.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _launchWhatsAppChat,
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Chat on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildListingShowcase(ThemeData theme, NumberFormat currencyFormat, String headline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline
        Text(
          headline,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 32,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 16),

        // Carousel / Gallery
        Stack(
          children: [
            Container(
              height: 380,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _property!.images.isEmpty
                  ? const Center(
                      child: Icon(Icons.home_work_outlined, size: 80, color: AppColors.textTertiary),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _property!.images.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          _property!.images[index],
                          fit: BoxFit.cover,
                        );
                      },
                    ),
            ),
            if (_property!.images.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${_property!.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Key Details (Price, Location)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INVESTMENT VALUE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                Text(currencyFormat.format(_property!.price), style: const TextStyle(color: AppColors.accent, fontSize: 28, fontWeight: FontWeight.w900)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _property!.status.value.toUpperCase(),
                style: const TextStyle(color: AppColors.successDark, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _property!.location ?? 'No location details',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Property Description
        Text('About this Property', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Text(
          _property!.description ?? 'No description provided.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 32),

        // Payment Plan Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.credit_card_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FLEXIBLE PAYMENT PLANS AVAILABLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _landingPageConfig?['landmark_notes']?.toString().contains('installment') == true
                          ? 'Installment payment plans available. Get details in the brochure.'
                          : 'Spread payments up to 12 - 24 months with a minimal initial deposit.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Video Tour
        if (_property!.videoUrl != null && _property!.videoUrl!.isNotEmpty) ...[
          Text(
            'Video Walkthrough',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: kIsWeb && _webPlayerViewType != null
                ? HtmlElementView(
                    viewType: _webPlayerViewType!,
                    onPlatformViewCreated: (viewId) {
                      _setupVideoTracking();
                    },
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_property!.images.isNotEmpty)
                        Image.network(
                          _property!.images[0],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _launchVideo(_property!.videoUrl!);
                          _logVideoMilestone(50);
                        },
                        icon: const Icon(Icons.play_circle_fill, size: 24),
                        label: const Text('Watch Property Video Tour'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
        ],

        // Neighborhood & Landmarks
        if (_landingPageConfig?['landmark_notes'] != null &&
            _landingPageConfig!['landmark_notes'].toString().isNotEmpty) ...[
          Text(
            'Neighborhood & Landmarks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.map_outlined, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Location Highlights',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _landingPageConfig!['landmark_notes'],
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Testimonials Section
        Text(
          'Trusted by Property Buyers',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTestimonialCard(
                'Oluwaseun A.',
                'Diaspora Investor',
                'The site inspection booking was seamless. I bought two plots of land while residing in London without any hassles.',
              ),
              _buildTestimonialCard(
                'Chioma O.',
                'Business Owner',
                'Very professional service. The payment plan details were clear, and the property brochure was instantly sent on WhatsApp.',
              ),
              _buildTestimonialCard(
                'Ibrahim K.',
                'Residential Buyer',
                'Extremely trustworthy platform. Verified documentation and smooth follow-up with the agency representative.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeadFormCard(ThemeData theme) {
    if (_submittedSuccessfully) {
      return Card(
        color: AppColors.white,
        elevation: 4,
        shadowColor: AppColors.border.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                'Inquiry Logged!',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                'We have logged your inspection request. Direct-message our team via WhatsApp to coordinate immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 14),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _launchWhatsAppChat,
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Chat on WhatsApp Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _submittedSuccessfully = false),
                child: const Text('Submit Another Inquiry'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: AppColors.white,
      elevation: 4,
      shadowColor: AppColors.border.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedVariant?.ctaPrimary ?? _landingPageConfig?['cta_primary'] ?? (_isLand ? 'Schedule Physical Land Tour' : 'Book Free Site Inspection'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _isLand
                    ? 'Provide your details to schedule a physical tour of the plot and secure your layout plan.'
                    : 'Provide your details to schedule a physical tour and get the brochure.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'e.g. John Doe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter your name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // WhatsApp Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'WhatsApp Phone Number',
                  hintText: 'e.g. 08012345678',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter your phone number';
                  // Simple phone validator
                  if (val.trim().length < 8) return 'Please enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Purpose Dropdown (Investment vs Residential)
              DropdownButtonFormField<String>(
                value: _selectedPurpose,
                decoration: InputDecoration(
                  labelText: 'Buying Purpose',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.assignment_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Investment', child: Text('Investment Portfolio')),
                  DropdownMenuItem(value: 'Residential', child: Text('Personal Residential')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPurpose = val);
                },
              ),
              const SizedBox(height: 16),

              // Budget Range Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBudget,
                decoration: InputDecoration(
                  labelText: 'Budget Range',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                items: _budgetOptions.map((opt) {
                  return DropdownMenuItem(value: opt, child: Text(opt));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBudget = val);
                },
              ),
              const SizedBox(height: 24),

              // NDPR Consent
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentChecked,
                    activeColor: AppColors.accent,
                    onChanged: (val) {
                      if (val != null) setState(() => _consentChecked = val);
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'I consent to being contacted via WhatsApp, call, or email regarding this property listing.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitLead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _selectedVariant?.ctaPrimary ?? _landingPageConfig?['cta_primary'] ?? (_isLand ? 'Submit & Get Plot Layout' : 'Submit & Get Brochure'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonialCard(String author, String role, String text) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16, bottom: 8, top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
              Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
              Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
              Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
              Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              '"$text"',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
          Text(role, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Engagement Signals Tracking Helpers ──

  Future<void> _initTracking() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have a lead ID for this property
    final savedLeadId = prefs.getString('lp_lead_id_${widget.propertyId}');
    if (savedLeadId != null) {
      setState(() {
        _submittedLeadId = savedLeadId;
      });
      // Log the return visit signal
      final service = ref.read(supabaseServiceProvider);
      await service.logLeadEngagement(
        leadId: savedLeadId,
        signalType: 'page_visit',
        signalValue: DateTime.now().toIso8601String(),
      );
    } else {
      // Pre-submission visit: increment visit count
      final visitKey = 'lp_visit_count_${widget.propertyId}';
      final currentCount = prefs.getInt(visitKey) ?? 0;
      await prefs.setInt(visitKey, currentCount + 1);
    }

    // Start time-on-page tracking
    _startTimeOnPageTracking();
  }

  void _startTimeOnPageTracking() {
    _timeOnPageTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      _timeOnPageSeconds += 10;
      
      if (_submittedLeadId != null) {
        final service = ref.read(supabaseServiceProvider);
        await service.logLeadEngagement(
          leadId: _submittedLeadId!,
          signalType: 'time_on_page',
          signalValue: _timeOnPageSeconds.toString(),
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lp_time_on_page_${widget.propertyId}', _timeOnPageSeconds);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll <= 0) return;

    final percent = (currentScroll / maxScroll) * 100;
    
    // Check milestones
    for (final milestone in [25, 50, 75, 100]) {
      if (percent >= milestone && !_scrollMilestones.contains(milestone)) {
        _scrollMilestones.add(milestone);
        _logScrollMilestone(milestone);
      }
    }
  }

  void _logScrollMilestone(int milestone) async {
    // Fire Pixel event
    if (_company?.fbPixelId != null && _company!.fbPixelId!.isNotEmpty) {
      trackFacebookPixel(
        'ScrollDepth',
        eventId: _generateEventId(),
        data: {
          'milestone': milestone,
          'content_name': _property?.title ?? '',
        },
      );
    }

    if (_submittedLeadId != null) {
      final service = ref.read(supabaseServiceProvider);
      await service.logLeadEngagement(
        leadId: _submittedLeadId!,
        signalType: 'scroll_depth',
        signalValue: milestone.toString(),
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lp_max_scroll_depth_${widget.propertyId}', milestone);
    }
  }

  String? extractYouTubeId(String url) {
    final regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 2) {
      final id = match.group(2);
      if (id != null && id.length == 11) {
        return id;
      }
    }
    return null;
  }

  void _setupVideoTracking() {
    if (!kIsWeb) return;
    if (_isYouTube && _youtubeId != null) {
      initYouTubeVideoTracking(
        'youtube-iframe-$_youtubeId',
        _youtubeId!,
        (milestoneStr) {
          final milestone = int.tryParse(milestoneStr) ?? 0;
          _logVideoMilestone(milestone);
        },
      );
    } else if (_webPlayerViewType != null) {
      final elementId = 'html5-video-${_webPlayerViewType!.hashCode}';
      initHtml5VideoTracking(
        elementId,
        (milestoneStr) {
          final milestone = int.tryParse(milestoneStr) ?? 0;
          _logVideoMilestone(milestone);
        },
      );
    }
  }

  void _logVideoMilestone(int milestone) async {
    // Fire Pixel event
    if (_company?.fbPixelId != null && _company!.fbPixelId!.isNotEmpty) {
      trackFacebookPixel(
        'VideoProgress',
        eventId: _generateEventId(),
        data: {
          'milestone': milestone,
          'content_name': _property?.title ?? '',
        },
      );
    }

    if (_submittedLeadId != null) {
      final service = ref.read(supabaseServiceProvider);
      await service.logLeadEngagement(
        leadId: _submittedLeadId!,
        signalType: 'video_progress',
        signalValue: milestone.toString(),
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final currentMax = prefs.getInt('lp_max_video_progress_${widget.propertyId}') ?? 0;
      if (milestone > currentMax) {
        await prefs.setInt('lp_max_video_progress_${widget.propertyId}', milestone);
      }
    }
  }
}
