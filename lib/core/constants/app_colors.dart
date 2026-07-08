import 'package:flutter/material.dart';

/// PPN Brand Color System
/// Designed for real estate — trust, professionalism, energy
class AppColors {
  AppColors._();

  // ── Primary Brand ──
  static const Color primary = Color(0xFF1E6BE6);
  static const Color primaryLight = Color(0xFF4C8DF5);
  static const Color primaryDark = Color(0xFF0B4CB0);

  // ── Accent ──
  static const Color accent = Color(0xFF7C3AED);
  static const Color accentLight = Color(0xFFA78BFA);
  static const Color accentDark = Color(0xFF5B21B6);

  // ── Secondary ──
  static const Color secondary = Color(0xFF05664F);
  static const Color secondaryLight = Color(0xFFD2EBE4);
  static const Color secondaryDark = Color(0xFF023F31);

  // ── Success / Green ──
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);

  // ── Warning / Yellow ──
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  // ── Error / Red ──
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);

  // ── Info / Blue ──
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── Neutrals ──
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // ── Text ──
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── Lead Stage Colors ──
  static const Color stageNew = Color(0xFF3B82F6);
  static const Color stageContacted = Color(0xFF8B5CF6);
  static const Color stageInspection = Color(0xFFF59E0B);
  static const Color stageNegotiation = Color(0xFFF97316);
  static const Color stageClosed = Color(0xFF10B981);
  static const Color stageLost = Color(0xFFEF4444);

  // ── Commission Status Colors ──
  static const Color commissionPending = Color(0xFFF59E0B);
  static const Color commissionApproved = Color(0xFF10B981);
  static const Color commissionPaid = Color(0xFF3B82F6);
  static const Color commissionDisputed = Color(0xFFEF4444);

  // ── Dark Surfaces (for premium sections) ──
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkSurfaceLight = Color(0xFF1E293B);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium gradient for dashboard welcome banners and hero sections
  static const LinearGradient dashboardHeaderGradient = LinearGradient(
    colors: [Color(0xFF1E6BE6), Color(0xFF0D9488), Color(0xFF05664F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// CTA / Primary action button gradient (matches landing page)
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFF1E6BE6), Color(0xFF05664F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm accent for commissions, earnings, and gold highlights
  static const LinearGradient warmAccentGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Shimmer / loading effect gradient
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0xFFF1F5F9),
      Color(0xFFE2E8F0),
      Color(0xFFF1F5F9),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
