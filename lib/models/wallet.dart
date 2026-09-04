import 'package:flutter/foundation.dart';

enum WalletTxType {
  credit,
  debit,
  escrowHold,
  escrowRelease,
  withdrawal,
  inspectionFee,
  commission;

  String get value {
    switch (this) {
      case WalletTxType.credit:
        return 'credit';
      case WalletTxType.debit:
        return 'debit';
      case WalletTxType.escrowHold:
        return 'escrow_hold';
      case WalletTxType.escrowRelease:
        return 'escrow_release';
      case WalletTxType.withdrawal:
        return 'withdrawal';
      case WalletTxType.inspectionFee:
        return 'inspection_fee';
      case WalletTxType.commission:
        return 'commission';
    }
  }

  static WalletTxType fromString(String value) {
    return WalletTxType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WalletTxType.credit,
    );
  }
}

@immutable
class Wallet {
  final String id;
  final String userId;
  final String? companyId;
  final double balance;
  final double ledgerBalance;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wallet({
    required this.id,
    required this.userId,
    this.companyId,
    required this.balance,
    this.ledgerBalance = 0.0,
    this.currency = 'NGN',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      companyId: json['company_id'] as String?,
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
      ledgerBalance: (json['ledger_balance'] as num? ?? 0.0).toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'balance': balance,
      'ledger_balance': ledgerBalance,
      'currency': currency,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

@immutable
class WalletTransaction {
  final String id;
  final String walletId;
  final String? userId;
  final double amount;
  final WalletTxType type;
  final String direction; // 'inflow' or 'outflow'
  final String reference;
  final String? description;
  final String status; // 'pending', 'completed', 'failed'
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.walletId,
    this.userId,
    required this.amount,
    required this.type,
    required this.direction,
    required this.reference,
    this.description,
    this.status = 'completed',
    this.metadata,
    required this.createdAt,
  });

  bool get isInflow => direction == 'inflow';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      userId: json['user_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      type: WalletTxType.fromString(json['type'] as String? ?? 'credit'),
      direction: json['direction'] as String? ?? 'inflow',
      reference: json['reference'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'completed',
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'user_id': userId,
      'amount': amount,
      'type': type.value,
      'direction': direction,
      'reference': reference,
      'description': description,
      'status': status,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
