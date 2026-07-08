import 'package:flutter/foundation.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

@immutable
class Transaction {
  final String id;
  final String companyId;
  final String? partnerId;
  final String? commissionId;
  final TransactionType type;
  final double amount;
  final double? balanceAfter;
  final String? description;
  final TransactionStatus status;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.companyId,
    this.partnerId,
    this.commissionId,
    required this.type,
    required this.amount,
    this.balanceAfter,
    this.description,
    this.status = TransactionStatus.completed,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      partnerId: json['partner_id'] as String?,
      commissionId: json['commission_id'] as String?,
      type: TransactionType.fromString(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: json['balance_after'] != null ? (json['balance_after'] as num).toDouble() : null,
      description: json['description'] as String?,
      status: json['status'] != null
          ? TransactionStatus.fromString(json['status'] as String)
          : TransactionStatus.completed,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'partner_id': partnerId,
      'commission_id': commissionId,
      'type': type.value,
      'amount': amount,
      'balance_after': balanceAfter,
      'description': description,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? companyId,
    String? partnerId,
    String? commissionId,
    TransactionType? type,
    double? amount,
    double? balanceAfter,
    String? description,
    TransactionStatus? status,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      partnerId: partnerId ?? this.partnerId,
      commissionId: commissionId ?? this.commissionId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
