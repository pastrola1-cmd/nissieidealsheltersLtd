import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

@immutable
class PaymentMilestone {
  final String id;
  final String paymentPlanId;
  final String companyId;
  final int milestoneNumber;
  final DateTime dueDate;
  final double expectedAmount;
  final double paidAmount;
  final DateTime? paidAt;
  final String status; // 'pending', 'paid', 'overdue', 'partial'
  final String? receiptNumber;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;

  const PaymentMilestone({
    required this.id,
    required this.paymentPlanId,
    required this.companyId,
    required this.milestoneNumber,
    required this.dueDate,
    required this.expectedAmount,
    this.paidAmount = 0.0,
    this.paidAt,
    this.status = 'pending',
    this.receiptNumber,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });

  bool get isPaid => status == 'paid' || paidAmount >= expectedAmount;
  bool get isOverdue => (status == 'overdue' || (status == 'pending' && dueDate.isBefore(DateTime.now()))) && !isPaid;
  bool get isPartial => status == 'partial' || (paidAmount > 0 && paidAmount < expectedAmount);
  bool get isPending => !isPaid && !isOverdue && !isPartial;
  double get remainingAmount => (expectedAmount - paidAmount).clamp(0, double.infinity);

  String get formattedDueDate => DateFormat('MMM d, yyyy').format(dueDate);
  String get formattedPaidAt => paidAt != null ? DateFormat('MMM d, yyyy').format(paidAt!) : '';

  factory PaymentMilestone.fromJson(Map<String, dynamic> json) {
    return PaymentMilestone(
      id: json['id'] as String,
      paymentPlanId: json['payment_plan_id'] as String,
      companyId: json['company_id'] as String,
      milestoneNumber: json['milestone_number'] as int? ?? 1,
      dueDate: DateTime.parse(json['due_date'] as String),
      expectedAmount: (json['expected_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      status: json['status'] as String? ?? 'pending',
      receiptNumber: json['receipt_number'] as String?,
      paymentMethod: json['payment_method'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_plan_id': paymentPlanId,
      'company_id': companyId,
      'milestone_number': milestoneNumber,
      'due_date': dueDate.toIso8601String().split('T').first,
      'expected_amount': expectedAmount,
      'paid_amount': paidAmount,
      'paid_at': paidAt?.toIso8601String(),
      'status': status,
      'receipt_number': receiptNumber,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PaymentMilestone copyWith({
    String? id,
    String? paymentPlanId,
    String? companyId,
    int? milestoneNumber,
    DateTime? dueDate,
    double? expectedAmount,
    double? paidAmount,
    DateTime? paidAt,
    String? status,
    String? receiptNumber,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
  }) {
    return PaymentMilestone(
      id: id ?? this.id,
      paymentPlanId: paymentPlanId ?? this.paymentPlanId,
      companyId: companyId ?? this.companyId,
      milestoneNumber: milestoneNumber ?? this.milestoneNumber,
      dueDate: dueDate ?? this.dueDate,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      paidAt: paidAt ?? this.paidAt,
      status: status ?? this.status,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

@immutable
class PaymentPlan {
  final String id;
  final String companyId;
  final String? leadId;
  final String buyerName;
  final String buyerPhone;
  final String? buyerEmail;
  final String? propertyId;
  final String propertyName;
  final String? plotNumber;
  final double totalAmount;
  final double initialDeposit;
  final double balanceAmount;
  final int durationMonths;
  final DateTime startDate;
  final String status; // 'active', 'completed', 'defaulted', 'cancelled'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PaymentMilestone> milestones;

  const PaymentPlan({
    required this.id,
    required this.companyId,
    this.leadId,
    required this.buyerName,
    required this.buyerPhone,
    this.buyerEmail,
    this.propertyId,
    required this.propertyName,
    this.plotNumber,
    required this.totalAmount,
    this.initialDeposit = 0.0,
    required this.balanceAmount,
    this.durationMonths = 1,
    required this.startDate,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.milestones = const [],
  });

  double get totalPaid => (totalAmount - balanceAmount).clamp(0, totalAmount);
  double get progressPercent => totalAmount > 0 ? (totalPaid / totalAmount).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => status == 'completed' || balanceAmount <= 0;
  bool get hasOverdue => milestones.any((m) => m.isOverdue);

  String get formattedStartDate => DateFormat('MMM d, yyyy').format(startDate);

  factory PaymentPlan.fromJson(Map<String, dynamic> json, {List<PaymentMilestone> milestones = const []}) {
    return PaymentPlan(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      leadId: json['lead_id'] as String?,
      buyerName: json['buyer_name'] as String? ?? 'Valued Client',
      buyerPhone: json['buyer_phone'] as String? ?? '',
      buyerEmail: json['buyer_email'] as String?,
      propertyId: json['property_id'] as String?,
      propertyName: json['property_name'] as String? ?? 'Property',
      plotNumber: json['plot_number'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      initialDeposit: (json['initial_deposit'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble() ?? 0.0,
      durationMonths: json['duration_months'] as int? ?? 1,
      startDate: DateTime.parse(json['start_date'] as String),
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      milestones: milestones,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'lead_id': leadId,
      'buyer_name': buyerName,
      'buyer_phone': buyerPhone,
      'buyer_email': buyerEmail,
      'property_id': propertyId,
      'property_name': propertyName,
      'plot_number': plotNumber,
      'total_amount': totalAmount,
      'initial_deposit': initialDeposit,
      'balance_amount': balanceAmount,
      'duration_months': durationMonths,
      'start_date': startDate.toIso8601String().split('T').first,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PaymentPlan copyWith({
    String? id,
    String? companyId,
    String? leadId,
    String? buyerName,
    String? buyerPhone,
    String? buyerEmail,
    String? propertyId,
    String? propertyName,
    String? plotNumber,
    double? totalAmount,
    double? initialDeposit,
    double? balanceAmount,
    int? durationMonths,
    DateTime? startDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PaymentMilestone>? milestones,
  }) {
    return PaymentPlan(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      leadId: leadId ?? this.leadId,
      buyerName: buyerName ?? this.buyerName,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      propertyId: propertyId ?? this.propertyId,
      propertyName: propertyName ?? this.propertyName,
      plotNumber: plotNumber ?? this.plotNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      initialDeposit: initialDeposit ?? this.initialDeposit,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      durationMonths: durationMonths ?? this.durationMonths,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      milestones: milestones ?? this.milestones,
    );
  }
}
