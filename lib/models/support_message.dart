import 'package:flutter/foundation.dart';

@immutable
class SupportMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole; // 'client' or 'admin'
  final String senderName;
  final String? senderPhone;
  final String? senderEmail;
  final String? propertyId;
  final String? propertyTitle;
  final String message;
  final bool isReadByAdmin;
  final bool isReadByClient;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderRole = 'client',
    required this.senderName,
    this.senderPhone,
    this.senderEmail,
    this.propertyId,
    this.propertyTitle,
    required this.message,
    this.isReadByAdmin = false,
    this.isReadByClient = false,
    required this.createdAt,
  });

  bool get isFromAdmin => senderRole == 'admin';
  bool get isFromClient => senderRole == 'client';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: (json['sender_role'] as String?) ?? 'client',
      senderName: (json['sender_name'] as String?) ?? 'Visitor',
      senderPhone: json['sender_phone'] as String?,
      senderEmail: json['sender_email'] as String?,
      propertyId: json['property_id'] as String?,
      propertyTitle: json['property_title'] as String?,
      message: (json['message'] as String?) ?? '',
      isReadByAdmin: (json['is_read_by_admin'] as bool?) ?? false,
      isReadByClient: (json['is_read_by_client'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'sender_name': senderName,
      if (senderPhone != null && senderPhone!.isNotEmpty) 'sender_phone': senderPhone,
      if (senderEmail != null && senderEmail!.isNotEmpty) 'sender_email': senderEmail,
      if (propertyId != null && propertyId!.isNotEmpty) 'property_id': propertyId,
      if (propertyTitle != null && propertyTitle!.isNotEmpty) 'property_title': propertyTitle,
      'message': message,
      'is_read_by_admin': isReadByAdmin,
      'is_read_by_client': isReadByClient,
    };
  }

  SupportMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderRole,
    String? senderName,
    String? senderPhone,
    String? senderEmail,
    String? propertyId,
    String? propertyTitle,
    String? message,
    bool? isReadByAdmin,
    bool? isReadByClient,
    DateTime? createdAt,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      senderEmail: senderEmail ?? this.senderEmail,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      message: message ?? this.message,
      isReadByAdmin: isReadByAdmin ?? this.isReadByAdmin,
      isReadByClient: isReadByClient ?? this.isReadByClient,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
