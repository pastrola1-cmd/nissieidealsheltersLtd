import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class MarketplaceFilter {
  final String listingType; // 'all', 'rent', 'sale', 'nissie_estates'
  final String selectedCity; // 'All', 'Abuja', 'Lagos'
  final String searchQuery;
  final String selectedCategory; // 'all', 'apartment', 'duplex', 'bungalow', 'self_contain', 'land'
  final int minBedrooms;
  final double? minPrice;
  final double? maxPrice;
  final String selectedPriceRange;

  const MarketplaceFilter({
    this.listingType = 'all',
    this.selectedCity = 'All',
    this.searchQuery = '',
    this.selectedCategory = 'all',
    this.minBedrooms = 0,
    this.minPrice,
    this.maxPrice,
    this.selectedPriceRange = 'all',
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
    return allProperties.where((prop) {
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
    return MarketplaceState(allProperties: _generateCuratedListings());
  }

  Future<void> loadMarketplace() async {
    try {
      final dbProperties = await _supabaseService.getProperties();
      if (dbProperties.isNotEmpty) {
        // Real Nissie properties from database are prioritized!
        final curatedRentals = _generateCuratedListings().where((c) => c.isMarketplace).toList();
        final existingIds = dbProperties.map((p) => p.id).toSet();
        final merged = [
          ...dbProperties,
          ...curatedRentals.where((c) => !existingIds.contains(c.id)),
        ];
        state = state.copyWith(allProperties: merged, isLoading: false);
      } else {
        state = state.copyWith(allProperties: _generateCuratedListings(), isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(allProperties: _generateCuratedListings(), isLoading: false);
    }
  }

  void setListingType(String type) {
    state = state.copyWith(filter: state.filter.copyWith(listingType: type));
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

  /// Books an inspection with escrow protection and a 4-digit verification PIN
  InspectionBooking bookInspection({
    required String propertyId,
    String? renterId,
    required String renterName,
    required String renterPhone,
    String? renterEmail,
    required DateTime date,
    required String time,
    String? notes,
  }) {
    final random = Random();
    final pin = (1000 + random.nextInt(9000)).toString(); // e.g. "4829"

    final booking = InspectionBooking(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      propertyId: propertyId,
      renterId: renterId,
      renterName: renterName,
      renterPhone: renterPhone,
      renterEmail: renterEmail,
      scheduledDate: date,
      scheduledTime: time,
      completionPin: pin,
      status: InspectionEscrowStatus.paidEscrow,
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
    state = state.copyWith(allProperties: [property, ...state.allProperties]);
  }

  List<Property> _generateCuratedListings() {
    final now = DateTime.now();
    return [
      // 1. Abuja Luxury Rent
      Property(
        id: 'prop_mkt_abj_01',
        companyId: 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        title: 'Exquisite 3-Bedroom Fully Serviced Apartment with Pool',
        description: 'Ultra-modern serviced 3-bedroom apartment located in prime Maitama. Features 24/7 security, central generator, fitted Italian kitchen, swimming pool, gym, and dedicated parking.',
        location: 'Maitama, Abuja',
        price: 7500000.0,
        status: PropertyStatus.available,
        images: const [
          'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 10.0,
        listingType: 'rent',
        propertyCategory: 'apartment',
        bedrooms: 3,
        bathrooms: 3,
        city: 'Abuja',
        stateLocation: 'FCT',
        district: 'Maitama',
        rentPeriod: 'year',
        inspectionFee: 3000.0,
        isMarketplace: true,
        isVerified: true,
        shieldedContact: true,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),

      // 2. Abuja Sale
      Property(
        id: 'prop_mkt_abj_02',
        companyId: 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        title: 'Contemporary 4-Bedroom Terrace Duplex with Room BQ',
        description: 'Newly completed 4-bedroom smart terrace duplex in Guzape with panoramic views of Abuja city. Solar inverter provision, automated gate, all rooms ensuite with walk-in closet.',
        location: 'Guzape Hills, Abuja',
        price: 85000000.0,
        status: PropertyStatus.available,
        images: const [
          'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 5.0,
        listingType: 'sale',
        propertyCategory: 'duplex',
        bedrooms: 4,
        bathrooms: 4,
        city: 'Abuja',
        stateLocation: 'FCT',
        district: 'Guzape',
        rentPeriod: 'total',
        inspectionFee: 3000.0,
        isMarketplace: true,
        isVerified: true,
        shieldedContact: true,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),

      // 3. Lagos Rent
      Property(
        id: 'prop_mkt_lag_01',
        companyId: 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        title: 'Luxury 3-Bedroom Waterfront Apartment with Ocean View',
        description: 'Immaculate 3-bedroom apartment overlooking the Lekki waterfront. Fully fitted open-plan kitchen, state-of-the-art gym, CCTV, high-speed elevator, and 24-hour round-the-clock power.',
        location: 'Lekki Phase 1, Lagos',
        price: 9000000.0,
        status: PropertyStatus.available,
        images: const [
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 10.0,
        listingType: 'rent',
        propertyCategory: 'apartment',
        bedrooms: 3,
        bathrooms: 4,
        city: 'Lagos',
        stateLocation: 'Lagos',
        district: 'Lekki Phase 1',
        rentPeriod: 'year',
        inspectionFee: 3000.0,
        isMarketplace: true,
        isVerified: true,
        shieldedContact: true,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now,
      ),

      // 4. Lagos Sale
      Property(
        id: 'prop_mkt_lag_02',
        companyId: 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        title: 'Modern 4-Bedroom Semi-Detached Smart Home',
        description: 'Top-tier luxury living in Chevron area, Lekki. Smart home automation, stamped concrete floor, fully fitted kitchen with pantry, Bluetooth surround speakers, and Jacuzzi bath.',
        location: 'Chevron Drive, Lekki, Lagos',
        price: 78000000.0,
        status: PropertyStatus.available,
        images: const [
          'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1600566753376-12c8ab7fb75b?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 5.0,
        listingType: 'sale',
        propertyCategory: 'duplex',
        bedrooms: 4,
        bathrooms: 5,
        city: 'Lagos',
        stateLocation: 'Lagos',
        district: 'Lekki',
        rentPeriod: 'total',
        inspectionFee: 3000.0,
        isMarketplace: true,
        isVerified: true,
        shieldedContact: true,
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now,
      ),

      // 5. Affordable Abuja Rent (Gwarinpa)
      Property(
        id: 'prop_mkt_abj_03',
        companyId: 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        title: 'Spacious 2-Bedroom Flat in Gated Residential Estate',
        description: 'Tastefully finished 2-bedroom flat inside a serene and secured estate in Gwarinpa. Tarred access road, constant water supply, prepaid meter, and ample car park.',
        location: 'Gwarinpa Estate, Abuja',
        price: 3200000.0,
        status: PropertyStatus.available,
        images: const [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 10.0,
        listingType: 'rent',
        propertyCategory: 'flat',
        bedrooms: 2,
        bathrooms: 2,
        city: 'Abuja',
        stateLocation: 'FCT',
        district: 'Gwarinpa',
        rentPeriod: 'year',
        inspectionFee: 3000.0,
        isMarketplace: true,
        isVerified: true,
        shieldedContact: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ),

      // 6. Nissie Signature Estate Development (Sale with Installment)
      Property(
        id: 'prop_nissie_dev_01',
        companyId: 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        title: 'Nissie Royal Crest Estate - 500sqm Prime Residential Plot',
        description: 'Official Nissie Ideal Shelters signature development in fast-developing Idu / Karmo corridor. 100% dry table land with Certificate of Occupancy (C of O), perimeter fencing, paved roads, and 12-month flexible installment plans.',
        location: 'Idu District, Abuja',
        price: 18500000.0,
        status: PropertyStatus.available,
        images: const [
          'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 5.0,
        listingType: 'sale',
        propertyCategory: 'land',
        bedrooms: 0,
        bathrooms: 0,
        city: 'Abuja',
        stateLocation: 'FCT',
        district: 'Idu',
        rentPeriod: 'total',
        inspectionFee: 0.0, // Free site inspection for Nissie developer estates
        isMarketplace: false, // Developer signature estate
        isVerified: true,
        shieldedContact: false,
        paymentPlans: const {
          'initial_deposit': 3500000,
          'duration_months': 12,
          'monthly_installment': 1250000,
        },
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now,
      ),

      // 7. Affordable Lagos Rent (Yaba)
      Property(
        id: 'prop_mkt_lag_03',
        companyId: 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
        title: 'Serviced 1-Bedroom Mini Flat / Room & Parlour',
        description: 'Clean and compact 1-bedroom mini flat near commercial hub in Yaba. Prepaid meter, secure compound, borehole water, perfect for young working professionals.',
        location: 'Yaba / Akoka, Lagos',
        price: 1600000.0,
        status: PropertyStatus.available,
        images: const [
          'https://images.unsplash.com/photo-1560185007-cde436f6a4d0?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 10.0,
        listingType: 'rent',
        propertyCategory: 'self_contain',
        bedrooms: 1,
        bathrooms: 1,
        city: 'Lagos',
        stateLocation: 'Lagos',
        district: 'Yaba',
        rentPeriod: 'year',
        inspectionFee: 3000.0,
        isMarketplace: true,
        isVerified: true,
        shieldedContact: true,
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now,
      ),
    ];
  }
}

final marketplaceProvider = NotifierProvider<MarketplaceNotifier, MarketplaceState>(() {
  return MarketplaceNotifier();
});
