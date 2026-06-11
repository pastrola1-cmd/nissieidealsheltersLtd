import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/auth_state.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/core/enums/enums.dart';

/// State representation for partner list and management operations.
class PartnerState {
  final List<Profile> partners;
  final bool isLoading;
  final String? errorMessage;

  const PartnerState({
    this.partners = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PartnerState copyWith({
    List<Profile>? partners,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PartnerState(
      partners: partners ?? this.partners,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Riverpod Notifier that manages loading and changing status of partners.
class PartnerNotifier extends Notifier<PartnerState> {
  late final SupabaseService _supabaseService;
  String? _loadedCompanyId;

  @override
  PartnerState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    if (profile != null && (profile.role == UserRole.admin || profile.role == UserRole.platformAdmin)) {
      final companyId = profile.companyId;
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() => loadPartners(companyId));
        return const PartnerState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const PartnerState();
    }
  }

  /// Load all partner profiles for a given company.
  Future<void> loadPartners(String? companyId) async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _supabaseService.getProfilesByRole(UserRole.partner, companyId: companyId);
      state = PartnerState(partners: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Generates a unique referral code.
  /// Format: {COMPANY_PREFIX}-{PARTNER_INITIALS}-{4_RANDOM_CHARS}
  String _generateReferralCode(String fullName, String companyName) {
    // 1. Get Company Prefix (e.g. "Scalewealth Estate" -> "SWE" or "SE")
    final companyWords = companyName.trim().split(RegExp(r'[\s_]+'));
    String companyPrefix = '';
    for (var word in companyWords) {
      if (word.isNotEmpty) {
        companyPrefix += word[0];
      }
    }
    if (companyPrefix.length < 2) {
      // Try camel case split e.g., ScaleWealthEstate
      final camelCaseWords = companyName.split(RegExp(r'(?=[A-Z])'));
      companyPrefix = camelCaseWords.where((w) => w.trim().isNotEmpty).map((w) => w.trim()[0]).join();
    }
    if (companyPrefix.length < 2) {
      companyPrefix = companyName.substring(0, math.min(3, companyName.length));
    }
    companyPrefix = companyPrefix.toUpperCase();

    // 2. Get Partner Initials (e.g. "Ola Can" -> "OC")
    final partnerWords = fullName.trim().replaceAll(RegExp(r'\s+'), ' ').split(' ');
    String partnerInitials = '';
    if (partnerWords.isEmpty || partnerWords[0].isEmpty) {
      partnerInitials = 'PT';
    } else if (partnerWords.length >= 2) {
      partnerInitials = '${partnerWords[0][0]}${partnerWords[1][0]}';
    } else {
      partnerInitials = partnerWords[0].length >= 2 ? partnerWords[0].substring(0, 2) : '${partnerWords[0][0]}X';
    }
    partnerInitials = partnerInitials.toUpperCase();

    // 3. Generate 4 Random Alphanumeric Characters
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    final randomChars = List.generate(4, (index) => chars[rand.nextInt(chars.length)]).join();

    return '$companyPrefix-$partnerInitials-$randomChars';
  }

  /// Approves a partner, generating a referral code and enabling login/access.
  Future<bool> approvePartner(String partnerId, String fullName, String companyName) async {
    state = state.copyWith(isLoading: true);
    try {
      final referralCode = _generateReferralCode(fullName, companyName);
      final updatedProfile = await _supabaseService.updateProfileStatus(
        partnerId,
        PartnerStatus.approved,
        referralCode: referralCode,
      );
      
      // Update local state list
      final updatedPartners = state.partners.map((p) {
        return p.id == partnerId ? updatedProfile : p;
      }).toList();

      state = state.copyWith(partners: updatedPartners, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Rejects a partner.
  Future<bool> rejectPartner(String partnerId) async {
    state = state.copyWith(isLoading: true);
    try {
      final updatedProfile = await _supabaseService.updateProfileStatus(
        partnerId,
        PartnerStatus.rejected,
      );

      final updatedPartners = state.partners.map((p) {
        return p.id == partnerId ? updatedProfile : p;
      }).toList();

      state = state.copyWith(partners: updatedPartners, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Suspends a partner.
  Future<bool> suspendPartner(String partnerId) async {
    state = state.copyWith(isLoading: true);
    try {
      final updatedProfile = await _supabaseService.updateProfileStatus(
        partnerId,
        PartnerStatus.suspended,
      );

      final updatedPartners = state.partners.map((p) {
        return p.id == partnerId ? updatedProfile : p;
      }).toList();

      state = state.copyWith(partners: updatedPartners, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

/// Provider for managing partners listing and updates.
final partnerProvider = NotifierProvider<PartnerNotifier, PartnerState>(() {
  return PartnerNotifier();
});
