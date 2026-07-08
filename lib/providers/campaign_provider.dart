import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class CampaignState {
  final List<Campaign> campaigns;
  final bool isLoading;
  final String? errorMessage;

  const CampaignState({
    this.campaigns = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CampaignState copyWith({
    List<Campaign>? campaigns,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CampaignState(
      campaigns: campaigns ?? this.campaigns,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CampaignNotifier extends Notifier<CampaignState> {
  late SupabaseService _supabaseService;
  String? _loadedCompanyId;

  @override
  CampaignState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final authState = ref.watch(authProvider);
    final companyId = authState.profile?.companyId;

    if (companyId != null) {
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() => loadCampaigns(companyId));
        return const CampaignState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const CampaignState();
    }
  }

  Future<void> loadCampaigns(String companyId) async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _supabaseService.getCampaigns(companyId);
      state = CampaignState(campaigns: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<Campaign?> saveCampaign({
    required String? propertyId,
    required Map<String, dynamic> inputData,
    required Map<String, dynamic> outputData,
    required String platform,
  }) async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) {
      state = state.copyWith(errorMessage: 'User profile not found.');
      return null;
    }
    final companyId = profile.companyId;
    if (companyId == null) {
      state = state.copyWith(errorMessage: 'Company ID not found.');
      return null;
    }

    try {
      final data = {
        'company_id': companyId,
        'property_id': propertyId,
        'created_by': profile.id,
        'input_data': inputData,
        'output_data': outputData,
        'platform': platform,
      };

      final insertedRaw = await _supabaseService.insert('campaigns', data);
      final campaign = Campaign.fromJson(insertedRaw);

      final current = List<Campaign>.from(state.campaigns);
      current.insert(0, campaign);
      state = state.copyWith(campaigns: current);
      return campaign;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }
}

final campaignProvider = NotifierProvider<CampaignNotifier, CampaignState>(() {
  return CampaignNotifier();
});
