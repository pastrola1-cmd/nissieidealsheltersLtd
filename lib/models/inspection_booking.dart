import 'package:flutter/foundation.dart';

enum InspectionEscrowStatus {
  pendingPayment,
  paidEscrow,
  agentAssigned,
  completed,
  cancelled,
  disputed;

  String get value {
    switch (this) {
      case InspectionEscrowStatus.pendingPayment:
        return 'pending_payment';
      case InspectionEscrowStatus.paidEscrow:
        return 'paid_escrow';
      case InspectionEscrowStatus.agentAssigned:
        return 'agent_assigned';
      case InspectionEscrowStatus.completed:
        return 'completed';
      case InspectionEscrowStatus.cancelled:
        return 'cancelled';
      case InspectionEscrowStatus.disputed:
        return 'disputed';
    }
  }

  static InspectionEscrowStatus fromString(String value) {
    return InspectionEscrowStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InspectionEscrowStatus.pendingPayment,
    );
  }
}

@immutable
class InspectionBooking {
  final String id;
  final String propertyId;
  final String? renterId;
  final String renterName;
  final String renterPhone;
  final String? renterEmail;
  final String? agentId;
  final DateTime scheduledDate;
  final String scheduledTime;
  final double feeAmount;
  final double agentPayoutAmount;
  final double platformFeeAmount;
  final String completionPin;
  final InspectionEscrowStatus status;
  final DateTime? escrowReleasedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InspectionBooking({
    required this.id,
    required this.propertyId,
    this.renterId,
    required this.renterName,
    required this.renterPhone,
    this.renterEmail,
    this.agentId,
    required this.scheduledDate,
    required this.scheduledTime,
    this.feeAmount = 3000.0,
    this.agentPayoutAmount = 2000.0,
    this.platformFeeAmount = 1000.0,
    required this.completionPin,
    this.status = InspectionEscrowStatus.pendingPayment,
    this.escrowReleasedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InspectionBooking.fromJson(Map<String, dynamic> json) {
    return InspectionBooking(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      renterId: json['renter_id'] as String?,
      renterName: json['renter_name'] as String,
      renterPhone: json['renter_phone'] as String,
      renterEmail: json['renter_email'] as String?,
      agentId: json['agent_id'] as String?,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: json['scheduled_time'] as String,
      feeAmount: (json['fee_amount'] as num? ?? 3000.0).toDouble(),
      agentPayoutAmount: (json['agent_payout_amount'] as num? ?? 2000.0).toDouble(),
      platformFeeAmount: (json['platform_fee_amount'] as num? ?? 1000.0).toDouble(),
      completionPin: json['completion_pin'] as String,
      status: InspectionEscrowStatus.fromString(json['status'] as String? ?? 'pending_payment'),
      escrowReleasedAt: json['escrow_released_at'] != null ? DateTime.parse(json['escrow_released_at'] as String) : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'renter_id': renterId,
      'renter_name': renterName,
      'renter_phone': renterPhone,
      'renter_email': renterEmail,
      'agent_id': agentId,
      'scheduled_date': scheduledDate.toIso8601String().split('T').first,
      'scheduled_time': scheduledTime,
      'fee_amount': feeAmount,
      'agent_payout_amount': agentPayoutAmount,
      'platform_fee_amount': platformFeeAmount,
      'completion_pin': completionPin,
      'status': status.value,
      'escrow_released_at': escrowReleasedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
