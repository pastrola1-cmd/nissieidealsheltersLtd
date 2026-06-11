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
  String? _loadedCompanyId;

  @override
  CompanyState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final authState = ref.watch(authProvider);
    final companyId = authState.profile?.companyId;

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
