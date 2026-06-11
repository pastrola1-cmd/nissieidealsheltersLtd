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
  final String subscriptionTier;
  final String subscriptionStatus;
  final DateTime? subscriptionExpiresAt;
  final bool isHidden;
  final int? customLeadLimit;

  const Company({
    required this.id,
    required this.name,
    this.logoUrl,
    this.email,
    this.phone,
    this.address,
    required this.createdAt,
    this.subscriptionTier = 'basic',
    this.subscriptionStatus = 'trialing',
    this.subscriptionExpiresAt,
    this.isHidden = false,
    this.customLeadLimit,
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
      subscriptionTier: (json['subscription_tier'] as String?) ?? 'basic',
      subscriptionStatus: (json['subscription_status'] as String?) ?? 'trialing',
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String)
          : null,
      isHidden: (json['is_hidden'] as bool?) ?? false,
      customLeadLimit: json['custom_lead_limit'] as int?,
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
      'subscription_tier': subscriptionTier,
      'subscription_status': subscriptionStatus,
      'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
      'is_hidden': isHidden,
      'custom_lead_limit': customLeadLimit,
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
    String? subscriptionTier,
    String? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
    bool? isHidden,
    Object? customLeadLimit = const Object(),
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      isHidden: isHidden ?? this.isHidden,
      customLeadLimit: customLeadLimit == const Object()
          ? this.customLeadLimit
          : (customLeadLimit as int?),
    );
  }
}

class SubscriptionPlan {
  final String tier; // 'basic', 'growth', 'enterprise'
  final String name;
  final int price;
  final int maxListings;
  final int maxPartners;
  final int maxLeadsPerMonth;
  final List<String> features;

  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.price,
    required this.maxListings,
    required this.maxPartners,
    required this.maxLeadsPerMonth,
    required this.features,
  });

  static const basic = SubscriptionPlan(
    tier: 'basic',
    name: 'Starter Plan',
    price: 25000,
    maxListings: 10,
    maxPartners: 5,
    maxLeadsPerMonth: 150,
    features: [
      'Basic Listings (up to 10)',
      'Lead Pipeline (up to 5 Partners)',
      '150 Leads per Month',
    ],
  );

  static const growth = SubscriptionPlan(
    tier: 'growth',
    name: 'Agency Growth',
    price: 50000,
    maxListings: 50,
    maxPartners: 25,
    maxLeadsPerMonth: 500,
    features: [
      'Up to 50 Listings',
      'Up to 25 Partners',
      '500 Leads per Month',
      'Push Notifications',
      'Analytics Panel',
      'Custom Logo Branding',
    ],
  );

  static const enterprise = SubscriptionPlan(
    tier: 'enterprise',
    name: 'Unlimited Scale',
    price: 100000,
    maxListings: 999999,
    maxPartners: 999999,
    maxLeadsPerMonth: 999999,
    features: [
      'Unlimited Listings & Partners',
      'Unlimited Leads per Month',
      'Push Notifications',
      'Analytics Panel',
      'Custom Logo Branding',
      'Priority Ledger & Support',
    ],
  );

  static SubscriptionPlan fromTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'growth':
        return growth;
      case 'enterprise':
        return enterprise;
      case 'basic':
      default:
        return basic;
    }
  }
}

extension CompanySubscriptionExtension on Company {
  SubscriptionPlan get plan => SubscriptionPlan.fromTier(subscriptionTier);

  bool get isTrialing => subscriptionStatus == 'trialing';
  bool get isActive => subscriptionStatus == 'active';
  bool get isPastDue => subscriptionStatus == 'past_due';
  bool get isSuspended => subscriptionStatus == 'suspended';

  bool get isSubscriptionActive {
    if (isSuspended) return false;
    if (subscriptionExpiresAt == null) return true;
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  int get effectiveLeadLimit {
    if (customLeadLimit != null) return customLeadLimit!;
    return plan.maxLeadsPerMonth;
  }
}

