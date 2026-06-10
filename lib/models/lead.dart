import 'package:flutter/foundation.dart';
import 'package:ppn/core/enums/enums.dart';

@immutable
class Lead {
  final String id;
  final String companyId;
  final String? propertyId;
  final String? partnerId;
  final String? buyerId;
  final String buyerName;
  final String buyerPhone;
  final String? buyerEmail;
  final String sourceChannel;
  final LeadStage stage;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lead({
    required this.id,
    required this.companyId,
    this.propertyId,
    this.partnerId,
    this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    this.buyerEmail,
    required this.sourceChannel,
    required this.stage,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      propertyId: json['property_id'] as String?,
      partnerId: json['partner_id'] as String?,
      buyerId: json['buyer_id'] as String?,
      buyerName: json['buyer_name'] as String,
      buyerPhone: json['buyer_phone'] as String,
      buyerEmail: json['buyer_email'] as String?,
      sourceChannel: json['source_channel'] as String? ?? 'whatsapp',
      stage: LeadStage.fromString(json['stage'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'property_id': propertyId,
      'partner_id': partnerId,
      'buyer_id': buyerId,
      'buyer_name': buyerName,
      'buyer_phone': buyerPhone,
      'buyer_email': buyerEmail,
      'source_channel': sourceChannel,
      'stage': stage.value,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Lead copyWith({
    String? id,
    String? companyId,
    String? propertyId,
    String? partnerId,
    String? buyerId,
    String? buyerName,
    String? buyerPhone,
    String? buyerEmail,
    String? sourceChannel,
    LeadStage? stage,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      propertyId: propertyId ?? this.propertyId,
      partnerId: partnerId ?? this.partnerId,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      sourceChannel: sourceChannel ?? this.sourceChannel,
      stage: stage ?? this.stage,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
