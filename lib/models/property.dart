import 'package:flutter/foundation.dart';
import 'package:ppn/core/enums/enums.dart';

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
    required this.createdAt,
    required this.updatedAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      price: (json['price'] as num).toDouble(),
      status: PropertyStatus.fromString(json['status'] as String),
      images: List<String>.from(json['images'] ?? []),
      videoUrl: json['video_url'] as String?,
      assignedPartnerId: json['assigned_partner_id'] as String?,
      createdBy: json['created_by'] as String?,
      commissionType: CommissionType.fromString(json['commission_type'] as String? ?? 'percentage'),
      commissionValue: (json['commission_value'] as num? ?? 5.0).toDouble(),
      targetAudience: json['target_audience'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
