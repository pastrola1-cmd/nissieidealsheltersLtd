import 'package:flutter/foundation.dart';

@immutable
class EmailCampaign {
  final String id;
  final String companyId;
  final String subject;
  final String body;
  final Map<String, dynamic>? recipientFilter;
  final int totalRecipients;
  final int deliveredCount;
  final int failedCount;
  final String status;
  final String? sentBy;
  final DateTime? sentAt;
  final DateTime createdAt;

  const EmailCampaign({
    required this.id,
    required this.companyId,
    required this.subject,
    required this.body,
    this.recipientFilter,
    required this.totalRecipients,
    required this.deliveredCount,
    required this.failedCount,
    required this.status,
    this.sentBy,
    this.sentAt,
    required this.createdAt,
  });

  factory EmailCampaign.fromJson(Map<String, dynamic> json) {
    return EmailCampaign(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      subject: json['subject'] as String,
      body: json['body'] as String,
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
      'subject': subject,
      'body': body,
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
class EmailMessageLog {
  final String id;
  final String campaignId;
  final String? recipientName;
  final String recipientEmail;
  final String? recipientType;
  final String status;
  final String? errorMessage;
  final DateTime sentAt;

  const EmailMessageLog({
    required this.id,
    required this.campaignId,
    this.recipientName,
    required this.recipientEmail,
    this.recipientType,
    required this.status,
    this.errorMessage,
    required this.sentAt,
  });

  factory EmailMessageLog.fromJson(Map<String, dynamic> json) {
    return EmailMessageLog(
      id: json['id'] as String,
      campaignId: json['campaign_id'] as String,
      recipientName: json['recipient_name'] as String?,
      recipientEmail: json['recipient_email'] as String,
      recipientType: json['recipient_type'] as String?,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'recipient_name': recipientName,
      'recipient_email': recipientEmail,
      'recipient_type': recipientType,
      'status': status,
      'error_message': errorMessage,
      'sent_at': sentAt.toIso8601String(),
    };
  }
}
