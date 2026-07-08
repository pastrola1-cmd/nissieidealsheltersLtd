import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:nissie_ideal_shelters/config/supabase_config.dart';
import 'package:nissie_ideal_shelters/providers/auth_state.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';


/// Riverpod NotifierProvider for authentication state management.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  late final SupabaseService _supabaseService;
  final sb.SupabaseClient _client = SupabaseConfig.client;
  StreamSubscription<sb.AuthState>? _authSubscription;

  /// Tracks the currently running profile fetch to prevent duplicate concurrent
  /// fetches (the root cause of the blank-screen-on-login bug).
  Completer<void>? _activeFetch;

  @override
  AuthState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _initialize();

    // Register cleanup callback on provider dispose
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return const AuthState();
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
        // If a fetch is already running for this user, just wait for it.
        if (_activeFetch != null && !_activeFetch!.isCompleted) {
          await _activeFetch!.future;
          return;
        }
        // Only fetch if we don't already have this user's profile loaded.
        if (state.profile?.id != session.user.id) {
          await _fetchProfile(session.user.id);
        }
      } else {
        state = const AuthState(isAuthenticated: false);
      }
    });
  }

  /// Fetches the user profile, guarded by [_activeFetch] to prevent duplicates.
  Future<void> _fetchProfile(String userId) async {
    // If already fetching this exact user, piggyback on the existing operation.
    if (_activeFetch != null && !_activeFetch!.isCompleted) {
      await _activeFetch!.future;
      return;
    }

    final completer = Completer<void>();
    _activeFetch = completer;

    state = state.copyWith(isLoading: true);

    try {
      // Retry mechanism to account for slight database trigger delays on signup
      for (int i = 0; i < 4; i++) {
        try {
          final profile = await _supabaseService.getProfile(userId);
          if (profile != null) {
            Company? company;
            if (profile.companyId != null) {
              company = await _supabaseService.getCompany(profile.companyId!);
            }
            state = AuthState(
              profile: profile,
              company: company,
              isAuthenticated: true,
              isLoading: false,
            );
            return;
          }
        } catch (e) {
          debugPrint('AuthNotifier._fetchProfile retry $i error: $e');
        }
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }

      state = const AuthState(
        errorMessage: 'User profile could not be loaded. Please try again.',
        isAuthenticated: false,
        isLoading: false,
      );
    } finally {
      completer.complete();
    }
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

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    String? companyId,
    String? createCompanyName,
    String? createSubscriptionTier,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role.value,
          if (companyId != null) 'company_id': companyId,
          if (createCompanyName != null) 'create_company_name': createCompanyName,
          if (createSubscriptionTier != null) 'create_subscription_tier': createSubscriptionTier,
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

  /// Updates the profile (name, phone, avatar) for the currently authenticated user.
  Future<bool> updateProfile({
    required String fullName,
    required String phone,
    Uint8List? avatarBytes,
    String? avatarName,
  }) async {
    final profile = state.profile;
    if (profile == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      String? newAvatarUrl = profile.avatarUrl;

      if (avatarBytes != null && avatarName != null) {
        final ext = avatarName.split('.').last;
        final path = 'avatars/${profile.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        newAvatarUrl = await _supabaseService.uploadFile(
          'company-assets',
          path,
          avatarBytes,
          mimeType: 'image/$ext',
        );
      }

      final updatedData = await _supabaseService.update('profiles', profile.id, {
        'full_name': fullName,
        'phone': phone,
        'avatar_url': newAvatarUrl,
      });

      state = AuthState(
        profile: Profile.fromJson(updatedData),
        company: state.company,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Refreshes only the company details in the authentication state.
  Future<void> refreshCompany() async {
    final profile = state.profile;
    if (profile != null && profile.companyId != null) {
      final company = await _supabaseService.getCompany(profile.companyId!);
      state = state.copyWith(company: company);
    }
  }
}
