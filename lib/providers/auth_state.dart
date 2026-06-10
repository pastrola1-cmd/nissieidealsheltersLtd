import 'package:flutter/foundation.dart';
import 'package:ppn/models/models.dart';

@immutable
class AuthState {
  final Profile? profile;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  const AuthState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    Profile? profile,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // We can clear error messages
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
