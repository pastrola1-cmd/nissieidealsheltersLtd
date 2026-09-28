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

  static const String _defaultUrl = 'https://mrwgijaypgtkoyaizjpg.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yd2dpamF5cGd0a295YWl6anBnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MjkzNjMsImV4cCI6MjA5NzEwNTM2M30.nS0Z96NwklNEQdv_Spc1F154iWLco0JJTaBbmk6G0lo';

  /// The Supabase project URL.
  /// Priority: --dart-define=SUPABASE_URL, then dotenv, then fallback constant.
  static String get supabaseUrl {
    const defined = String.fromEnvironment('SUPABASE_URL');
    if (defined.isNotEmpty) return defined;
    try {
      final envVal = dotenv.env['SUPABASE_URL'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return _defaultUrl;
  }

  /// The Supabase anonymous/public key.
  /// Priority: --dart-define=SUPABASE_ANON_KEY, then dotenv, then fallback constant.
  static String get supabaseAnonKey {
    const defined = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (defined.isNotEmpty) return defined;
    try {
      final envVal = dotenv.env['SUPABASE_ANON_KEY'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return _defaultAnonKey;
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
