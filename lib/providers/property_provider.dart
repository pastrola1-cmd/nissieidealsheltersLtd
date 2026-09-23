import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/marketplace_provider.dart';

class PropertyState {
  final List<Property> properties;
  final bool isLoading;
  final String? errorMessage;

  const PropertyState({
    this.properties = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PropertyState copyWith({
    List<Property>? properties,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PropertyState(
      properties: properties ?? this.properties,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PropertyNotifier extends Notifier<PropertyState> {
  late SupabaseService _supabaseService;
  String? _loadedCompanyId;

  @override
  PropertyState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final companyId = ref.watch(selectedCompanyIdProvider);

    if (companyId != null) {
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() => loadProperties(companyId));
        return const PropertyState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const PropertyState();
    }
  }

  Future<void> loadProperties(String companyId) async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _supabaseService.getProperties(companyId: companyId);
      // Sort by createdAt descending
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = PropertyState(properties: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createProperty({
    required String title,
    String? description,
    String? location,
    required double price,
    required PropertyStatus status,
    required List<Uint8List> imageBytesList,
    required List<String> imageNames,
    String? videoUrl,
    String? assignedPartnerId,
    required CommissionType commissionType,
    required double commissionValue,
    String? targetAudience,
    String listingType = 'sale',
    String propertyCategory = 'apartment',
    int bedrooms = 0,
    int bathrooms = 0,
    String city = 'Abuja',
    String stateLocation = 'FCT',
    String? district,
    String rentPeriod = 'year',
    double inspectionFee = 3000.0,
    bool isMarketplace = true,
    bool isVerified = true,
    bool shieldedContact = true,
  }) async {
    final profile = ref.read(authProvider).profile;
    final companyId = profile?.companyId;
    if (companyId == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Company ID not found.');
      return false;
    }

    final company = ref.read(authProvider).company;
    if (company != null) {
      final plan = company.plan;
      if (state.properties.length >= plan.maxListings) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Listing limit reached. Your plan (${plan.name}) allows up to ${plan.maxListings} listings. Please upgrade your plan or request a dedicated app.',
        );
        return false;
      }
    }

    state = state.copyWith(isLoading: true);
    try {
      // 1. Insert property first to get database generated property ID
      final insertData = {
        'company_id': companyId,
        'title': title,
        'description': description,
        'location': location,
        'price': price,
        'status': status.value,
        'images': <String>[], // Start with empty images list
        'video_url': videoUrl,
        'assigned_partner_id': assignedPartnerId,
        'created_by': profile!.id,
        'commission_type': commissionType.value,
        'commission_value': commissionValue,
        'target_audience': targetAudience,
        'listing_type': listingType,
        'property_category': propertyCategory,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'city': city,
        'state': stateLocation,
        'district': district,
        'rent_period': rentPeriod,
        'inspection_fee': inspectionFee,
        'is_marketplace': isMarketplace,
        'is_verified': isVerified,
        'shielded_contact': shieldedContact,
      };

      final insertedRaw = await _supabaseService.insert('properties', insertData);
      final insertedProperty = Property.fromJson(insertedRaw);
      final propertyId = insertedProperty.id;

      // 2. Upload images if any are selected
      final List<String> uploadedUrls = [];
      for (int i = 0; i < imageBytesList.length; i++) {
        final bytes = imageBytesList[i];
        final name = imageNames[i];
        final extension = name.split('.').last.toLowerCase();
        final path = 'properties/$propertyId/${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
        
        final url = await _supabaseService.uploadFile(
          'company-assets',
          path,
          bytes,
          mimeType: 'image/$extension',
        );
        uploadedUrls.add(url);
      }

      // 3. Update property with uploaded image URLs
      Property finalProperty = insertedProperty;
      if (uploadedUrls.isNotEmpty) {
        final updatedRaw = await _supabaseService.update('properties', propertyId, {
          'images': uploadedUrls,
        });
        finalProperty = Property.fromJson(updatedRaw);
      }

      // 4. Update state
      final currentList = List<Property>.from(state.properties);
      currentList.insert(0, finalProperty);
      state = PropertyState(properties: currentList, isLoading: false);
      try { ref.read(marketplaceProvider.notifier).loadMarketplace(); } catch (_) {}
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateProperty({
    required String id,
    required String title,
    String? description,
    String? location,
    required double price,
    required PropertyStatus status,
    required List<String> existingImages,
    required List<Uint8List> newImageBytesList,
    required List<String> newImageNames,
    String? videoUrl,
    String? assignedPartnerId,
    required CommissionType commissionType,
    required double commissionValue,
    String? targetAudience,
    String? listingType,
    String? propertyCategory,
    int? bedrooms,
    int? bathrooms,
    String? city,
    String? stateLocation,
    String? district,
    String? rentPeriod,
    double? inspectionFee,
    bool? isMarketplace,
    bool? isVerified,
    bool? shieldedContact,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Upload new images if any
      final List<String> uploadedUrls = List<String>.from(existingImages);
      for (int i = 0; i < newImageBytesList.length; i++) {
        final bytes = newImageBytesList[i];
        final name = newImageNames[i];
        final extension = name.split('.').last.toLowerCase();
        final path = 'properties/$id/${DateTime.now().millisecondsSinceEpoch}_new_$i.$extension';
        
        final url = await _supabaseService.uploadFile(
          'company-assets',
          path,
          bytes,
          mimeType: 'image/$extension',
        );
        uploadedUrls.add(url);
      }

      // 2. Update property row
      final updateData = {
        'title': title,
        'description': description,
        'location': location,
        'price': price,
        'status': status.value,
        'images': uploadedUrls,
        'video_url': videoUrl,
        'assigned_partner_id': assignedPartnerId,
        'commission_type': commissionType.value,
        'commission_value': commissionValue,
        'target_audience': targetAudience,
        if (listingType != null) 'listing_type': listingType,
        if (propertyCategory != null) 'property_category': propertyCategory,
        if (bedrooms != null) 'bedrooms': bedrooms,
        if (bathrooms != null) 'bathrooms': bathrooms,
        if (city != null) 'city': city,
        if (stateLocation != null) 'state': stateLocation,
        if (district != null) 'district': district,
        if (rentPeriod != null) 'rent_period': rentPeriod,
        if (inspectionFee != null) 'inspection_fee': inspectionFee,
        if (isMarketplace != null) 'is_marketplace': isMarketplace,
        if (isVerified != null) 'is_verified': isVerified,
        if (shieldedContact != null) 'shielded_contact': shieldedContact,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final updatedRaw = await _supabaseService.update('properties', id, updateData);
      final updatedProperty = Property.fromJson(updatedRaw);

      // 3. Update state
      final currentList = state.properties.map((p) => p.id == id ? updatedProperty : p).toList();
      state = PropertyState(properties: currentList, isLoading: false);
      try { ref.read(marketplaceProvider.notifier).loadMarketplace(); } catch (_) {}
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> setVerified(String id, bool value) async {
    state = state.copyWith(isLoading: true);
    try {
      final updatedRaw = await _supabaseService.update('properties', id, {
        'is_verified': value,
        'updated_at': DateTime.now().toIso8601String(),
      });
      final updatedProperty = Property.fromJson(updatedRaw);
      final currentList = state.properties.map((p) => p.id == id ? updatedProperty : p).toList();
      state = PropertyState(properties: currentList, isLoading: false);
      try { ref.read(marketplaceProvider.notifier).loadMarketplace(); } catch (_) {}
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteProperty(String id) async {    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.delete('properties', id);
      final currentList = state.properties.where((p) => p.id != id).toList();
      state = PropertyState(properties: currentList, isLoading: false);
      try { ref.read(marketplaceProvider.notifier).loadMarketplace(); } catch (_) {}
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final propertyProvider = NotifierProvider<PropertyNotifier, PropertyState>(() {
  return PropertyNotifier();
});
