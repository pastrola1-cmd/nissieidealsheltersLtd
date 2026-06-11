import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/services/supabase_service.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String? referralCode;
  final String? campaignId;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
    this.referralCode,
    this.campaignId,
  });

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  Property? _property;

  @override
  void initState() {
    super.initState();
    _loadProperty();
    _handleReferral();
  }

  Future<void> _handleReferral() async {
    final code = widget.referralCode;
    final campaignId = widget.campaignId;

    try {
      const secureStorage = FlutterSecureStorage();

      if (code != null && code.isNotEmpty) {
        // 1. Store referral code persistently in secure storage
        await secureStorage.write(key: 'last_referral_code', value: code);
        await secureStorage.write(key: 'last_referral_property_id', value: widget.propertyId);

        // 2. Resolve partner profile from referral code
        final service = ref.read(supabaseServiceProvider);
        final partner = await service.getProfileByReferralCode(code);

        // 3. Log referral link click in DB
        await service.logReferralClick(
          referralCode: code,
          propertyId: widget.propertyId,
          partnerId: partner?.id,
          userAgent: kIsWeb ? 'Web Browser' : 'Mobile App',
        );
      }

      if (campaignId != null && campaignId.isNotEmpty) {
        await secureStorage.write(key: 'last_referral_campaign_id', value: campaignId);
      } else {
        await secureStorage.delete(key: 'last_referral_campaign_id');
      }
    } catch (e) {
      debugPrint('Error processing referral click: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProperty() async {
    setState(() => _isLoading = true);
    try {
      // Try finding from cached list first
      final properties = ref.read(propertyProvider).properties;
      final match = properties.where((p) => p.id == widget.propertyId).firstOrNull;
      if (match != null) {
        _property = match;
      } else {
        // Fallback to direct DB call (e.g. deep-linked guest)
        final service = ref.read(supabaseServiceProvider);
        final fetched = await service.getProperty(widget.propertyId);
        if (fetched != null) {
          _property = fetched;
        }
      }
    } catch (e) {
      debugPrint('Error loading property details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _copyReferralLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareReferralLink(String link, String title) {
    SharePlus.instance.share(
      ShareParams(
        text: 'Check out this property: $title\n$link',
        subject: 'Property Referral Link',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(authProvider).profile;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final property = _property;
    if (property == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Property Details'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_work_outlined, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text('Property not found or deleted.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    // Calculate commission payout
    double estimatedPayout = 0.0;
    if (property.commissionType == CommissionType.percentage) {
      estimatedPayout = property.price * (property.commissionValue / 100);
    } else {
      estimatedPayout = property.commissionValue;
    }

    // Dynamic Referral Link Building
    final origin = kIsWeb ? Uri.base.origin : 'https://scalewealth.com';
    final refCode = userProfile?.referralCode ?? 'PPN-PENDING';
    final referralLink = '$origin/properties/${property.id}?ref=$refCode';

    final isUserAdmin = userProfile?.role == UserRole.admin || userProfile?.role == UserRole.platformAdmin;
    final isUserPartner = userProfile?.role == UserRole.partner;
    final canSeeCommission = isUserAdmin || isUserPartner;
    final canGenerateCampaign = userProfile?.role == UserRole.admin ||
        userProfile?.role == UserRole.platformAdmin ||
        userProfile?.role == UserRole.manager ||
        userProfile?.role == UserRole.marketer;

    Color statusColor;
    switch (property.status) {
      case PropertyStatus.available:
        statusColor = AppColors.success;
        break;
      case PropertyStatus.reserved:
        statusColor = AppColors.warning;
        break;
      case PropertyStatus.sold:
        statusColor = AppColors.error;
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Carousel Top Area ──
            Stack(
              children: [
                Container(
                  height: 320,
                  width: double.infinity,
                  color: AppColors.surfaceVariant,
                  child: property.images.isEmpty
                      ? const Center(
                          child: Icon(Icons.home_work_outlined, size: 80, color: AppColors.textTertiary),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: property.images.length,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemBuilder: (context, index) {
                            return Image.network(
                              property.images[index],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                ),
                // Back Button Overlay
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                // Page Indicator Overlay
                if (property.images.length > 1)
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
                        '${_currentPage + 1}/${property.images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Property Info ──
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          property.status.value.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          property.location ?? 'No location listed',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price block
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LISTING PRICE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          currencyFormat.format(property.price),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Commission Split Card (Admins / Partners only) ──
                  if (canSeeCommission) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.wallet_giftcard_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                isUserAdmin ? 'Agency Commission Structure' : 'Partner Commission Split',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Commission Rate', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text(
                                property.commissionType == CommissionType.percentage
                                    ? '${property.commissionValue.toStringAsFixed(1)}%'
                                    : currencyFormat.format(property.commissionValue),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isUserAdmin ? 'Total Value Payout' : 'Your Estimated Earning',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                currencyFormat.format(estimatedPayout),
                                style: const TextStyle(
                                  color: AppColors.successLight,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Referral generation card (Partners only) ──
                  if (isUserPartner) ...[
                    Card(
                      color: AppColors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.share_rounded, color: AppColors.accent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Your Unique Referral Link',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Share this link with prospective buyers. Any click, inspection request, or sale generated through this link is automatically attributed to your wallet.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      referralLink,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _copyReferralLink(referralLink),
                                    child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _copyReferralLink(referralLink),
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: const Text('Copy Link'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.surfaceVariant,
                                      foregroundColor: AppColors.textPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _shareReferralLink(referralLink, property.title),
                                    icon: const Icon(Icons.share_rounded, size: 16),
                                    label: const Text('Share Link'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: AppColors.textOnAccent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Campaign Generator card (Admins, Managers, Marketers) ──
                  if (canGenerateCampaign) ...[
                    Card(
                      color: AppColors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Marketing Intelligence',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Generate high-converting, rule-based marketing copy tailored for Facebook, Instagram, WhatsApp, and LinkedIn targeting specified local buyer segments.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final role = userProfile?.role.value;
                                  context.push('/$role/campaigns/generator?propertyId=${property.id}');
                                },
                                icon: const Icon(Icons.campaign_rounded, size: 16),
                                label: const Text('Launch Campaign Generator'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description Header
                  Text(
                    'Property Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description Text
                  Text(
                    property.description ?? 'No description listed for this property.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Video Link (if present)
                  if (property.videoUrl != null && property.videoUrl!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Video Tour',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _launchVideo(property.videoUrl!),
                      icon: const Icon(Icons.play_circle_fill, size: 20),
                      label: const Text('Watch Video Walkthrough'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Buyer CTA Action Panel ──
                  if (userProfile == null) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Interested in this property?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign up or log in to schedule an inspection with one of our verified partners.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => context.push('/signup'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Get Started & Book Inspection', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (userProfile.role == UserRole.buyer) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/buyer/inspections/book?propertyId=${property.id}');
                        },
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Schedule Property Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
