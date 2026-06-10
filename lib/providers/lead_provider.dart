import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/auth_state.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/core/enums/enums.dart';

class LeadState {
  final List<Lead> leads;
  final bool isLoading;
  final String? errorMessage;

  const LeadState({
    this.leads = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  LeadState copyWith({
    List<Lead>? leads,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LeadState(
      leads: leads ?? this.leads,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class LeadNotifier extends Notifier<LeadState> {
  late final SupabaseService _supabaseService;
  final _secureStorage = const FlutterSecureStorage();

  @override
  LeadState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _initialize();
    return const LeadState();
  }

  void _initialize() {
    // Listen to auth state to load lead portfolio automatically
    ref.listen<AuthState>(authProvider, (previous, next) {
      final profile = next.profile;
      if (profile != null) {
        loadLeads();
      } else {
        state = const LeadState();
      }
    }, fireImmediately: true);
  }

  /// Loads leads scoped by role and company.
  Future<void> loadLeads() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    state = state.copyWith(isLoading: true);
    try {
      List<Lead> list;
      if (profile.role == UserRole.partner) {
        list = await _supabaseService.getLeads(
          companyId: profile.companyId,
          partnerId: profile.id,
        );
      } else {
        list = await _supabaseService.getLeads(
          companyId: profile.companyId,
        );
      }
      // Sort by updated_at or created_at descending
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = LeadState(leads: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Mutates pipeline stage of a lead.
  Future<bool> updateStage(String leadId, LeadStage stage, {String? notes}) async {
    state = state.copyWith(isLoading: true);
    try {
      final updatedLead = await _supabaseService.updateLeadStage(leadId, stage, notes: notes);
      
      // Update local state
      final updatedLeads = state.leads.map((l) {
        return l.id == leadId ? updatedLead : l;
      }).toList();
      
      state = state.copyWith(leads: updatedLeads, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Creates a lead manually (Admin function).
  Future<bool> createLead({
    required String propertyId,
    required String buyerName,
    required String buyerPhone,
    String? buyerEmail,
    required String sourceChannel,
    String? partnerId,
    String? notes,
  }) async {
    final profile = ref.read(authProvider).profile;
    if (profile == null || profile.companyId == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Company ID not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final Map<String, dynamic> insertData = {
        'company_id': profile.companyId,
        'property_id': propertyId,
        'partner_id': partnerId,
        'buyer_name': buyerName,
        'buyer_phone': buyerPhone,
        'buyer_email': buyerEmail,
        'source_channel': sourceChannel,
        'stage': LeadStage.newLead.value,
        'notes': notes,
      };

      final newLead = await _supabaseService.createLead(insertData);
      
      state = state.copyWith(
        leads: [newLead, ...state.leads],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Checks secure storage for a referral code and auto-attributes a lead.
  Future<bool> checkAndCreateReferralLead({
    required String buyerId,
    required String buyerName,
    required String buyerPhone,
    String? buyerEmail,
  }) async {
    try {
      final referralCode = await _secureStorage.read(key: 'last_referral_code');
      final propertyId = await _secureStorage.read(key: 'last_referral_property_id');

      if (referralCode == null || propertyId == null) {
        return false;
      }

      final partner = await _supabaseService.getProfileByReferralCode(referralCode);
      if (partner == null) {
        // Clear broken session
        await _clearStoredReferral();
        return false;
      }

      final Map<String, dynamic> insertData = {
        'company_id': partner.companyId,
        'property_id': propertyId,
        'partner_id': partner.id,
        'buyer_id': buyerId,
        'buyer_name': buyerName,
        'buyer_phone': buyerPhone,
        'buyer_email': buyerEmail,
        'source_channel': 'whatsapp',
        'stage': LeadStage.newLead.value,
      };

      await _supabaseService.createLead(insertData);
      
      // Clear referral cookie session
      await _clearStoredReferral();
      
      // Reload lead list
      await loadLeads();
      return true;
    } catch (e) {
      debugPrint('Error creating referral lead: $e');
      return false;
    }
  }

  Future<void> _clearStoredReferral() async {
    await _secureStorage.delete(key: 'last_referral_code');
    await _secureStorage.delete(key: 'last_referral_property_id');
  }
}

final leadProvider = NotifierProvider<LeadNotifier, LeadState>(() {
  return LeadNotifier();
});
