import 'package:flutter/foundation.dart';

@immutable
class Goal {
  final String id;
  final String companyId;
  final String? createdBy;
  final String metric; // 'leads', 'closings', 'revenue'
  final String horizon; // 'monthly', 'quarterly', '6month', 'yearly'
  final double targetValue;
  final DateTime periodStart;
  final DateTime periodEnd;

  const Goal({
    required this.id,
    required this.companyId,
    this.createdBy,
    required this.metric,
    required this.horizon,
    required this.targetValue,
    required this.periodStart,
    required this.periodEnd,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      createdBy: json['created_by'] as String?,
      metric: json['metric'] as String,
      horizon: json['horizon'] as String,
      targetValue: (json['target_value'] as num).toDouble(),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'company_id': companyId,
      'created_by': createdBy,
      'metric': metric,
      'horizon': horizon,
      'target_value': targetValue,
      'period_start': periodStart.toIso8601String().split('T').first,
      'period_end': periodEnd.toIso8601String().split('T').first,
    };
  }

  Goal copyWith({
    String? id,
    String? companyId,
    String? createdBy,
    String? metric,
    String? horizon,
    double? targetValue,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    return Goal(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      metric: metric ?? this.metric,
      horizon: horizon ?? this.horizon,
      targetValue: targetValue ?? this.targetValue,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
    );
  }
}
