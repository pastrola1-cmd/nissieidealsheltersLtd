import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

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
  late SupabaseService _supabaseService;
  final _secureStorage = const FlutterSecureStorage();
  String? _loadedProfileId;

  @override
  LeadState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    if (profile != null) {
      if (_loadedProfileId != profile.id) {
        _loadedProfileId = profile.id;
        Future.microtask(() => loadLeads());
        return const LeadState(isLoading: true);
      }
      return state;
    } else {
      _loadedProfileId = null;
      return const LeadState();
    }
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

  /// Assigns a lead to a marketer/agent.
  Future<bool> assignAgent(String leadId, String? agentId) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _supabaseService.update('leads', leadId, {
        'assigned_agent_id': agentId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      final updatedLead = Lead.fromJson(response);
      
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
      Company? company = ref.read(authProvider).company ?? ref.read(companyProvider).company;
      if (company == null) {
        company = await _supabaseService.getCompany(profile.companyId!);
      }

      if (company != null) {
        final limit = company.effectiveLeadLimit;
        final monthlyCount = await _supabaseService.getMonthlyLeadCount(profile.companyId!);
        if (monthlyCount >= limit) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Monthly lead creation limit reached ($monthlyCount/$limit). Upgrade your plan to add more.',
          );
          return false;
        }
      }

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
        if (profile.role == UserRole.marketer) 'assigned_agent_id': profile.id,
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
      final campaignId = await _secureStorage.read(key: 'last_referral_campaign_id');

      if (referralCode == null || propertyId == null) {
        return false;
      }

      final partner = await _supabaseService.getProfileByReferralCode(referralCode);
      if (partner == null || partner.companyId == null) {
        // Clear broken session
        await _clearStoredReferral();
        return false;
      }

      // Check limit before creating referral lead
      final company = await _supabaseService.getCompany(partner.companyId!);
      if (company != null) {
        final limit = company.effectiveLeadLimit;
        final monthlyCount = await _supabaseService.getMonthlyLeadCount(partner.companyId!);
        if (monthlyCount >= limit) {
          debugPrint('Referral lead block: Monthly limit reached ($monthlyCount/$limit) for company ${company.name}');
          await _clearStoredReferral();
          return false;
        }
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
        'campaign_id': campaignId,
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

  /// Checks if a lead with the same phone or email exists locally or in database.
  Future<Lead?> checkDuplicateLead(String phone, String email) async {
    final trimmedPhone = phone.trim().toLowerCase();
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedPhone.isEmpty && trimmedEmail.isEmpty) return null;

    // First check locally
    for (final lead in state.leads) {
      final leadPhone = lead.buyerPhone.trim().toLowerCase();
      final leadEmail = lead.buyerEmail?.trim().toLowerCase() ?? '';
      if (trimmedPhone.isNotEmpty && leadPhone == trimmedPhone) return lead;
      if (trimmedEmail.isNotEmpty && leadEmail == trimmedEmail) return lead;
    }

    // Then check database (fallback)
    final profile = ref.read(authProvider).profile;
    if (profile == null) return null;
    final companyId = profile.companyId;
    if (companyId == null) return null;

    try {
      final client = _supabaseService.client;
      var query = client.from('leads').select().eq('company_id', companyId);
      
      String orFilter = '';
      if (trimmedPhone.isNotEmpty) {
        orFilter += 'buyer_phone.ilike.${trimmedPhone}';
      }
      if (trimmedEmail.isNotEmpty) {
        if (orFilter.isNotEmpty) orFilter += ',';
        orFilter += 'buyer_email.ilike.${trimmedEmail}';
      }
      
      if (orFilter.isNotEmpty) {
        final res = await query.or(orFilter).maybeSingle();
        if (res != null) {
          return Lead.fromJson(res);
        }
      }
    } catch (e) {
      debugPrint('Error checking remote duplicate: $e');
    }
    return null;
  }

  /// Performs bulk updates on leads (e.g. assign to agent, change stage).
  Future<bool> bulkUpdateLeads({
    required List<String> leadIds,
    String? assignedAgentId,
    LeadStage? stage,
  }) async {
    if (leadIds.isEmpty) return true;
    state = state.copyWith(isLoading: true);
    try {
      final Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (assignedAgentId != null) {
        updateData['assigned_agent_id'] = assignedAgentId == 'unassign' ? null : assignedAgentId;
      }
      if (stage != null) {
        updateData['stage'] = stage.value;
      }

      final updatedRows = await _supabaseService.bulkUpdate('leads', leadIds, updateData);
      final updatedLeads = updatedRows.map((r) => Lead.fromJson(r)).toList();

      final Map<String, Lead> updatedMap = {for (var l in updatedLeads) l.id: l};
      final newList = state.leads.map((l) {
        return updatedMap.containsKey(l.id) ? updatedMap[l.id]! : l;
      }).toList();

      state = state.copyWith(leads: newList, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Performs bulk deletion of leads.
  Future<bool> bulkDeleteLeads(List<String> leadIds) async {
    if (leadIds.isEmpty) return true;
    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.bulkDelete('leads', leadIds);

      final Set<String> deletedSet = leadIds.toSet();
      final newList = state.leads.where((l) => !deletedSet.contains(l.id)).toList();

      state = state.copyWith(leads: newList, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Performs bulk insertion of leads (CSV import).
  Future<bool> bulkInsertLeads(List<Map<String, dynamic>> dataList) async {
    if (dataList.isEmpty) return true;
    final profile = ref.read(authProvider).profile;
    if (profile == null || profile.companyId == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Company ID not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      Company? company = ref.read(authProvider).company ?? ref.read(companyProvider).company;
      if (company == null) {
        company = await _supabaseService.getCompany(profile.companyId!);
      }

      if (company != null) {
        final limit = company.effectiveLeadLimit;
        final monthlyCount = await _supabaseService.getMonthlyLeadCount(profile.companyId!);
        if (monthlyCount >= limit) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Monthly lead creation limit reached ($monthlyCount/$limit). Upgrade your plan to add more.',
          );
          return false;
        }
        if (monthlyCount + dataList.length > limit) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Importing ${dataList.length} leads would exceed your monthly lead limit (${monthlyCount + dataList.length}/$limit). Please upgrade your plan.',
          );
          return false;
        }
      }

      final insertedRows = await _supabaseService.bulkInsert('leads', dataList);
      final insertedLeads = insertedRows.map((r) => Lead.fromJson(r)).toList();

      state = state.copyWith(
        leads: [...insertedLeads, ...state.leads],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> _clearStoredReferral() async {
    await _secureStorage.delete(key: 'last_referral_code');
    await _secureStorage.delete(key: 'last_referral_property_id');
    await _secureStorage.delete(key: 'last_referral_campaign_id');
  }
}

final leadProvider = NotifierProvider<LeadNotifier, LeadState>(() {
  return LeadNotifier();
});

/// Fetches all marketers/agents registered in the current user's company.
final agencyMarketersProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
  final authState = ref.watch(authProvider);
  final companyId = authState.profile?.companyId;
  if (companyId == null) return [];
  
  final service = ref.watch(supabaseServiceProvider);
  return service.getProfilesByRole(UserRole.marketer, companyId: companyId);
});

/// Fetches the monthly lead count for the current company.
final monthlyLeadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final authState = ref.watch(authProvider);
  final companyId = authState.profile?.companyId;
  if (companyId == null) return 0;
  
  final service = ref.watch(supabaseServiceProvider);
  // Also watch leadProvider to refresh this count when leads are created/inserted/deleted
  ref.watch(leadProvider);
  return service.getMonthlyLeadCount(companyId);
});
