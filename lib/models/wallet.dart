import 'package:flutter/foundation.dart';

enum WalletTxType {
  credit,
  debit,
  escrowHold,
  escrowRelease,
  withdrawal,
  inspectionFee,
  commission,
  payout,
  platformFee;

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
      case WalletTxType.payout:
        return 'payout';
      case WalletTxType.platformFee:
        return 'platform_fee';
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
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      companyId: json['company_id']?.toString(),
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
      ledgerBalance: (json['ledger_balance'] as num? ?? 0.0).toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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

  Wallet copyWith({
    String? id,
    String? userId,
    String? companyId,
    double? balance,
    double? ledgerBalance,
    String? currency,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      balance: balance ?? this.balance,
      ledgerBalance: ledgerBalance ?? this.ledgerBalance,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
    Map<String, dynamic>? meta;
    if (json['metadata'] != null) {
      if (json['metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['metadata'] as Map);
      }
    }

    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      walletId: json['wallet_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      type: WalletTxType.fromString(json['type'] as String? ?? 'credit'),
      direction: json['direction'] as String? ?? 'inflow',
      reference: json['reference']?.toString() ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'completed',
      metadata: meta,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  WalletTransaction copyWith({
    String? id,
    String? walletId,
    String? userId,
    double? amount,
    WalletTxType? type,
    String? direction,
    String? reference,
    String? description,
    String? status,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      reference: reference ?? this.reference,
      description: description ?? this.description,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
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
