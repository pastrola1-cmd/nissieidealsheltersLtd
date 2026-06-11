import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/widgets/lead_usage_progress_bar.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  int _propertiesCount = 0;
  int _partnersCount = 0;
  bool _isLoadingCounts = true;
  String? _errorMessage;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
    locale: 'en_NG',
  );

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCounts = true;
      _errorMessage = null;
    });

    try {
      final company = ref.read(authProvider).company;
      if (company != null) {
        final service = ref.read(supabaseServiceProvider);
        
        final properties = await service.getProperties(companyId: company.id);
        final partners = await service.getProfilesByRole(UserRole.partner, companyId: company.id);

        if (mounted) {
          setState(() {
            _propertiesCount = properties.length;
            _partnersCount = partners.length;
            _isLoadingCounts = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingCounts = false;
            _errorMessage = "Company details not found.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
          _errorMessage = "Failed to load usage data: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final company = authState.company;
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (company == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Billing & Subscription'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final activePlan = company.plan;
    final isExpiresSoon = company.subscriptionExpiresAt != null &&
        company.subscriptionExpiresAt!.difference(DateTime.now()).inDays <= 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'ScaleWealth Estate Billing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              ref.invalidate(monthlyLeadCountProvider);
              await ref.read(authProvider.notifier).refreshCompany();
              await _loadCounts();
            },
          ),
        ],
      ),
      body: _isLoadingCounts
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(monthlyLeadCountProvider);
                await ref.read(authProvider.notifier).refreshCompany();
                await _loadCounts();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.errorDark),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.errorDark),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── 1. Active Plan Overview Card ──
                    _buildActivePlanCard(company, activePlan, isExpiresSoon),
                    const SizedBox(height: 32),

                    // ── 2. Resource Usage Metrics ──
                    Text(
                      'Resource Usage',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildUsageMetrics(activePlan),
                    const SizedBox(height: 20),
                    const LeadUsageProgressBar(),
                    const SizedBox(height: 32),

                    // ── 3. Upgrade Options ──
                    Text(
                      'Available Tiers',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPricingGrid(context, company, isMobile),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActivePlanCard(Company company, SubscriptionPlan activePlan, bool isExpiresSoon) {
    final expiryText = company.subscriptionExpiresAt != null
        ? DateFormat('MMMM dd, yyyy').format(company.subscriptionExpiresAt!.toLocal())
        : 'Never';

    final daysRemaining = company.subscriptionExpiresAt != null
        ? company.subscriptionExpiresAt!.difference(DateTime.now()).inDays
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.star_border_purple500_rounded,
              size: 150,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            activePlan.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: company.subscriptionStatus == 'active' || company.subscriptionStatus == 'trialing'
                            ? AppColors.success.withOpacity(0.9)
                            : AppColors.error.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        company.subscriptionStatus.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'CURRENT PLAN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activePlan.tier == 'enterprise'
                      ? 'Enterprise Access'
                      : _currencyFormat.format(activePlan.price) + ' / mo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expires At',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expiryText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (daysRemaining != null && daysRemaining > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Time Left',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$daysRemaining day${daysRemaining == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: isExpiresSoon ? AppColors.accentLight : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageMetrics(SubscriptionPlan activePlan) {
    final hasUnlimitedListings = activePlan.maxListings >= 999999;
    final hasUnlimitedPartners = activePlan.maxPartners >= 999999;

    final listingsProgress = hasUnlimitedListings
        ? 0.0
        : (_propertiesCount / activePlan.maxListings).clamp(0.0, 1.0);

    final partnersProgress = hasUnlimitedPartners
        ? 0.0
        : (_partnersCount / activePlan.maxPartners).clamp(0.0, 1.0);

    return Column(
      children: [
        _buildUsageBar(
          label: 'Properties Listings',
          used: _propertiesCount,
          max: hasUnlimitedListings ? null : activePlan.maxListings,
          progress: listingsProgress,
          color: AppColors.success,
        ),
        const SizedBox(height: 20),
        _buildUsageBar(
          label: 'Registered Partners',
          used: _partnersCount,
          max: hasUnlimitedPartners ? null : activePlan.maxPartners,
          progress: partnersProgress,
          color: AppColors.info,
        ),
      ],
    );
  }

  Widget _buildUsageBar({
    required String label,
    required int used,
    required int? max,
    required double progress,
    required Color color,
  }) {
    final isLimitReached = max != null && used >= max;

    return Card(
      elevation: 0,
      color: Colors.white,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  max == null ? '$used / Unlimited' : '$used / $max',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLimitReached ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 10,
                child: LinearProgressIndicator(
                  value: max == null ? 1.0 : progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isLimitReached ? AppColors.error : color,
                  ),
                ),
              ),
            ),
            if (isLimitReached) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Limit reached! Upgrade your plan to add more.',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPricingGrid(BuildContext context, Company company, bool isMobile) {
    final plans = [
      SubscriptionPlan.basic,
      SubscriptionPlan.growth,
      SubscriptionPlan.enterprise,
    ];

    if (isMobile) {
      return Column(
        children: plans.map((plan) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildPricingCard(context, company, plan),
        )).toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plans.map((plan) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _buildPricingCard(context, company, plan),
        ),
      )).toList(),
    );
  }

  Widget _buildPricingCard(BuildContext context, Company company, SubscriptionPlan plan) {
    final isCurrent = company.subscriptionTier == plan.tier;

    return Card(
      elevation: isCurrent ? 4 : 0,
      color: Colors.white,
      shadowColor: AppColors.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCurrent ? AppColors.accent : AppColors.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCurrent) ...[
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active Plan',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              plan.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currencyFormat.format(plan.price) + ' / mo',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...plan.features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: isCurrent
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Current Tier'),
                    )
                  : ElevatedButton(
                      onPressed: ref.read(authProvider).profile?.role == UserRole.manager
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Only Agency Administrators can upgrade the subscription plan. Please contact your admin.'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.warningDark,
                                ),
                              );
                            }
                          : () => _showUpgradeInstructions(context, company, plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ref.read(authProvider).profile?.role == UserRole.manager ? Colors.grey[400] : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(ref.read(authProvider).profile?.role == UserRole.manager ? 'Contact Admin to Upgrade' : 'Select Plan'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeInstructions(BuildContext context, Company company, SubscriptionPlan targetPlan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upgrade to ${targetPlan.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for upgrading! We are currently operating offline billing. To upgrade your subscription, please make a bank transfer to the following account:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Bank Name', 'Sterling Bank'),
                  const Divider(height: 16),
                  _buildDetailRow('Account Number', '0092384712'),
                  const Divider(height: 16),
                  _buildDetailRow('Account Name', 'ScaleWealth Estate Ltd'),
                  const Divider(height: 16),
                  _buildDetailRow('Amount', _currencyFormat.format(targetPlan.price)),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tenant ID',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Row(
                        children: [
                          Text(
                            company.id.substring(0, 8) + '...',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: company.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tenant ID copied to clipboard.'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.copy,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'IMPORTANT: Please use your Tenant ID as the transfer description/reference to ensure fast activation.',
              style: TextStyle(
                color: AppColors.warningDark,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email Support'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final emailUri = Uri(
                        scheme: 'mailto',
                        path: 'support@scalewealth.com',
                        queryParameters: {
                          'subject': 'Subscription Upgrade Request: ${company.name}',
                          'body': 'Hello ScaleWealth Support,\n\nWe have initiated a payment to upgrade our agency subscription to the ${targetPlan.name}.\n\nTenant ID: ${company.id}\nCompany Name: ${company.name}\n\nPlease find the payment confirmation receipt attached.\n\nThank you!',
                        },
                      );
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open email client.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('WhatsApp Support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final message = Uri.encodeComponent(
                        'Hello Support, we want to upgrade our ScaleWealth Estate subscription to the ${targetPlan.name}.\n\nTenant ID: ${company.id}\nCompany: ${company.name}',
                      );
                      final whatsappUrl = Uri.parse('https://wa.me/2348000000000?text=$message');
                      if (await canLaunchUrl(whatsappUrl)) {
                        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not launch WhatsApp.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
