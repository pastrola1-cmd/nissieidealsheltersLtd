import 'package:flutter/foundation.dart';

@immutable
class StaffPerformance {
  final String profileId;
  final String name;
  final int leadsHandled;
  final int conversions;
  final double conversionRate;

  const StaffPerformance({
    required this.profileId,
    required this.name,
    required this.leadsHandled,
    required this.conversions,
    required this.conversionRate,
  });

  factory StaffPerformance.fromJson(Map<String, dynamic> json) {
    return StaffPerformance(
      profileId: json['profile_id'] as String,
      name: json['name'] as String? ?? 'Unknown Staff',
      leadsHandled: json['leads_handled'] as int? ?? 0,
      conversions: json['conversions'] as int? ?? 0,
      conversionRate: (json['conversion_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'name': name,
      'leads_handled': leadsHandled,
      'conversions': conversions,
      'conversion_rate': conversionRate,
    };
  }
}

@immutable
class DailyReport {
  final String id;
  final String companyId;
  final DateTime reportDate;
  final int newLeads;
  final int followUps;
  final int inspectionsBooked;
  final int inspectionsCompleted;
  final int closedDeals;
  final double revenueToday;
  final List<StaffPerformance> topStaff;
  final Map<String, int> leadsByStage;

  const DailyReport({
    required this.id,
    required this.companyId,
    required this.reportDate,
    required this.newLeads,
    required this.followUps,
    required this.inspectionsBooked,
    required this.inspectionsCompleted,
    required this.closedDeals,
    required this.revenueToday,
    required this.topStaff,
    required this.leadsByStage,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final staffRaw = json['top_staff'] as List<dynamic>? ?? [];
    final staffList = staffRaw.map((e) => StaffPerformance.fromJson(e as Map<String, dynamic>)).toList();

    final stageRaw = json['leads_by_stage'] as Map<String, dynamic>? ?? {};
    final stageMap = stageRaw.map((k, v) => MapEntry(k, v as int? ?? 0));

    return DailyReport(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      reportDate: DateTime.parse(json['report_date'] as String),
      newLeads: json['new_leads'] as int? ?? 0,
      followUps: json['follow_ups'] as int? ?? 0,
      inspectionsBooked: json['inspections_booked'] as int? ?? 0,
      inspectionsCompleted: json['inspections_completed'] as int? ?? 0,
      closedDeals: json['closed_deals'] as int? ?? 0,
      revenueToday: (json['revenue_today'] as num?)?.toDouble() ?? 0.0,
      topStaff: staffList,
      leadsByStage: stageMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'report_date': reportDate.toIso8601String().split('T').first,
      'new_leads': newLeads,
      'follow_ups': followUps,
      'inspections_booked': inspectionsBooked,
      'inspections_completed': inspectionsCompleted,
      'closed_deals': closedDeals,
      'revenue_today': revenueToday,
      'top_staff': topStaff.map((e) => e.toJson()).toList(),
      'leads_by_stage': leadsByStage,
    };
  }
}
