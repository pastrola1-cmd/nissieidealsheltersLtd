import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';
import 'package:nissie_ideal_shelters/providers/dashboard_provider.dart';
import 'package:nissie_ideal_shelters/providers/inspection_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
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
  Set<String> _wishlistPropertyIds = {};

  @override
  void initState() {
    super.initState();
    _loadWishlist();
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

  Future<void> _loadWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('buyer_wishlist');
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr);
        if (mounted) {
          setState(() {
            _wishlistPropertyIds = list.cast<String>().toSet();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  Future<void> _toggleWishlist(String propertyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (_wishlistPropertyIds.contains(propertyId)) {
          _wishlistPropertyIds.remove(propertyId);
        } else {
          _wishlistPropertyIds.add(propertyId);
        }
      });
      await prefs.setString('buyer_wishlist', json.encode(_wishlistPropertyIds.toList()));
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
    }
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
    final inspectionsState = ref.watch(inspectionProvider);
    final leadsState = ref.watch(leadProvider);

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
                        // Wishlist Badge Icon Button
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: Icon(
                                _wishlistPropertyIds.isNotEmpty ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _wishlistPropertyIds.isNotEmpty ? AppColors.error : AppColors.textPrimary,
                              ),
                              tooltip: 'My Wishlist',
                              onPressed: () {
                                if (_wishlistPropertyIds.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Your wishlist is currently empty. Tap the heart on any property to save it!')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Wishlist contains ${_wishlistPropertyIds.length} saved properties.')),
                                  );
                                }
                              },
                            ),
                            if (_wishlistPropertyIds.isNotEmpty)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${_wishlistPropertyIds.length}',
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

                // ── Journey Progress Tracker ──
                _buildJourneyProgressTracker(context, inspectionsState.inspections, leadsState.leads),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final defaultPrice = availableProperties.firstOrNull?.price ?? 15000000.0;
          _showPaymentPlanCalculatorBottomSheet(defaultPrice);
        },
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.calculate_rounded),
        label: const Text('Payment Calculator', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  // Wishlist Toggle Button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _wishlistPropertyIds.contains(property.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _wishlistPropertyIds.contains(property.id) ? AppColors.error : Colors.white,
                          size: 20,
                        ),
                        onPressed: () => _toggleWishlist(property.id),
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

  Widget _buildJourneyProgressTracker(BuildContext context, List<Inspection> inspections, List<Lead> leads) {
    final buyerId = ref.watch(authProvider).profile?.id;
    final userInspections = inspections.where((i) => i.buyerId == buyerId).toList();
    final userLeads = leads.where((l) => l.buyerId == buyerId).toList();

    final step1Done = true; // Logged in & browsing
    final step2Done = userInspections.isNotEmpty;
    final step3Done = userLeads.any((l) => l.stage == LeadStage.negotiation || l.stage == LeadStage.closed);
    final step4Done = userLeads.any((l) => l.stage == LeadStage.closed);

    final steps = [
      _JourneyStep('Browse', step1Done, 1),
      _JourneyStep('Inspect', step2Done, 2),
      _JourneyStep('Offer', step3Done, 3),
      _JourneyStep('Purchase', step4Done, 4),
    ];

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Your Home Buying Journey',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: steps.map((s) {
                final isDone = s.isDone;
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? AppColors.success : AppColors.background,
                          border: Border.all(color: isDone ? AppColors.success : AppColors.border),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : Text(
                                  '${s.stepNum}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                          color: isDone ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentPlanCalculatorBottomSheet(double initialPrice) {
    final format = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PaymentCalculatorDialog(initialPrice: initialPrice, format: format);
      },
    );
  }
}

class _JourneyStep {
  final String label;
  final bool isDone;
  final int stepNum;
  _JourneyStep(this.label, this.isDone, this.stepNum);
}

class _PaymentCalculatorDialog extends StatefulWidget {
  final double initialPrice;
  final NumberFormat format;

  const _PaymentCalculatorDialog({required this.initialPrice, required this.format});

  @override
  State<_PaymentCalculatorDialog> createState() => _PaymentCalculatorDialogState();
}

class _PaymentCalculatorDialogState extends State<_PaymentCalculatorDialog> {
  late TextEditingController _priceController;
  double _depositPercent = 20.0;
  int _durationMonths = 12;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.initialPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(_priceController.text) ?? widget.initialPrice;
    final depositAmount = price * (_depositPercent / 100);
    final loanAmount = (price - depositAmount).clamp(0.0, double.infinity);
    final monthlyPayment = loanAmount / _durationMonths;
    final totalPayable = (monthlyPayment * _durationMonths) + depositAmount;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calculate_rounded, color: AppColors.accent, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Payment Plan Calculator',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Property Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Initial Deposit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                Text('${_depositPercent.toStringAsFixed(0)}% (${widget.format.format(depositAmount)})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 12)),
              ],
            ),
            Slider(
              value: _depositPercent,
              min: 10.0,
              max: 50.0,
              divisions: 8,
              activeColor: AppColors.accent,
              onChanged: (val) => setState(() => _depositPercent = val),
            ),
            const SizedBox(height: 16),

            const Text('Payment Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _durationMonths,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
              items: const [
                DropdownMenuItem(value: 6, child: Text('6 Months')),
                DropdownMenuItem(value: 12, child: Text('12 Months (1 Year)')),
                DropdownMenuItem(value: 18, child: Text('18 Months')),
                DropdownMenuItem(value: 24, child: Text('24 Months (2 Years)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _durationMonths = val);
              },
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Monthly Payment:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(widget.format.format(monthlyPayment), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount Payable:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(widget.format.format(totalPayable), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


