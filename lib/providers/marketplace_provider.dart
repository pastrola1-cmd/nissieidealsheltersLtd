import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class MarketplaceFilter {
  final String listingType; // 'all', 'rent', 'sale', 'nissie_estates'
  final String selectedCity; // 'All', 'Abuja', 'Lagos', ...
  final String searchQuery;
  final String selectedCategory; // 'all', 'apartment', 'duplex', 'bungalow', 'self_contain', 'land'
  final int minBedrooms;
  final double? minPrice;
  final double? maxPrice;
  final String selectedPriceRange;
  final String sortOrder; // 'newest', 'price_asc', 'price_desc'

  const MarketplaceFilter({
    this.listingType = 'all',
    this.selectedCity = 'All',
    this.searchQuery = '',
    this.selectedCategory = 'all',
    this.minBedrooms = 0,
    this.minPrice,
    this.maxPrice,
    this.selectedPriceRange = 'all',
    this.sortOrder = 'newest',
  });

  MarketplaceFilter copyWith({
    String? listingType,
    String? selectedCity,
    String? searchQuery,
    String? selectedCategory,
    int? minBedrooms,
    double? minPrice,
    double? maxPrice,
    String? selectedPriceRange,
    String? sortOrder,
    bool clearPrice = false,
  }) {
    return MarketplaceFilter(
      listingType: listingType ?? this.listingType,
      selectedCity: selectedCity ?? this.selectedCity,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      minBedrooms: minBedrooms ?? this.minBedrooms,
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      selectedPriceRange: selectedPriceRange ?? this.selectedPriceRange,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class MarketplaceState {
  final List<Property> allProperties;
  final MarketplaceFilter filter;
  final bool isLoading;
  final String? errorMessage;
  final List<InspectionBooking> myBookings;

  const MarketplaceState({
    this.allProperties = const [],
    this.filter = const MarketplaceFilter(),
    this.isLoading = false,
    this.errorMessage,
    this.myBookings = const [],
  });

  List<Property> get filteredProperties {
    final list = allProperties.where((prop) {
      // Approval gate: agent/landlord listings go live only after Nissie verifies.
      if (!prop.isVerified) return false;
      // Listing type filter
      if (filter.listingType == 'rent' && !prop.isRent) return false;
      if (filter.listingType == 'sale' && !prop.isSale) return false;
      if (filter.listingType == 'nissie_estates' && !prop.isNissieEstate) return false;

      // City filter
      if (filter.selectedCity != 'All' && !prop.city.toLowerCase().contains(filter.selectedCity.toLowerCase())) {
        return false;
      }

      // Category filter
      if (filter.selectedCategory != 'all' && prop.propertyCategory != filter.selectedCategory) {
        return false;
      }

      // Bedrooms filter
      if (filter.minBedrooms > 0 && prop.bedrooms < filter.minBedrooms) {
        return false;
      }

      // Min & Max price filter
      if (filter.minPrice != null && prop.price > 0 && prop.price < filter.minPrice!) {
        return false;
      }
      if (filter.maxPrice != null && prop.price > 0 && prop.price > filter.maxPrice!) {
        return false;
      }

      // Search query
      if (filter.searchQuery.trim().isNotEmpty) {
        final q = filter.searchQuery.toLowerCase().trim();
        final matchTitle = prop.title.toLowerCase().contains(q);
        final matchDistrict = (prop.district ?? '').toLowerCase().contains(q);
        final matchLocation = (prop.location ?? '').toLowerCase().contains(q);
        final matchCity = prop.city.toLowerCase().contains(q);
        if (!matchTitle && !matchDistrict && !matchLocation && !matchCity) {
          return false;
        }
      }

      return true;
    }).toList();
    switch (filter.sortOrder) {
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'newest':
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return list;
  }

  MarketplaceState copyWith({
    List<Property>? allProperties,
    MarketplaceFilter? filter,
    bool? isLoading,
    String? errorMessage,
    List<InspectionBooking>? myBookings,
  }) {
    return MarketplaceState(
      allProperties: allProperties ?? this.allProperties,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      myBookings: myBookings ?? this.myBookings,
    );
  }
}

class MarketplaceNotifier extends Notifier<MarketplaceState> {
  late SupabaseService _supabaseService;

  @override
  MarketplaceState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    Future.microtask(() => loadMarketplace());
    return const MarketplaceState();
  }

  /// Loads ONLY real Nissie properties from Supabase. No demo data.
  Future<void> loadMarketplace() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dbProperties = await _supabaseService.getProperties();
      state = state.copyWith(allProperties: dbProperties, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        allProperties: const [],
        isLoading: false,
        errorMessage: 'Could not reach database. Pull to retry.',
      );
    }
  }

  void setListingType(String type) {
    // Clear stale price range when switching rent/sale — keys are disjoint.
    final cleared = state.filter.selectedPriceRange != 'all' ? true : false;
    var next = state.filter.copyWith(listingType: type);
    if (cleared) {
      next = next.copyWith(selectedPriceRange: 'all', clearPrice: true);
    }
    state = state.copyWith(filter: next);
  }

  void setCity(String city) {
    state = state.copyWith(filter: state.filter.copyWith(selectedCity: city));
  }

  void setSearchQuery(String query) {
    state = state.copyWith(filter: state.filter.copyWith(searchQuery: query));
  }

  void setCategory(String category) {
    state = state.copyWith(filter: state.filter.copyWith(selectedCategory: category));
  }

  void setBedrooms(int bedrooms) {
    state = state.copyWith(filter: state.filter.copyWith(minBedrooms: bedrooms));
  }

  void setPriceRange({double? min, double? max, String rangeKey = 'all'}) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        minPrice: min,
        maxPrice: max,
        selectedPriceRange: rangeKey,
        clearPrice: rangeKey == 'all',
      ),
    );
  }

  void resetFilters() {
    state = state.copyWith(filter: const MarketplaceFilter());
  }

  void setSortOrder(String order) {
    state = state.copyWith(filter: state.filter.copyWith(sortOrder: order));
  }

  /// Books an inspection with escrow protection and a 4-digit verification PIN.
  /// NOTE: PIN is issued client-side for UX only. Server RPC must re-validate
  /// PIN + booking + status before any payout (see settle_inspection_pin_payout).
  InspectionBooking bookInspection({
    required String propertyId,
    String? renterId,
    required String renterName,
    required String renterPhone,
    String? renterEmail,
    required DateTime date,
    required String time,
    String? notes,
    double feeAmount = 3000.0,
  }) {
    final random = Random.secure();
    // Ensure uniqueness within local session (1/9000 collision space).
    final existingPins = state.myBookings.map((b) => b.completionPin).toSet();
    String pin;
    do {
      pin = (1000 + random.nextInt(9000)).toString();
    } while (existingPins.contains(pin));

    final booking = InspectionBooking(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(9999)}',
      propertyId: propertyId,
      renterId: renterId,
      renterName: renterName,
      renterPhone: renterPhone,
      renterEmail: renterEmail,
      scheduledDate: date,
      scheduledTime: time,
      completionPin: pin,
      feeAmount: feeAmount,
      agentPayoutAmount: feeAmount <= 0 ? 0 : 2000.0,
      platformFeeAmount: feeAmount <= 0 ? 0 : 1000.0,
      status: feeAmount <= 0
          ? InspectionEscrowStatus.agentAssigned
          : InspectionEscrowStatus.paidEscrow,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final updatedBookings = [booking, ...state.myBookings];
    state = state.copyWith(myBookings: updatedBookings);
    return booking;
  }

  /// Retrieves all inspection bookings relevant to a given user
  List<InspectionBooking> getBookingsForUser({
    String? userId,
    String? email,
    String? phone,
  }) {
    return state.myBookings.where((b) {
      if (userId != null && b.renterId == userId) return true;
      if (email != null && email.isNotEmpty && b.renterEmail != null && b.renterEmail!.toLowerCase() == email.toLowerCase()) return true;
      if (phone != null && phone.isNotEmpty && b.renterPhone.replaceAll(' ', '') == phone.replaceAll(' ', '')) return true;
      return userId == null && email == null && phone == null;
    }).toList();
  }

  void addProperty(Property property) {
    final existing = state.allProperties.where((p) => p.id != property.id).toList();
    state = state.copyWith(allProperties: [property, ...existing]);
  }

  void updatePropertyPrice(String id, double price) {
    final updated = state.allProperties
        .map((p) => p.id == id ? p.copyWith(price: price, updatedAt: DateTime.now()) : p)
        .toList();
    state = state.copyWith(allProperties: updated);
  }

  /// Swaps a local booking id for its server UUID after DB insert,
  /// so escrow verify / payout RPCs reference a real row.
  void replaceBookingId(String oldId, String newId) {
    final updated = state.myBookings
        .map((b) => b.id == oldId ? b.copyWith(id: newId) : b)
        .toList();
    state = state.copyWith(myBookings: updated);
  }

}

final marketplaceProvider = NotifierProvider<MarketplaceNotifier, MarketplaceState>(() {
  return MarketplaceNotifier();
});
