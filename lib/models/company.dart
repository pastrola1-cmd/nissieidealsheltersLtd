import 'package:flutter/foundation.dart';

@immutable
class Company {
  final String id;
  final String name;
  final String? logoUrl;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  const Company({
    required this.id,
    required this.name,
    this.logoUrl,
    this.email,
    this.phone,
    this.address,
    required this.createdAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'email': email,
      'phone': phone,
      'address': address,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? email,
    String? phone,
    String? address,
    DateTime? createdAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
