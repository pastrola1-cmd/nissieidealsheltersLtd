import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

@immutable
class Property {
  final String id;
  final String companyId;
  final String title;
  final String? description;
  final String? location;
  final double price;
  final PropertyStatus status;
  final List<String> images;
  final String? videoUrl;
  final String? assignedPartnerId;
  final String? createdBy;
  final CommissionType commissionType;
  final double commissionValue;
  final String? targetAudience;
  final List<String>? documents;
  final Map<String, dynamic>? paymentPlans;
  final String listingType; // 'rent', 'sale', 'shortlet'
  final String propertyCategory; // 'apartment', 'flat', 'duplex', 'bungalow', 'self_contain', 'land', 'commercial'
  final int bedrooms;
  final int bathrooms;
  final String city;
  final String stateLocation;
  final String? district;
  final String rentPeriod; // 'year', 'month', 'total'
  final double inspectionFee;
  final bool isMarketplace;
  final bool isVerified;
  final bool shieldedContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Property({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    this.location,
    required this.price,
    required this.status,
    required this.images,
    this.videoUrl,
    this.assignedPartnerId,
    this.createdBy,
    required this.commissionType,
    required this.commissionValue,
    this.targetAudience,
    this.documents,
    this.paymentPlans,
    this.listingType = 'sale',
    this.propertyCategory = 'apartment',
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.city = 'Abuja',
    this.stateLocation = 'FCT',
    this.district,
    this.rentPeriod = 'total',
    this.inspectionFee = 3000.0,
    this.isMarketplace = true,
    this.isVerified = true,
    this.shieldedContact = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRent => listingType == 'rent';
  bool get isSale => listingType == 'sale';
  bool get isNissieEstate => !isMarketplace;

  String get displayPrice {
    if (price <= 0) {
      return 'Contact for Price';
    }
    if (price >= 1000000) {
      final m = price / 1000000;
      final formattedM = m == m.roundToDouble() ? m.toInt().toString() : m.toStringAsFixed(1);
      return isRent ? '₦${formattedM}M / $rentPeriod' : '₦${formattedM}M';
    }
    final grouped = NumberFormat('#,###').format(price.round());
    return isRent ? '₦$grouped / $rentPeriod' : '₦$grouped';
  }

  String get locationDisplay {
    if (district != null && district!.isNotEmpty && city.isNotEmpty) {
      return '$district, $city';
    }
    return location ?? city;
  }

  /// Dynamically resolved list of title documents for the Nigerian market (falling back to realistic defaults)
  List<String> get verifiedDocuments {
    if (documents != null && documents!.isNotEmpty) {
      return documents!;
    }
    // High-value listings (Lekki, Ikeja, Abuja) typically get C of O
    if (price >= 20000000) {
      return const ['Certificate of Occupancy (C of O)', 'Registered Survey Plan', 'Deed of Assignment'];
    }
    // Standard plots, agricultural land or suburban estates
    return const ['Governor\'s Consent', 'Deed of Assignment', 'Approved Estate Layout Layout'];
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String;
    final location = json['location'] as String?;
    final isMarketplaceVal = json['is_marketplace'] as bool? ?? false;

    // Detect city from location if not explicitly provided
    String city = json['city'] as String? ?? 'Abuja';
    if (json['city'] == null && location != null) {
      if (location.toLowerCase().contains('lagos')) {
        city = 'Lagos';
      } else {
        city = 'Abuja';
      }
    }

    // Infer category and bedrooms intelligently from title/location
    final category = _inferCategory(title, json['property_category'] as String?);
    final beds = _inferBedrooms(title, json['bedrooms'] as int?);

    return Property(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: title,
      description: json['description'] as String?,
      location: location,
      price: (json['price'] as num).toDouble(),
      status: PropertyStatus.fromString(json['status'] as String),
      images: List<String>.from(json['images'] ?? []),
      videoUrl: json['video_url'] as String?,
      assignedPartnerId: json['assigned_partner_id'] as String?,
      createdBy: json['created_by'] as String?,
      commissionType: CommissionType.fromString(json['commission_type'] as String? ?? 'percentage'),
      commissionValue: (json['commission_value'] as num? ?? 5.0).toDouble(),
      targetAudience: json['target_audience'] as String?,
      documents: json['documents'] != null ? List<String>.from(json['documents']) : null,
      paymentPlans: json['payment_plans'] as Map<String, dynamic>?,
      listingType: json['listing_type'] as String? ?? 'sale',
      propertyCategory: category,
      bedrooms: beds,
      bathrooms: json['bathrooms'] as int? ?? (beds > 0 ? beds : 0),
      city: city,
      stateLocation: json['state'] as String? ?? (city == 'Lagos' ? 'Lagos' : 'FCT'),
      district: json['district'] as String? ?? (location != null ? location.split(',').first.trim() : null),
      rentPeriod: json['rent_period'] as String? ?? (json['listing_type'] == 'rent' ? 'year' : 'total'),
      inspectionFee: (json['inspection_fee'] as num? ?? (isMarketplaceVal ? 3000.0 : 0.0)).toDouble(),
      isMarketplace: isMarketplaceVal,
      isVerified: json['is_verified'] as bool? ?? true,
      shieldedContact: json['shielded_contact'] as bool? ?? isMarketplaceVal,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static String _inferCategory(String title, String? category) {
    if (category != null && category.isNotEmpty && category != 'apartment') return category;
    final t = title.toLowerCase();
    if (t.contains('duplex')) return 'duplex';
    if (t.contains('bungalow')) return 'bungalow';
    if (t.contains('plaza') || t.contains('shopping') || t.contains('commercial') || t.contains('office')) return 'commercial';
    if (t.contains('estate') || t.contains('plot') || t.contains('land')) return 'land';
    if (t.contains('self') || t.contains('mini')) return 'self_contain';
    return category ?? 'apartment';
  }

  static int _inferBedrooms(String title, int? beds) {
    if (beds != null && beds > 0) return beds;
    final t = title.toLowerCase();
    if (t.contains('1 bed') || t.contains('1-bed')) return 1;
    if (t.contains('2 bed') || t.contains('2-bed') || t.contains('semi-detached')) return 2;
    if (t.contains('3 bed') || t.contains('3-bed')) return 3;
    if (t.contains('4 bed') || t.contains('4-bed') || t.contains('terrace')) return 4;
    if (t.contains('5 bed') || t.contains('5-bed') || t.contains('detached')) return 5;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'description': description,
      'location': location,
      'price': price,
      'status': status.value,
      'images': images,
      'video_url': videoUrl,
      'assigned_partner_id': assignedPartnerId,
      'created_by': createdBy,
      'commission_type': commissionType.value,
      'commission_value': commissionValue,
      'target_audience': targetAudience,
      'documents': documents,
      'payment_plans': paymentPlans,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Property copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    String? location,
    double? price,
    PropertyStatus? status,
    List<String>? images,
    String? videoUrl,
    String? assignedPartnerId,
    String? createdBy,
    CommissionType? commissionType,
    double? commissionValue,
    Object? targetAudience = const Object(),
    List<String>? documents,
    Map<String, dynamic>? paymentPlans,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      price: price ?? this.price,
      status: status ?? this.status,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
      assignedPartnerId: assignedPartnerId ?? this.assignedPartnerId,
      createdBy: createdBy ?? this.createdBy,
      commissionType: commissionType ?? this.commissionType,
      commissionValue: commissionValue ?? this.commissionValue,
      targetAudience: targetAudience == const Object()
          ? this.targetAudience
          : (targetAudience as String?),
      documents: documents ?? this.documents,
      paymentPlans: paymentPlans ?? this.paymentPlans,
      listingType: listingType ?? this.listingType,
      propertyCategory: propertyCategory ?? this.propertyCategory,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      city: city ?? this.city,
      stateLocation: stateLocation ?? this.stateLocation,
      district: district ?? this.district,
      rentPeriod: rentPeriod ?? this.rentPeriod,
      inspectionFee: inspectionFee ?? this.inspectionFee,
      isMarketplace: isMarketplace ?? this.isMarketplace,
      isVerified: isVerified ?? this.isVerified,
      shieldedContact: shieldedContact ?? this.shieldedContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
