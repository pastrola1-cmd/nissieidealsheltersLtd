import 'package:flutter/foundation.dart';
import 'package:nissie_ideal_shelters/models/models.dart';

@immutable
class AuthState {
  final Profile? profile;
  final Company? company;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  const AuthState({
    this.profile,
    this.company,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    Profile? profile,
    Company? company,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      profile: profile ?? this.profile,
      company: company ?? this.company,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // We can clear error messages
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
