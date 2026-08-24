import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/attendance_record.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

/// State representation for Staff Attendance operations.
class AttendanceState {
  final AttendanceRecord? todaySession;
  final List<AttendanceRecord> myHistory;
  final List<AttendanceRecord> companyRecords;
  final bool isLoading;
  final String? errorMessage;

  const AttendanceState({
    this.todaySession,
    this.myHistory = const [],
    this.companyRecords = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isClockedIn => todaySession != null && todaySession!.isClockedIn;

  AttendanceState copyWith({
    AttendanceRecord? todaySession,
    bool clearTodaySession = false,
    List<AttendanceRecord>? myHistory,
    List<AttendanceRecord>? companyRecords,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AttendanceState(
      todaySession: clearTodaySession ? null : (todaySession ?? this.todaySession),
      myHistory: myHistory ?? this.myHistory,
      companyRecords: companyRecords ?? this.companyRecords,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Manages staff clock-in / clock-out transitions and company attendance queries.
class AttendanceNotifier extends Notifier<AttendanceState> {
  late SupabaseService _supabaseService;

  @override
  AttendanceState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    final profile = ref.watch(authProvider).profile;
    if (profile != null) {
      Future.microtask(() => loadTodayAttendance());
    }
    return const AttendanceState();
  }

  /// Loads today's attendance record for the logged-in staff member.
  Future<void> loadTodayAttendance() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final record = await _supabaseService.getTodayAttendance(profile.id);
      state = state.copyWith(todaySession: record, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Clocks in the current staff member.
  Future<bool> clockIn({
    required String workMode,
    double? locationLat,
    double? locationLng,
    String? locationName,
    String? propertyId,
    String? propertyName,
  }) async {
    final profile = ref.read(authProvider).profile;
    if (profile == null || profile.companyId == null) {
      state = state.copyWith(errorMessage: 'User profile or company ID not loaded.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _supabaseService.clockInStaff(
        companyId: profile.companyId!,
        userId: profile.id,
        workMode: workMode,
        locationLat: locationLat,
        locationLng: locationLng,
        locationName: locationName,
        propertyId: propertyId,
        propertyName: propertyName,
      );

      state = state.copyWith(
        todaySession: session,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      debugPrint('clockIn error: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Clocks out the current active session with mandatory daily wrap-up summary.
  Future<bool> clockOut({
    required String notes,
    double? clockOutLat,
    double? clockOutLng,
    String? clockOutLocationName,
  }) async {
    final currentSession = state.todaySession;
    if (currentSession == null) {
      state = state.copyWith(errorMessage: 'No active clock-in session found to clock out.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updated = await _supabaseService.clockOutStaff(
        sessionId: currentSession.id,
        notes: notes,
        clockOutLat: clockOutLat,
        clockOutLng: clockOutLng,
        clockOutLocationName: clockOutLocationName,
      );

      state = state.copyWith(
        todaySession: updated,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      debugPrint('clockOut error: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Loads attendance history for a specific staff member.
  Future<void> loadStaffHistory(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _supabaseService.getStaffAttendanceHistory(userId);
      state = state.copyWith(myHistory: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Loads all staff attendance records for a specific date (for Managers & Admins).
  Future<List<AttendanceRecord>> loadCompanyAttendanceForDate(DateTime date) async {
    final companyId = ref.read(authProvider).profile?.companyId;
    if (companyId == null) return [];

    try {
      final list = await _supabaseService.getCompanyAttendanceForDate(companyId, date);
      state = state.copyWith(companyRecords: list);
      return list;
    } catch (e) {
      debugPrint('loadCompanyAttendanceForDate error: $e');
      return [];
    }
  }
}

/// Global provider for staff attendance management.
final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceState>(() {
  return AttendanceNotifier();
});

/// FutureProvider to fetch company-wide attendance for any specific date.
final companyAttendanceForDateProvider = FutureProvider.autoDispose.family<List<AttendanceRecord>, DateTime>((ref, date) async {
  final authState = ref.watch(authProvider);
  final companyId = authState.profile?.companyId;
  if (companyId == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  return await service.getCompanyAttendanceForDate(companyId, date);
});

/// FutureProvider to fetch individual staff member's attendance history.
final staffAttendanceHistoryProvider = FutureProvider.autoDispose.family<List<AttendanceRecord>, String>((ref, userId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getStaffAttendanceHistory(userId);
});
