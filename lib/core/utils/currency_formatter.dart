import 'package:intl/intl.dart';

/// Utility helpers for formatting monetary values in Nigerian Naira (₦).
///
/// Uses the `intl` package [NumberFormat] under the hood.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Standard Naira formatter: `₦15,000,000`
  static final _nairaFormat = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );

  /// Formats [amount] as full Nigerian Naira with comma grouping.
  ///
  /// Example: `formatNaira(15000000)` → `"₦15,000,000"`
  static String formatNaira(num amount) {
    return _nairaFormat.format(amount);
  }

  /// Formats [amount] in a compact human-readable form.
  ///
  /// Examples:
  /// - `formatNairaCompact(500000)` → `"₦500K"`
  /// - `formatNairaCompact(15000000)` → `"₦15M"`
  /// - `formatNairaCompact(2500000000)` → `"₦2.5B"`
  /// - `formatNairaCompact(750)` → `"₦750"`
  static String formatNairaCompact(num amount) {
    final abs = amount.abs();

    if (abs >= 1e9) {
      final value = amount / 1e9;
      return '₦${_stripTrailingZeros(value)}B';
    } else if (abs >= 1e6) {
      final value = amount / 1e6;
      return '₦${_stripTrailingZeros(value)}M';
    } else if (abs >= 1e3) {
      final value = amount / 1e3;
      return '₦${_stripTrailingZeros(value)}K';
    }

    return '₦${amount.toInt()}';
  }

  /// Removes unnecessary trailing zeros from a double string representation.
  ///
  /// `2.50` → `"2.5"`, `3.00` → `"3"`.
  static String _stripTrailingZeros(num value) {
    final str = value.toStringAsFixed(1);
    return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
  }
}
