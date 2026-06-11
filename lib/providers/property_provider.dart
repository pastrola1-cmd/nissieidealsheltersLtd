import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/auth_state.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/core/enums/enums.dart';

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
  late final SupabaseService _supabaseService;
  String? _loadedCompanyId;

  @override
  PropertyState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final authState = ref.watch(authProvider);
    final companyId = authState.profile?.companyId;

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
  }) async {
    final profile = ref.read(authProvider).profile;
    final companyId = profile?.companyId;
    if (companyId == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Company ID not found.');
      return false;
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
        'updated_at': DateTime.now().toIso8601String(),
      };

      final updatedRaw = await _supabaseService.update('properties', id, updateData);
      final updatedProperty = Property.fromJson(updatedRaw);

      // 3. Update state
      final currentList = state.properties.map((p) => p.id == id ? updatedProperty : p).toList();
      state = PropertyState(properties: currentList, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteProperty(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.delete('properties', id);
      final currentList = state.properties.where((p) => p.id != id).toList();
      state = PropertyState(properties: currentList, isLoading: false);
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
