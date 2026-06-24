import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/widgets/shimmer_loading.dart';
import 'package:ppn/widgets/empty_state.dart';

class PartnerPropertiesScreen extends ConsumerStatefulWidget {
  const PartnerPropertiesScreen({super.key});

  @override
  ConsumerState<PartnerPropertiesScreen> createState() => _PartnerPropertiesScreenState();
}

class _PartnerPropertiesScreenState extends ConsumerState<PartnerPropertiesScreen> {
  final _searchController = TextEditingController();
  String _selectedStatusFilter = 'All'; // 'All', 'Available', 'Reserved', 'Sold'
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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
    final state = ref.watch(propertyProvider);
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Currency Formatter for Nigerian Naira
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    // Apply filtering
    final filteredProperties = state.properties.where((property) {
      final matchesSearch = property.title.toLowerCase().contains(_searchQuery) ||
          (property.location?.toLowerCase().contains(_searchQuery) ?? false);

      final matchesStatus = _selectedStatusFilter == 'All' ||
          property.status.value.toLowerCase() == _selectedStatusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Property Listings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      body: state.isLoading && state.properties.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: ShimmerGrid(),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final companyId = profile?.companyId;
                if (companyId != null) {
                  await ref.read(propertyProvider.notifier).loadProperties(companyId);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Filters & Search ──
                    _buildSearchAndFilters(theme),
                    const SizedBox(height: 24),

                    // ── Properties Grid/List ──
                    if (state.errorMessage != null)
                      Center(
                        child: Text(
                          'Error: ${state.errorMessage}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      )
                    else if (filteredProperties.isEmpty)
                      _buildEmptyState(theme)
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredProperties.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1),
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          mainAxisExtent: 380,
                        ),
                        itemBuilder: (context, index) {
                          final property = filteredProperties[index];
                          return _buildPropertyCard(context, property, currencyFormat, theme, profile);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (val) {
            if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'Search properties by title or location...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Available', 'Reserved', 'Sold'].map((status) {
              final isSelected = _selectedStatusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatusFilter = status;
                      });
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  showCheckmark: false,
                  elevation: 0,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyCard(
    BuildContext context,
    Property property,
    NumberFormat currencyFormat,
    ThemeData theme,
    Profile? profile,
  ) {
    final hasImage = property.images.isNotEmpty;
    final firstImageUrl = hasImage ? property.images.first : null;

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

    // Calculate estimated commission payout
    double estimatedPayout = 0.0;
    if (property.commissionType == CommissionType.percentage) {
      estimatedPayout = property.price * (property.commissionValue / 100);
    } else {
      estimatedPayout = property.commissionValue;
    }

    final origin = kIsWeb ? Uri.base.origin : 'https://scalewealth.com';
    final refCode = profile?.referralCode ?? 'PPN-PENDING';
    final referralLink = '$origin/properties/${property.id}?ref=$refCode';

    return Card(
      color: AppColors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/properties/${property.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Area
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    image: firstImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(firstImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: firstImageUrl == null
                      ? const Center(
                          child: Icon(
                            Icons.home_work_outlined,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : null,
                ),
                // Status Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      property.status.value.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location ?? 'No Location Listed',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Price & Commission Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRICE',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormat.format(property.price),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Commission
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            '+${currencyFormat.format(estimatedPayout)} Payout',
                            style: const TextStyle(
                              color: AppColors.successDark,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          property.commissionType == CommissionType.percentage
                              ? '${property.commissionValue.toStringAsFixed(1)}% split'
                              : 'Fixed pay',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                              onPressed: () => _copyReferralLink(referralLink),
                              tooltip: 'Copy Referral Link',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.accent),
                              onPressed: () => _shareReferralLink(referralLink, property.title),
                              tooltip: 'Share Referral Link',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return EmptyState(
      icon: Icons.home_work_outlined,
      title: 'No properties available',
      description: 'Your agency hasn\'t added any properties or none match your status filter.',
      actionLabel: 'Reset Filters',
      onActionPressed: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _selectedStatusFilter = 'All';
        });
      },
    );
  }
}
