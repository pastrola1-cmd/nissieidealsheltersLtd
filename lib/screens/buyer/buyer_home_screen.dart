import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';
import 'package:nissie_ideal_shelters/providers/dashboard_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/providers/notification_provider.dart';
import 'package:nissie_ideal_shelters/models/models.dart';

class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedLocation = 'All';

  @override
  void initState() {
    super.initState();
    // Default the selected company if it's null
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final selectedId = ref.read(selectedCompanyIdProvider);
      if (selectedId == null) {
        try {
          final companies = await ref.read(allCompaniesProvider.future);
          if (companies.isNotEmpty && mounted) {
            ref.read(selectedCompanyIdProvider.notifier).state = companies.first.id;
          }
        } catch (e) {
          debugPrint('Error defaulting selected company: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAgencySelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Real Estate Agency',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Consumer(
                builder: (context, ref, child) {
                  final companiesVal = ref.watch(allCompaniesProvider);
                  final selectedId = ref.watch(selectedCompanyIdProvider);

                  return companiesVal.when(
                    data: (companies) {
                      if (companies.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No active agencies found.', style: TextStyle(color: AppColors.textSecondary)),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: companies.length,
                        itemBuilder: (context, index) {
                          final item = companies[index];
                          final isSelected = item.id == selectedId;
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                                image: item.logoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(item.logoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: item.logoUrl == null
                                  ? const Icon(Icons.business_rounded, color: AppColors.textTertiary)
                                  : null,
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                                : null,
                            onTap: () {
                              ref.read(selectedCompanyIdProvider.notifier).state = item.id;
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (err, s) => Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('Error loading agencies: $err', style: const TextStyle(color: AppColors.error)),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyState = ref.watch(companyProvider);
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(dashboardProvider);
    final propertiesState = ref.watch(propertyProvider);
    final notificationState = ref.watch(notificationProvider);

    final company = companyState.company;
    final profile = authState.profile;
    final unreadNotifications = notificationState.notifications.where((n) => !n.read).length;

    // Filter available properties based on search query and location chip
    final availableProperties = propertiesState.properties.where((p) {
      if (p.status != PropertyStatus.available) return false;
      
      final query = _searchController.text.toLowerCase();
      final matchesQuery = query.isEmpty ||
          p.title.toLowerCase().contains(query) ||
          (p.location != null && p.location!.toLowerCase().contains(query)) ||
          (p.description != null && p.description!.toLowerCase().contains(query));
      
      final matchesLocation = _selectedLocation == 'All' ||
          (p.location != null && p.location!.toLowerCase().contains(_selectedLocation.toLowerCase()));

      return matchesQuery && matchesLocation;
    }).toList();

    // Extract unique locations for chips (top 4 locations + 'All')
    final uniqueLocations = <String>{};
    for (var p in propertiesState.properties) {
      if (p.location != null && p.location!.isNotEmpty) {
        final parts = p.location!.split(',');
        final city = parts.last.trim();
        if (city.isNotEmpty) {
          uniqueLocations.add(city);
        }
      }
    }
    final locationChips = ['All', ...uniqueLocations.take(4)];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _showAgencySelectorBottomSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            // Company Logo
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                                image: company?.logoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(company!.logoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: company?.logoUrl == null
                                  ? const Icon(Icons.business_rounded, size: 24, color: AppColors.textTertiary)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      company?.name ?? 'Select Agency',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
                                  ],
                                ),
                                Text(
                                  'Exclusive Home Seeker',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                              onPressed: () => context.push('/notifications'),
                            ),
                            if (unreadNotifications > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$unreadNotifications',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_outline_rounded, color: AppColors.textPrimary),
                          onPressed: () {
                            // Navigate to profile branch or screen if configured
                            context.push('/buyer/profile');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Welcome ──
                Text(
                  'Find Your Dream Home',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome, ${profile?.fullName?.split(' ').first ?? 'Client'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Upcoming Visits Card ──
                if (dashboardState.buyerUpcomingInspections.isNotEmpty) ...[
                  _buildUpcomingVisitsCard(context, dashboardState.buyerUpcomingInspections, propertiesState.properties),
                  const SizedBox(height: 28),
                ],

                // ── Search Bar ──
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by title, town, or feature...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Location Chips ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: locationChips.map((loc) {
                      final isSelected = _selectedLocation == loc;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(loc),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedLocation = loc;
                              });
                            }
                          },
                          selectedColor: AppColors.accent,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Property Listings List ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Listings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${availableProperties.length} found',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (availableProperties.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home_work_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No properties match your filters.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: availableProperties.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final property = availableProperties[index];
                      return _buildPropertyCard(context, property);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingVisitsCard(BuildContext context, List<Inspection> upcoming, List<Property> properties) {
    final theme = Theme.of(context);
    final propertiesMap = {for (var p in properties) p.id: p};
    final latestVisit = upcoming.first;
    final property = propertiesMap[latestVisit.propertyId];

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0x1A9C27B0), // Purple with 10% opacity
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_note_rounded, color: Colors.purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Upcoming Inspection Visit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/buyer/inspections'),
                  child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property?.title ?? 'Referred Listing',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${latestVisit.scheduledDate} at ${latestVisit.scheduledTime}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: latestVisit.status == InspectionStatus.confirmed
                        ? Colors.teal.withValues(alpha: 0.1)
                        : Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    latestVisit.status.label,
                    style: TextStyle(
                      color: latestVisit.status == InspectionStatus.confirmed ? Colors.teal : Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Property property) {
    final formattedPrice = '₦${_formatPrice(property.price)}';
    final hasImages = property.images.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/properties/${property.id}'),
      child: Card(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with PageView carousel if multiple
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                children: [
                  if (!hasImages)
                    Container(
                      color: AppColors.border,
                      child: const Center(
                        child: Icon(Icons.home_work_outlined, size: 48, color: AppColors.textTertiary),
                      ),
                    )
                  else if (property.images.length == 1)
                    Image.network(
                      property.images.first,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, e, s) => Container(
                        color: AppColors.border,
                        child: const Icon(Icons.broken_image_outlined, size: 40),
                      ),
                    )
                  else
                    PageView.builder(
                      itemCount: property.images.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          property.images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, e, s) => Container(
                            color: AppColors.border,
                            child: const Icon(Icons.broken_image_outlined, size: 40),
                          ),
                        );
                      },
                    ),
                  // Price Badge on top of image
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formattedPrice,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location ?? 'No location provided',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (property.description != null && property.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      property.description!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  String _formatPrice(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(2)}B';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(2)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(2);
  }
}


