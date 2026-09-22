import 'dart:async';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:nissie_ideal_shelters/config/supabase_config.dart';
import 'package:nissie_ideal_shelters/providers/auth_state.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/wallet_provider.dart';


/// Riverpod NotifierProvider for authentication state management.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  late SupabaseService _supabaseService;
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
    Future.microtask(() {
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
          WalletNotifier.clearSessionCache();
          state = const AuthState(isAuthenticated: false);
        }
      });
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
          var profile = await _supabaseService.getProfile(userId);
          if (profile != null) {
            // Auto-heal missing email or phone on profile if available in auth session
            final user = _client.auth.currentUser;
            if (user != null) {
              final userEmail = user.email;
              final userPhone = user.phone;
              bool needUpdate = false;
              final Map<String, dynamic> updates = {};

              if (userEmail != null && userEmail.isNotEmpty && profile.email != userEmail) {
                updates['email'] = userEmail;
                needUpdate = true;
              }
              if (userPhone != null && userPhone.isNotEmpty && profile.phone != userPhone) {
                updates['phone'] = userPhone;
                needUpdate = true;
              }
              if (needUpdate) {
                await _supabaseService.update('profiles', userId, updates);
                profile = profile.copyWith(
                  email: updates['email'] as String? ?? profile.email,
                  phone: updates['phone'] as String? ?? profile.phone,
                );
              }
            }

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

      // Safe auto-provision fallback if trigger delay occurs: never leave user logged out!
      final user = _client.auth.currentUser;
      if (user != null) {
        final meta = user.userMetadata ?? {};
        final fallbackProfile = Profile(
          id: user.id,
          email: user.email ?? meta['email'] as String? ?? '',
          phone: user.phone ?? meta['phone'] as String? ?? '',
          fullName: meta['full_name'] as String? ?? 'User',
          role: UserRole.fromString(meta['role'] as String? ?? 'buyer'),
          companyId: meta['company_id'] as String? ?? AppStrings.defaultCompanyId,
          status: PartnerStatus.approved,
          createdAt: DateTime.now(),
        );

        try {
          await _supabaseService.insert('profiles', fallbackProfile.toJson());
        } catch (_) {}

        state = AuthState(
          profile: fallbackProfile,
          isAuthenticated: true,
          isLoading: false,
        );
        return;
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'User profile missing from login response.',
      );
      return false;
    } catch (e) {
      final rawError = e.toString().replaceFirst('AuthException: ', '');
      String friendly = rawError;
      if (rawError.toLowerCase().contains('email not confirmed')) {
        friendly = 'Email not confirmed. Please check your email inbox or run the quick auto-confirm SQL in Supabase.';
      } else if (rawError.toLowerCase().contains('invalid login credentials')) {
        friendly = 'Invalid email or password. Please verify your credentials.';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendly,
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
          'phone': phone,
          'email': email,
          'role': role.value,
          if (companyId != null) 'company_id': companyId,
          if (createCompanyName != null)
            'create_company_name': createCompanyName,
          if (createSubscriptionTier != null)
            'create_subscription_tier': createSubscriptionTier,
        },
      );

      // Immediately establish session if Supabase did not return an active session
      if (response.session == null) {
        try {
          await _client.auth.signInWithPassword(email: email, password: password);
        } catch (_) {}
      }

      final current = _client.auth.currentUser;
      if (current != null) {
        await _fetchProfile(current.id);
        return state.isAuthenticated;
      }

      // If user was created in auth.users but session is blocked by unconfirmed email
      if (response.user != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Account registered! Email confirmation is enabled in your Supabase project. Disable "Confirm email" in Supabase Auth or run the auto-confirm SQL to log in immediately.',
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not complete registration. Please try again.',
      );
      return false;
    } catch (e) {
      // If user already exists, log in seamlessly
      try {
        final loginSuccess = await login(email, password);
        if (loginSuccess) return true;
      } catch (_) {}

      final rawError = e.toString().replaceFirst('AuthException: ', '');
      String friendly = rawError;
      if (rawError.toLowerCase().contains('email not confirmed')) {
        friendly = 'Email not confirmed. Please check your email inbox or run the quick auto-confirm SQL in Supabase.';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendly,
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
    WalletNotifier.clearSessionCache();
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
