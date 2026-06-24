import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/services/supabase_service.dart';

class PlatformCompanyData {
  final Company company;
  final List<Profile> admins;
  final int propertiesCount;
  final int partnersCount;
  final int managersCount;
  final int marketersCount;
  final String status; // 'active' or 'suspended' based on admin profiles

  PlatformCompanyData({
    required this.company,
    required this.admins,
    required this.propertiesCount,
    required this.partnersCount,
    required this.managersCount,
    required this.marketersCount,
    required this.status,
  });
}

class PlatformState {
  final List<PlatformCompanyData> companies;
  final int totalProperties;
  final int totalPartners;
  final double totalSalesProcessed;
  final List<Map<String, dynamic>> lpAdoptionSummary;
  final List<Map<String, dynamic>> topLandingPages;
  final bool isLoading;
  final String? errorMessage;

  const PlatformState({
    this.companies = const [],
    this.totalProperties = 0,
    this.totalPartners = 0,
    this.totalSalesProcessed = 0.0,
    this.lpAdoptionSummary = const [],
    this.topLandingPages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PlatformState copyWith({
    List<PlatformCompanyData>? companies,
    int? totalProperties,
    int? totalPartners,
    double? totalSalesProcessed,
    List<Map<String, dynamic>>? lpAdoptionSummary,
    List<Map<String, dynamic>>? topLandingPages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PlatformState(
      companies: companies ?? this.companies,
      totalProperties: totalProperties ?? this.totalProperties,
      totalPartners: totalPartners ?? this.totalPartners,
      totalSalesProcessed: totalSalesProcessed ?? this.totalSalesProcessed,
      lpAdoptionSummary: lpAdoptionSummary ?? this.lpAdoptionSummary,
      topLandingPages: topLandingPages ?? this.topLandingPages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PlatformNotifier extends Notifier<PlatformState> {
  SupabaseClient get _client => ref.read(supabaseServiceProvider).client;
  String? _loadedAdminId;

  @override
  PlatformState build() {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    if (profile != null && profile.role == UserRole.platformAdmin) {
      if (_loadedAdminId != profile.id) {
        _loadedAdminId = profile.id;
        Future.microtask(() => loadPlatformData());
        return const PlatformState(isLoading: true);
      }
      return state;
    } else {
      _loadedAdminId = null;
      return const PlatformState();
    }
  }

  Future<void> loadPlatformData() async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Fetch all companies
      final companiesResponse = await _client.from('companies').select();
      final List<Company> companiesList = List<Map<String, dynamic>>.from(companiesResponse)
          .map((json) => Company.fromJson(json))
          .toList();

      // 2. Fetch all profiles
      final profilesResponse = await _client.from('profiles').select();
      final List<Profile> allProfiles = List<Map<String, dynamic>>.from(profilesResponse)
          .map((json) => Profile.fromJson(json))
          .toList();

      // 3. Fetch all properties
      final propertiesResponse = await _client.from('properties').select('id, company_id');
      final List<Map<String, dynamic>> allProperties = List<Map<String, dynamic>>.from(propertiesResponse);

      // 4. Fetch all commissions
      final commissionsResponse = await _client.from('commissions').select('sale_price, status');
      final List<Map<String, dynamic>> allCommissions = List<Map<String, dynamic>>.from(commissionsResponse);

      // Compute stats
      final totalProperties = allProperties.length;
      final totalPartners = allProfiles.where((p) => p.role == UserRole.partner).length;
      final totalSales = allCommissions
          .where((c) => c['status'] == 'approved' || c['status'] == 'paid')
          .fold<double>(0.0, (sum, c) => sum + (c['sale_price'] as num).toDouble());

      // Assemble PlatformCompanyData
      final List<PlatformCompanyData> platformCompanies = [];
      for (var company in companiesList) {
        final companyProfiles = allProfiles.where((p) => p.companyId == company.id).toList();
        final companyAdmins = companyProfiles.where((p) => p.role == UserRole.admin).toList();
        final companyPropertiesCount = allProperties.where((p) => p['company_id'] == company.id).length;
        final companyPartnersCount = companyProfiles.where((p) => p.role == UserRole.partner).length;
        final companyManagersCount = companyProfiles.where((p) => p.role == UserRole.manager).length;
        final companyMarketersCount = companyProfiles.where((p) => p.role == UserRole.marketer).length;
        
        // Determine status: suspended wins, then pending, then active.
        final hasSuspendedAdmin = companyAdmins.any((a) => a.status == PartnerStatus.suspended);
        final hasPendingAdmin = companyAdmins.any((a) => a.status == PartnerStatus.pending);
        final companyStatus = hasSuspendedAdmin
            ? 'suspended'
            : (hasPendingAdmin ? 'pending' : 'active');

        platformCompanies.add(PlatformCompanyData(
          company: company,
          admins: companyAdmins,
          propertiesCount: companyPropertiesCount,
          partnersCount: companyPartnersCount,
          managersCount: companyManagersCount,
          marketersCount: companyMarketersCount,
          status: companyStatus,
        ));
      }

      // 5. Fetch Landing Page adoption summaries
      final adoptionResponse = await _client.from('platform_lp_adoption_summary').select();
      final List<Map<String, dynamic>> adoptionList = List<Map<String, dynamic>>.from(adoptionResponse);

      // 6. Fetch Top Landing Pages ranking
      final performanceResponse = await _client
          .from('platform_lp_performance_ranking')
          .select()
          .order('conversion_rate', ascending: false)
          .order('leads_count', ascending: false)
          .limit(5);
      final List<Map<String, dynamic>> performanceList = List<Map<String, dynamic>>.from(performanceResponse);

      state = PlatformState(
        companies: platformCompanies,
        totalProperties: totalProperties,
        totalPartners: totalPartners,
        totalSalesProcessed: totalSales,
        lpAdoptionSummary: adoptionList,
        topLandingPages: performanceList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Toggles the status of all admin profiles in a company between 'approved' and 'suspended'
  Future<bool> toggleCompanyStatus(String companyId, bool suspend) async {
    state = state.copyWith(isLoading: true);
    try {
      final newStatus = suspend ? 'suspended' : 'approved';
      
      // Update in Supabase
      await _client
          .from('profiles')
          .update({'status': newStatus})
          .eq('company_id', companyId)
          .eq('role', UserRole.admin.value);

      // Reload state
      await loadPlatformData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Approves a pending company by setting all its admin profiles to 'approved'
  Future<bool> approveCompany(String companyId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _client
          .from('profiles')
          .update({'status': 'approved'})
          .eq('company_id', companyId)
          .eq('role', UserRole.admin.value);

      // Reload state
      await loadPlatformData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Creates a new tenant company in the SaaS platform
  Future<bool> createCompany({
    required String name,
    String? email,
    String? phone,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.from('companies').insert({
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
      });

      // Reload
      await loadPlatformData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Updates a company's subscription plan (tier, status, expiry)
  Future<bool> updateCompanySubscription(
    String companyId, {
    required String tier,
    required String status,
    required DateTime expiresAt,
    int? customLeadLimit,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(supabaseServiceProvider).updateCompanySubscription(
            companyId,
            tier: tier,
            status: status,
            expiresAt: expiresAt,
            customLeadLimit: customLeadLimit,
          );
      await loadPlatformData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Deletes a company and cascades deletions to its data
  Future<bool> deleteCompany(String companyId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.from('companies').delete().eq('id', companyId);
      await loadPlatformData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Toggles the public visibility of a company on the signup dropdown
  Future<bool> toggleCompanyVisibility(String companyId, bool isHidden) async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.from('companies').update({'is_hidden': isHidden}).eq('id', companyId);
      await loadPlatformData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final platformProvider = NotifierProvider<PlatformNotifier, PlatformState>(() {
  return PlatformNotifier();
});
