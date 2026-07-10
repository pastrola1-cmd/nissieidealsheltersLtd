import 'package:flutter/foundation.dart';

@immutable
class SmsCampaign {
  final String id;
  final String companyId;
  final String title;
  final String message;
  final String channel;
  final String senderId;
  final Map<String, dynamic>? recipientFilter;
  final int totalRecipients;
  final int deliveredCount;
  final int failedCount;
  final String status;
  final String? sentBy;
  final DateTime? sentAt;
  final DateTime createdAt;

  const SmsCampaign({
    required this.id,
    required this.companyId,
    required this.title,
    required this.message,
    required this.channel,
    required this.senderId,
    this.recipientFilter,
    required this.totalRecipients,
    required this.deliveredCount,
    required this.failedCount,
    required this.status,
    this.sentBy,
    this.sentAt,
    required this.createdAt,
  });

  factory SmsCampaign.fromJson(Map<String, dynamic> json) {
    return SmsCampaign(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      channel: json['channel'] as String? ?? 'generic',
      senderId: json['sender_id'] as String? ?? 'Nissie',
      recipientFilter: json['recipient_filter'] as Map<String, dynamic>?,
      totalRecipients: json['total_recipients'] as int? ?? 0,
      deliveredCount: json['delivered_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'sent',
      sentBy: json['sent_by'] as String?,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'message': message,
      'channel': channel,
      'sender_id': senderId,
      'recipient_filter': recipientFilter,
      'total_recipients': totalRecipients,
      'delivered_count': deliveredCount,
      'failed_count': failedCount,
      'status': status,
      'sent_by': sentBy,
      'sent_at': sentAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class SmsMessageLog {
  final String id;
  final String campaignId;
  final String? recipientName;
  final String recipientPhone;
  final String? recipientType;
  final String messageBody;
  final String status;
  final String? termiiMessageId;
  final String? errorMessage;
  final DateTime sentAt;

  const SmsMessageLog({
    required this.id,
    required this.campaignId,
    this.recipientName,
    required this.recipientPhone,
    this.recipientType,
    required this.messageBody,
    required this.status,
    this.termiiMessageId,
    this.errorMessage,
    required this.sentAt,
  });

  factory SmsMessageLog.fromJson(Map<String, dynamic> json) {
    return SmsMessageLog(
      id: json['id'] as String,
      campaignId: json['campaign_id'] as String,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String,
      recipientType: json['recipient_type'] as String?,
      messageBody: json['message_body'] as String,
      status: json['status'] as String,
      termiiMessageId: json['termii_message_id'] as String?,
      errorMessage: json['error_message'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'recipient_type': recipientType,
      'message_body': messageBody,
      'status': status,
      'termii_message_id': termiiMessageId,
      'error_message': errorMessage,
      'sent_at': sentAt.toIso8601String(),
    };
  }
}
