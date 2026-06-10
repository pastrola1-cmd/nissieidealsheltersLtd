import 'package:flutter/foundation.dart';
import 'package:ppn/core/enums/enums.dart';

@immutable
class Profile {
  final String id;
  final String? companyId;
  final UserRole role;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? referralCode;
  final PartnerStatus status;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.companyId,
    required this.role,
    this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.referralCode,
    required this.status,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      companyId: json['company_id'] as String?,
      role: UserRole.fromString(json['role'] as String),
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      referralCode: json['referral_code'] as String?,
      status: PartnerStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'role': role.value,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'referral_code': referralCode,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? companyId,
    UserRole? role,
    String? fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    String? referralCode,
    PartnerStatus? status,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      referralCode: referralCode ?? this.referralCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
