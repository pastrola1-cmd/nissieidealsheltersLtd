import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/widgets/shimmer_loading.dart';
import 'package:ppn/widgets/empty_state.dart';

class AdminPropertiesScreen extends ConsumerStatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  ConsumerState<AdminPropertiesScreen> createState() => _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends ConsumerState<AdminPropertiesScreen> {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(propertyProvider);
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

    // Stats calculation
    final totalCount = state.properties.length;
    final availableCount = state.properties.where((p) => p.status == PropertyStatus.available).length;
    final soldCount = state.properties.where((p) => p.status == PropertyStatus.sold).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Properties Portfolio'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => context.pushNamed('adminPropertyAdd'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Property'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ),
      body: state.isLoading && state.properties.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: ShimmerGrid(),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final companyId = ref.read(propertyProvider).properties.firstOrNull?.companyId;
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
                    // ── Stats Row ──
                    _buildStatsRow(
                      theme: theme,
                      total: totalCount,
                      available: availableCount,
                      sold: soldCount,
                      screenWidth: screenWidth,
                    ),
                    const SizedBox(height: 24),

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
                          mainAxisExtent: 390,
                        ),
                        itemBuilder: (context, index) {
                          final property = filteredProperties[index];
                          return _buildPropertyCard(context, property, currencyFormat, theme);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow({
    required ThemeData theme,
    required int total,
    required int available,
    required int sold,
    required double screenWidth,
  }) {
    final isMobile = screenWidth < 600;
    
    final cards = [
      _buildStatCard(
        title: 'Total Listings',
        value: total.toString(),
        icon: Icons.business_rounded,
        color: AppColors.primary,
        textColor: AppColors.textOnPrimary,
        isGradient: true,
      ),
      _buildStatCard(
        title: 'Available',
        value: available.toString(),
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        textColor: AppColors.successDark,
        isGradient: false,
      ),
      _buildStatCard(
        title: 'Sold Out',
        value: sold.toString(),
        icon: Icons.shopping_bag_outlined,
        color: AppColors.secondary,
        textColor: AppColors.secondary,
        isGradient: false,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 12),
          cards[1],
          const SizedBox(height: 12),
          cards[2],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color textColor,
    required bool isGradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGradient ? null : AppColors.surface,
        gradient: isGradient ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(16),
        border: isGradient ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGradient ? Colors.white12 : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isGradient ? Colors.white : color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isGradient ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isGradient ? Colors.white : AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
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
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            property.commissionType == CommissionType.percentage
                                ? '${property.commissionValue.toStringAsFixed(0)}% Comm'
                                : '${currencyFormat.format(property.commissionValue)} Comm',
                            style: const TextStyle(
                              color: AppColors.accent,
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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            context.pushNamed(
                              'adminPropertyEdit',
                              pathParameters: {'id': property.id},
                            );
                          },
                          tooltip: 'Edit Property',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                          onPressed: () => _showDeleteConfirmation(context, property),
                          tooltip: 'Delete Property',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
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
      title: 'No properties match your filter',
      description: 'Try clearing search queries or adding a new property portfolio.',
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

  void _showDeleteConfirmation(BuildContext context, Property property) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Property?'),
          content: Text('Are you sure you want to delete "${property.title}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final success = await ref.read(propertyProvider.notifier).deleteProperty(property.id);
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Property deleted successfully.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    final error = ref.read(propertyProvider).errorMessage ?? 'Failed to delete';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
