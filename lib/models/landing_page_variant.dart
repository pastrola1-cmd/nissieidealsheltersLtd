import 'package:flutter/foundation.dart';

@immutable
class LandingPageVariant {
  final String id;
  final String landingPageId;
  final String companyId;
  final String variantCode; // 'A', 'B', 'C'
  final String headline;
  final String ctaPrimary;
  final String ctaSecondary;
  final int viewsCount;
  final int leadsCount;
  final bool isActive;
  final DateTime createdAt;

  const LandingPageVariant({
    required this.id,
    required this.landingPageId,
    required this.companyId,
    required this.variantCode,
    required this.headline,
    this.ctaPrimary = 'Book Free Site Inspection',
    this.ctaSecondary = 'Get Price List',
    this.viewsCount = 0,
    this.leadsCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory LandingPageVariant.fromJson(Map<String, dynamic> json) {
    return LandingPageVariant(
      id: json['id'] as String,
      landingPageId: json['landing_page_id'] as String,
      companyId: json['company_id'] as String,
      variantCode: json['variant_code'] as String,
      headline: json['headline'] as String,
      ctaPrimary: json['cta_primary'] as String? ?? 'Book Free Site Inspection',
      ctaSecondary: json['cta_secondary'] as String? ?? 'Get Price List',
      viewsCount: (json['views_count'] as int?) ?? 0,
      leadsCount: (json['leads_count'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'landing_page_id': landingPageId,
      'company_id': companyId,
      'variant_code': variantCode,
      'headline': headline,
      'cta_primary': ctaPrimary,
      'cta_secondary': ctaSecondary,
      'views_count': viewsCount,
      'leads_count': leadsCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LandingPageVariant copyWith({
    String? id,
    String? landingPageId,
    String? companyId,
    String? variantCode,
    String? headline,
    String? ctaPrimary,
    String? ctaSecondary,
    int? viewsCount,
    int? leadsCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return LandingPageVariant(
      id: id ?? this.id,
      landingPageId: landingPageId ?? this.landingPageId,
      companyId: companyId ?? this.companyId,
      variantCode: variantCode ?? this.variantCode,
      headline: headline ?? this.headline,
      ctaPrimary: ctaPrimary ?? this.ctaPrimary,
      ctaSecondary: ctaSecondary ?? this.ctaSecondary,
      viewsCount: viewsCount ?? this.viewsCount,
      leadsCount: leadsCount ?? this.leadsCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
