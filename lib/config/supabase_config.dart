import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration class for Supabase integration.
///
/// Reads connection credentials from environment variables via flutter_dotenv
/// and provides convenient access to the Supabase client, auth, and storage.
///
/// Usage:
/// ```dart
/// await SupabaseConfig.initialize();
/// final client = SupabaseConfig.client;
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  /// The Supabase project URL.
  /// Priority: --dart-define=SUPABASE_URL, then dotenv (local dev only).
  static String get supabaseUrl {
    const defined = String.fromEnvironment('SUPABASE_URL');
    if (defined.isNotEmpty) return defined;
    try {
      return dotenv.env['SUPABASE_URL'] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// The Supabase anonymous/public key.
  /// Priority: --dart-define=SUPABASE_ANON_KEY, then dotenv (local dev only).
  static String get supabaseAnonKey {
    const defined = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (defined.isNotEmpty) return defined;
    try {
      return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Initializes the Supabase client with URL and anon key from environment.
  ///
  /// Must be called once during app startup, typically in `main()`.
  /// Ensure `dotenv.load()` has been called before invoking this.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  /// The global [SupabaseClient] instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// Shortcut to the GoTrue auth client for authentication operations.
  static GoTrueClient get auth => client.auth;

  /// Shortcut to the Supabase Storage client for file/bucket operations.
  static SupabaseStorageClient get storage => client.storage;
}
