import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:ppn/config/supabase_config.dart';
import 'package:ppn/providers/auth_state.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/core/enums/enums.dart';


/// Riverpod NotifierProvider for authentication state management.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  late final SupabaseService _supabaseService;
  final sb.SupabaseClient _client = SupabaseConfig.client;
  StreamSubscription<sb.AuthState>? _authSubscription;
  
  // Custom broadcast StreamController to notify GoRouter when state updates
  final StreamController<AuthState> _streamController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get stream => _streamController.stream;

  @override
  AuthState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _initialize();

    // Register cleanup callback on provider dispose
    ref.onDispose(() {
      _authSubscription?.cancel();
      _streamController.close();
    });

    return const AuthState();
  }

  // Override state setter to push updates to the stream controller
  @override
  set state(AuthState value) {
    super.state = value;
    if (!_streamController.isClosed) {
      _streamController.add(value);
    }
  }

  void _initialize() {
    // Check current session immediately on startup
    final currentSession = _client.auth.currentSession;
    if (currentSession != null) {
      _fetchProfile(currentSession.user.id);
    }

    // Listen to subsequent auth changes
    _authSubscription = _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        if (state.profile?.id != session.user.id) {
          await _fetchProfile(session.user.id);
        }
      } else {
        state = const AuthState(isAuthenticated: false);
      }
    });
  }

  Future<void> _fetchProfile(String userId) async {
    state = state.copyWith(isLoading: true);
    // Retry mechanism to account for slight database trigger delays on signup
    for (int i = 0; i < 4; i++) {
      try {
        final profile = await _supabaseService.getProfile(userId);
        if (profile != null) {
          state = AuthState(
            profile: profile,
            isAuthenticated: true,
            isLoading: false,
          );
          return;
        }
      } catch (e) {
        // Silently catch and retry
      }
      await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
    }

    state = const AuthState(
      errorMessage: 'User profile could not be loaded. Please try again.',
      isAuthenticated: false,
      isLoading: false,
    );
  }

  /// Logs in a user with email and password.
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _fetchProfile(response.user!.id);
        return state.isAuthenticated;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('AuthException: ', ''),
      );
      return false;
    }
  }

  /// Signs up a new user and lets the Postgres trigger auto-create the Profile.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role.value,
        },
      );
      if (response.user != null) {
        // Wait for trigger and fetch profile
        await _fetchProfile(response.user!.id);
        return state.isAuthenticated;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('AuthException: ', ''),
      );
      return false;
    }
  }

  /// Signs out the current user and clears the state.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.auth.signOut();
    } catch (_) {}
    state = const AuthState(isAuthenticated: false);
  }

  /// Refreshes the current user's profile from the database.
  Future<void> refreshProfile() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser != null) {
      await _fetchProfile(currentUser.id);
    }
  }
}
