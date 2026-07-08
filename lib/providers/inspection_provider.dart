import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

class InspectionState {
  final List<Inspection> inspections;
  final bool isLoading;
  final String? errorMessage;

  const InspectionState({
    this.inspections = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  InspectionState copyWith({
    List<Inspection>? inspections,
    bool? isLoading,
    String? errorMessage,
  }) {
    return InspectionState(
      inspections: inspections ?? this.inspections,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class InspectionNotifier extends Notifier<InspectionState> {
  late SupabaseService _supabaseService;
  final _secureStorage = const FlutterSecureStorage();
  String? _loadedProfileId;

  @override
  InspectionState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    if (profile != null) {
      if (_loadedProfileId != profile.id) {
        _loadedProfileId = profile.id;
        Future.microtask(() => loadInspections());
        return const InspectionState(isLoading: true);
      }
      return state;
    } else {
      _loadedProfileId = null;
      return const InspectionState();
    }
  }

  /// Loads inspections based on the user's role and scopes.
  Future<void> loadInspections() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    state = state.copyWith(isLoading: true);
    try {
      List<Inspection> list;
      if (profile.role == UserRole.buyer) {
        list = await _supabaseService.getInspections(
          buyerId: profile.id,
        );
      } else if (profile.role == UserRole.partner) {
        list = await _supabaseService.getInspections(
          partnerId: profile.id,
        );
      } else {
        // Admin or Platform Admin
        list = await _supabaseService.getInspections(
          companyId: profile.companyId,
        );
      }
      // Sort inspections by scheduled date and time descending, or created_at descending
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = InspectionState(inspections: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Books an inspection as a buyer, auto-creating a lead if none exists.
  Future<bool> bookInspection({
    required String propertyId,
    required String scheduledDate,
    required String scheduledTime,
    String? notes,
  }) async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile == null) {
      state = state.copyWith(errorMessage: 'Authentication error: User profile not found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final leadNotifier = ref.read(leadProvider.notifier);
      final leadState = ref.read(leadProvider);

      // 1. Try to find an existing lead for this buyer & property listing
      Lead? lead = leadState.leads.cast<Lead?>().firstWhere(
            (l) => l?.propertyId == propertyId && l?.buyerId == authProfile.id,
            orElse: () => null,
          );

      // 2. If no lead exists, auto-provision one (checking secure storage for referral attribution)
      if (lead == null) {
        final lastRefCode = await _secureStorage.read(key: 'last_referral_code');
        final lastRefPropId = await _secureStorage.read(key: 'last_referral_property_id');

        String? partnerId;
        String sourceChannel = 'website';

        if (lastRefCode != null && lastRefPropId == propertyId) {
          final partner = await _supabaseService.getProfileByReferralCode(lastRefCode);
          if (partner != null) {
            partnerId = partner.id;
            sourceChannel = 'whatsapp';
          }
        }

        final Map<String, dynamic> leadInsertData = {
          'company_id': authProfile.companyId,
          'property_id': propertyId,
          'partner_id': partnerId,
          'buyer_id': authProfile.id,
          'buyer_name': authProfile.fullName ?? 'Buyer Client',
          'buyer_phone': authProfile.phone ?? '',
          'buyer_email': authProfile.email,
          'source_channel': sourceChannel,
          'stage': LeadStage.newLead.value,
        };

        lead = await _supabaseService.createLead(leadInsertData);
        // Refresh leads in the notifier
        await leadNotifier.loadLeads();
      }

      // 3. Create the inspection record
      final Map<String, dynamic> inspectionInsertData = {
        'company_id': authProfile.companyId,
        'property_id': propertyId,
        'lead_id': lead.id,
        'buyer_id': authProfile.id,
        'partner_id': lead.partnerId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'status': InspectionStatus.pending.value,
        'notes': notes,
      };

      final newInspection = await _supabaseService.createInspection(inspectionInsertData);

      // 4. Update the lead stage to 'inspection_booked'
      await leadNotifier.updateStage(lead.id, LeadStage.inspectionBooked);

      // Update local inspections list
      state = state.copyWith(
        inspections: [newInspection, ...state.inspections],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Updates an inspection's status (Admin operation).
  Future<bool> updateStatus(
    String inspectionId,
    InspectionStatus status, {
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = await _supabaseService.updateInspectionStatus(
        inspectionId,
        status,
        notes: notes,
      );

      // Update local state
      final updatedList = state.inspections.map((i) {
        return i.id == inspectionId ? updated : i;
      }).toList();

      state = state.copyWith(inspections: updatedList, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final inspectionProvider = NotifierProvider<InspectionNotifier, InspectionState>(() {
  return InspectionNotifier();
});
