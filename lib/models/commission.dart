import 'package:flutter/foundation.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

@immutable
class Commission {
  final String id;
  final String companyId;
  final String? leadId;
  final String? partnerId;
  final String? propertyId;
  final double salePrice;
  final double? commissionRate;
  final double commissionAmount;
  final CommissionStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  const Commission({
    required this.id,
    required this.companyId,
    this.leadId,
    this.partnerId,
    this.propertyId,
    required this.salePrice,
    this.commissionRate,
    required this.commissionAmount,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });

  factory Commission.fromJson(Map<String, dynamic> json) {
    return Commission(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      leadId: json['lead_id'] as String?,
      partnerId: json['partner_id'] as String?,
      propertyId: json['property_id'] as String?,
      salePrice: (json['sale_price'] as num).toDouble(),
      commissionRate: json['commission_rate'] != null ? (json['commission_rate'] as num).toDouble() : null,
      commissionAmount: (json['commission_amount'] as num).toDouble(),
      status: CommissionStatus.fromString(json['status'] as String),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'lead_id': leadId,
      'partner_id': partnerId,
      'property_id': propertyId,
      'sale_price': salePrice,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'status': status.value,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Commission copyWith({
    String? id,
    String? companyId,
    String? leadId,
    String? partnerId,
    String? propertyId,
    double? salePrice,
    double? commissionRate,
    double? commissionAmount,
    CommissionStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
  }) {
    return Commission(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      leadId: leadId ?? this.leadId,
      partnerId: partnerId ?? this.partnerId,
      propertyId: propertyId ?? this.propertyId,
      salePrice: salePrice ?? this.salePrice,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
