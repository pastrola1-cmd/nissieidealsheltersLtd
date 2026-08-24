import 'package:flutter/foundation.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

@immutable
class Inspection {
  final String id;
  final String companyId;
  final String? propertyId;
  final String? leadId;
  final String? buyerId;
  final String? partnerId;
  final String scheduledDate;
  final String scheduledTime;
  final InspectionStatus status;
  final String? notes;
  final String? photoUrl;
  final double? inspectionLat;
  final double? inspectionLng;
  final DateTime? completedAt;
  final String? clientFeedback;
  final bool isVerified;
  final DateTime createdAt;

  const Inspection({
    required this.id,
    required this.companyId,
    this.propertyId,
    this.leadId,
    this.buyerId,
    this.partnerId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    this.notes,
    this.photoUrl,
    this.inspectionLat,
    this.inspectionLng,
    this.completedAt,
    this.clientFeedback,
    this.isVerified = false,
    required this.createdAt,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      propertyId: json['property_id'] as String?,
      leadId: json['lead_id'] as String?,
      buyerId: json['buyer_id'] as String?,
      partnerId: json['partner_id'] as String?,
      scheduledDate: json['scheduled_date'] as String,
      scheduledTime: json['scheduled_time'] as String,
      status: InspectionStatus.fromString(json['status'] as String),
      notes: json['notes'] as String?,
      photoUrl: json['photo_url'] as String?,
      inspectionLat: (json['inspection_lat'] as num?)?.toDouble(),
      inspectionLng: (json['inspection_lng'] as num?)?.toDouble(),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      clientFeedback: json['client_feedback'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'property_id': propertyId,
      'lead_id': leadId,
      'buyer_id': buyerId,
      'partner_id': partnerId,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'status': status.value,
      'notes': notes,
      'photo_url': photoUrl,
      'inspection_lat': inspectionLat,
      'inspection_lng': inspectionLng,
      'completed_at': completedAt?.toIso8601String(),
      'client_feedback': clientFeedback,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Inspection copyWith({
    String? id,
    String? companyId,
    String? propertyId,
    String? leadId,
    String? buyerId,
    String? partnerId,
    String? scheduledDate,
    String? scheduledTime,
    InspectionStatus? status,
    String? notes,
    String? photoUrl,
    double? inspectionLat,
    double? inspectionLng,
    DateTime? completedAt,
    String? clientFeedback,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return Inspection(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      propertyId: propertyId ?? this.propertyId,
      leadId: leadId ?? this.leadId,
      buyerId: buyerId ?? this.buyerId,
      partnerId: partnerId ?? this.partnerId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      inspectionLat: inspectionLat ?? this.inspectionLat,
      inspectionLng: inspectionLng ?? this.inspectionLng,
      completedAt: completedAt ?? this.completedAt,
      clientFeedback: clientFeedback ?? this.clientFeedback,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
