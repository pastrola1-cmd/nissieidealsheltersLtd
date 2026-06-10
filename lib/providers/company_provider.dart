import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/auth_state.dart';
import 'package:ppn/services/supabase_service.dart';

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

class CompanyNotifier extends Notifier<CompanyState> {
  late final SupabaseService _supabaseService;

  @override
  CompanyState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _initialize();
    return const CompanyState();
  }

  void _initialize() {
    // Listen to authentication status changes to load the tenant details
    ref.listen<AuthState>(authProvider, (previous, next) {
      final companyId = next.profile?.companyId;
      if (companyId != null) {
        loadCompany(companyId);
      } else {
        state = const CompanyState();
      }
    }, fireImmediately: true);
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
