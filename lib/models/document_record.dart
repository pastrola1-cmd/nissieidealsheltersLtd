import 'package:flutter/foundation.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

@immutable
class DocumentRecord {
  final String id;
  final String companyId;
  final String? leadId;
  final String? createdBy;
  final DocumentType type;
  final String title;
  final String fileUrl;
  final Map<String, dynamic> variables;
  final DateTime createdAt;

  const DocumentRecord({
    required this.id,
    required this.companyId,
    this.leadId,
    this.createdBy,
    required this.type,
    required this.title,
    required this.fileUrl,
    required this.variables,
    required this.createdAt,
  });

  factory DocumentRecord.fromJson(Map<String, dynamic> json) {
    return DocumentRecord(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      leadId: json['lead_id'] as String?,
      createdBy: json['created_by'] as String?,
      type: DocumentType.fromString(json['type'] as String),
      title: json['title'] as String,
      fileUrl: json['file_url'] as String,
      variables: json['variables'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'lead_id': leadId,
      'created_by': createdBy,
      'type': type.value,
      'title': title,
      'file_url': fileUrl,
      'variables': variables,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DocumentRecord copyWith({
    String? id,
    String? companyId,
    String? leadId,
    String? createdBy,
    DocumentType? type,
    String? title,
    String? fileUrl,
    Map<String, dynamic>? variables,
    DateTime? createdAt,
  }) {
    return DocumentRecord(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      leadId: leadId ?? this.leadId,
      createdBy: createdBy ?? this.createdBy,
      type: type ?? this.type,
      title: title ?? this.title,
      fileUrl: fileUrl ?? this.fileUrl,
      variables: variables ?? this.variables,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
