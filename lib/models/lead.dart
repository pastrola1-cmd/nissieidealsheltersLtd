import 'package:flutter/foundation.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

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
  final String? assignedAgentId;
  final String? leadFingerprint;
  final String? campaignId;
  final String intentScore;
  final Map<String, dynamic> engagementSignals;
  final DateTime? firstResponseAt;
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
    this.assignedAgentId,
    this.leadFingerprint,
    this.campaignId,
    this.intentScore = 'Cold',
    this.engagementSignals = const {},
    this.firstResponseAt,
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
      assignedAgentId: json['assigned_agent_id'] as String?,
      leadFingerprint: json['lead_fingerprint'] as String?,
      campaignId: json['campaign_id'] as String?,
      intentScore: json['intent_score'] as String? ?? 'Cold',
      engagementSignals: json['engagement_signals'] as Map<String, dynamic>? ?? {},
      firstResponseAt: json['first_response_at'] != null ? DateTime.parse(json['first_response_at'] as String) : null,
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
      'assigned_agent_id': assignedAgentId,
      'lead_fingerprint': leadFingerprint,
      'campaign_id': campaignId,
      'intent_score': intentScore,
      'engagement_signals': engagementSignals,
      'first_response_at': firstResponseAt?.toIso8601String(),
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
    String? assignedAgentId,
    String? leadFingerprint,
    String? campaignId,
    String? intentScore,
    Map<String, dynamic>? engagementSignals,
    DateTime? firstResponseAt,
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
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      leadFingerprint: leadFingerprint ?? this.leadFingerprint,
      campaignId: campaignId ?? this.campaignId,
      intentScore: intentScore ?? this.intentScore,
      engagementSignals: engagementSignals ?? this.engagementSignals,
      firstResponseAt: firstResponseAt ?? this.firstResponseAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


