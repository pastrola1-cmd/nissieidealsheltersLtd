import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class CompanyState {
  final Company? company;
  final bool isLoading;
  final String? errorMessage;

  const CompanyState({
    this.company,
    this.isLoading = false,
    this.errorMessage,
  });

  CompanyState copyWith({
    Company? company,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CompanyState(
      company: company ?? this.company,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SelectedCompanyIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final authState = ref.watch(authProvider);
    return authState.profile?.companyId;
  }

  @override
  set state(String? value) {
    super.state = value;
  }
}

final selectedCompanyIdProvider = NotifierProvider<SelectedCompanyIdNotifier, String?>(() {
  return SelectedCompanyIdNotifier();
});

class CompanyNotifier extends Notifier<CompanyState> {
  late SupabaseService _supabaseService;
  String? _loadedCompanyId;

  @override
  CompanyState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final companyId = ref.watch(selectedCompanyIdProvider);

    if (companyId != null) {
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() => loadCompany(companyId));
        return const CompanyState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const CompanyState();
    }
  }

  Future<void> loadCompany(String companyId) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _supabaseService.getById('companies', companyId);
      if (data != null) {
        state = CompanyState(company: Company.fromJson(data), isLoading: false);
      } else {
        state = const CompanyState(errorMessage: 'Company details not found.', isLoading: false);
      }
    } catch (e) {
      state = CompanyState(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<bool> updateCompany({
    required String name,
    String? email,
    String? phone,
    String? address,
    String? logoUrl,
    String? fbPixelId,
    String? fbCapiToken,
    bool? lpModuleEnabled,
    String? whatsappPhoneNumberId,
    String? whatsappWabaId,
    String? whatsappAccessToken,
    bool? whatsappEnabled,
    String? whatsappTemplateName,
    String? customDomain,
  }) async {
    final companyId = state.company?.id;
    if (companyId == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final updatedData = await _supabaseService.update('companies', companyId, {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'logo_url': logoUrl,
        'fb_pixel_id': fbPixelId,
        'fb_capi_token': fbCapiToken,
        if (lpModuleEnabled != null) 'lp_module_enabled': lpModuleEnabled,
        'whatsapp_phone_number_id': whatsappPhoneNumberId,
        'whatsapp_waba_id': whatsappWabaId,
        'whatsapp_access_token': whatsappAccessToken,
        if (whatsappEnabled != null) 'whatsapp_enabled': whatsappEnabled,
        'whatsapp_template_name': whatsappTemplateName,
        'custom_domain': customDomain,
      });
      state = CompanyState(company: Company.fromJson(updatedData), isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final companyProvider = NotifierProvider<CompanyNotifier, CompanyState>(() {
  return CompanyNotifier();
});

final allCompaniesProvider = FutureProvider.autoDispose<List<Company>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getCompanies(excludeHidden: true);
});
