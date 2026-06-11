import 'package:flutter/foundation.dart';

@immutable
class Campaign {
  final String id;
  final String companyId;
  final String? propertyId;
  final String? createdBy;
  final Map<String, dynamic> inputData;
  final Map<String, dynamic> outputData;
  final String platform;
  final DateTime createdAt;
  final int shareCount;
  final int leadCount;
  final int conversionCount;

  const Campaign({
    required this.id,
    required this.companyId,
    this.propertyId,
    this.createdBy,
    required this.inputData,
    required this.outputData,
    required this.platform,
    required this.createdAt,
    this.shareCount = 0,
    this.leadCount = 0,
    this.conversionCount = 0,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      propertyId: json['property_id'] as String?,
      createdBy: json['created_by'] as String?,
      inputData: json['input_data'] as Map<String, dynamic>,
      outputData: json['output_data'] as Map<String, dynamic>,
      platform: json['platform'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      shareCount: json['share_count'] as int? ?? 0,
      leadCount: json['lead_count'] as int? ?? 0,
      conversionCount: json['conversion_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'property_id': propertyId,
      'created_by': createdBy,
      'input_data': inputData,
      'output_data': outputData,
      'platform': platform,
      'created_at': createdAt.toIso8601String(),
      'share_count': shareCount,
      'lead_count': leadCount,
      'conversion_count': conversionCount,
    };
  }

  Campaign copyWith({
    String? id,
    String? companyId,
    String? propertyId,
    String? createdBy,
    Map<String, dynamic>? inputData,
    Map<String, dynamic>? outputData,
    String? platform,
    DateTime? createdAt,
    int? shareCount,
    int? leadCount,
    int? conversionCount,
  }) {
    return Campaign(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      propertyId: propertyId ?? this.propertyId,
      createdBy: createdBy ?? this.createdBy,
      inputData: inputData ?? this.inputData,
      outputData: outputData ?? this.outputData,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      shareCount: shareCount ?? this.shareCount,
      leadCount: leadCount ?? this.leadCount,
      conversionCount: conversionCount ?? this.conversionCount,
    );
  }
}
