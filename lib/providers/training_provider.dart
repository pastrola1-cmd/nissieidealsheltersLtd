import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/services/training_service.dart';

class TrainingState {
  final List<TrainingMaterial> materials;
  final List<TrainingSimulator> simulators;
  final List<TrainingExam> exams;
  final List<TrainingProgress> progress;
  final List<TrainingBadge> badges;
  final List<Profile> companyStaff;
  final bool isLoading;
  final String? errorMessage;

  const TrainingState({
    this.materials = const [],
    this.simulators = const [],
    this.exams = const [],
    this.progress = const [],
    this.badges = const [],
    this.companyStaff = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  TrainingState copyWith({
    List<TrainingMaterial>? materials,
    List<TrainingSimulator>? simulators,
    List<TrainingExam>? exams,
    List<TrainingProgress>? progress,
    List<TrainingBadge>? badges,
    List<Profile>? companyStaff,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TrainingState(
      materials: materials ?? this.materials,
      simulators: simulators ?? this.simulators,
      exams: exams ?? this.exams,
      progress: progress ?? this.progress,
      badges: badges ?? this.badges,
      companyStaff: companyStaff ?? this.companyStaff,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TrainingNotifier extends Notifier<TrainingState> {
  late TrainingService _trainingService;
  late SupabaseService _supabaseService;
  String? _loadedCompanyId;

  @override
  TrainingState build() {
    _trainingService = ref.watch(trainingServiceProvider);
    _supabaseService = ref.watch(supabaseServiceProvider);

    final authState = ref.watch(authProvider);
    final company = authState.company;

    if (company != null) {
      if (_loadedCompanyId != company.id) {
        _loadedCompanyId = company.id;
        Future.microtask(() => loadAllTrainingData());
        return const TrainingState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const TrainingState();
    }
  }

  Future<void> loadAllTrainingData() async {
    final companyId = _loadedCompanyId;
    if (companyId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final materials = await _trainingService.getMaterials(companyId);
      final simulators = await _trainingService.getSimulators(companyId);
      final exams = await _trainingService.getExams(companyId);
      final progress = await _trainingService.getProgress(companyId);
      final badges = await _trainingService.getBadges(companyId);

      // Load company staff/partners for leaderboard
      final staffResponse = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('company_id', companyId);
      final staff = (staffResponse as List).map((x) => Profile.fromJson(x)).toList();

      state = TrainingState(
        materials: materials,
        simulators: simulators,
        exams: exams,
        progress: progress,
        badges: badges,
        companyStaff: staff,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Add/Delete Material
  Future<bool> addMaterial(String title, String? description, String? contentText, String? mediaUrl, String? mediaName, int points) async {
    final companyId = _loadedCompanyId;
    if (companyId == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final newMat = await _trainingService.createMaterial({
        'company_id': companyId,
        'title': title,
        'description': description,
        'content_text': contentText,
        'media_url': mediaUrl,
        'media_name': mediaName,
        'points': points,
      });

      state = state.copyWith(
        materials: [...state.materials, newMat],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteMaterial(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _trainingService.deleteMaterial(id);
      state = state.copyWith(
        materials: state.materials.where((m) => m.id != id).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Add/Delete Simulator
  Future<bool> addSimulator(String title, String? description, String objectionType, String clientPersona, String initialMessage, List<SimulatorScenarioStep> scenarios, int points) async {
    final companyId = _loadedCompanyId;
    if (companyId == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final newSim = await _trainingService.createSimulator({
        'company_id': companyId,
        'title': title,
        'description': description,
        'objection_type': objectionType,
        'client_persona': clientPersona,
        'initial_message': initialMessage,
        'scenarios': scenarios.map((s) => s.toJson()).toList(),
        'points': points,
      });

      state = state.copyWith(
        simulators: [...state.simulators, newSim],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteSimulator(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _trainingService.deleteSimulator(id);
      state = state.copyWith(
        simulators: state.simulators.where((s) => s.id != id).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Add/Delete Exam
  Future<bool> addExam(String title, String? description, int passingScore, int timeLimitMins, List<ExamQuestion> questions, int points) async {
    final companyId = _loadedCompanyId;
    if (companyId == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final newExam = await _trainingService.createExam({
        'company_id': companyId,
        'title': title,
        'description': description,
        'passing_score': passingScore,
        'time_limit_mins': timeLimitMins,
        'questions': questions.map((q) => q.toJson()).toList(),
        'points': points,
      });

      state = state.copyWith(
        exams: [...state.exams, newExam],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteExam(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _trainingService.deleteExam(id);
      state = state.copyWith(
        exams: state.exams.where((e) => e.id != id).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Progress Logging
  Future<bool> recordProgress({
    required String itemType,
    required String itemId,
    int? score,
  }) async {
    final profile = ref.read(authProvider).profile;
    final companyId = _loadedCompanyId;
    if (profile == null || companyId == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final newProg = await _trainingService.logProgress({
        'profile_id': profile.id,
        'company_id': companyId,
        'item_type': itemType,
        'item_id': itemId,
        'score': score,
      });

      // Update local progress list
      final updatedList = state.progress.where((p) => p.id != newProg.id).toList();
      updatedList.add(newProg);

      state = state.copyWith(
        progress: updatedList,
        isLoading: false,
      );

      // Perform auto-badge unlock logic
      await _checkAndUnlockBadges(profile.id, companyId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> _checkAndUnlockBadges(String profileId, String companyId) async {
    final userProgress = state.progress.where((p) => p.profileId == profileId).toList();
    
    // 1. "Academy Starter" badge (read first material)
    final readMaterials = userProgress.where((p) => p.itemType == 'material').length;
    if (readMaterials >= 1) {
      final b = await _trainingService.unlockBadge(profileId, companyId, 'Academy Starter');
      _addBadgeLocally(b);
    }

    // 2. "Objection Crusher" badge (completed first simulator)
    final completedSimulators = userProgress.where((p) => p.itemType == 'simulator').length;
    if (completedSimulators >= 1) {
      final b = await _trainingService.unlockBadge(profileId, companyId, 'Objection Crusher');
      _addBadgeLocally(b);
    }

    // 3. "Nissie Property Expert" badge (passed first exam with score >= 80)
    final passedExams = userProgress.where((p) {
      if (p.itemType != 'exam' || p.score == null) return false;
      final exam = state.exams.cast<TrainingExam?>().firstWhere((e) => e?.id == p.itemId, orElse: () => null);
      return exam != null && p.score! >= exam.passingScore;
    }).length;

    if (passedExams >= 1) {
      final b = await _trainingService.unlockBadge(profileId, companyId, 'Nissie Property Expert');
      _addBadgeLocally(b);
    }

    // 4. "Elite Closer" badge (completed 3 simulators and passed 2 exams)
    if (completedSimulators >= 3 && passedExams >= 2) {
      final b = await _trainingService.unlockBadge(profileId, companyId, 'Elite Closer');
      _addBadgeLocally(b);
    }
  }

  void _addBadgeLocally(TrainingBadge b) {
    if (!state.badges.any((x) => x.id == b.id)) {
      state = state.copyWith(badges: [...state.badges, b]);
    }
  }

  // Helper getters for UI calculations
  Map<String, int> getLeaderboardPoints() {
    final Map<String, int> pointsMap = {};
    for (final staff in state.companyStaff) {
      pointsMap[staff.id] = 0;
    }

    for (final prog in state.progress) {
      final userId = prog.profileId;
      int pointsToAdd = 0;

      if (prog.itemType == 'material') {
        final mat = state.materials.cast<TrainingMaterial?>().firstWhere((m) => m?.id == prog.itemId, orElse: () => null);
        pointsToAdd = mat?.points ?? 50;
      } else if (prog.itemType == 'simulator') {
        final sim = state.simulators.cast<TrainingSimulator?>().firstWhere((s) => s?.id == prog.itemId, orElse: () => null);
        pointsToAdd = sim?.points ?? 100;
      } else if (prog.itemType == 'exam') {
        final exam = state.exams.cast<TrainingExam?>().firstWhere((e) => e?.id == prog.itemId, orElse: () => null);
        if (exam != null && prog.score != null && prog.score! >= exam.passingScore) {
          pointsToAdd = exam.points;
        }
      }

      pointsMap[userId] = (pointsMap[userId] ?? 0) + pointsToAdd;
    }

    return pointsMap;
  }
}

final trainingProvider = NotifierProvider<TrainingNotifier, TrainingState>(() {
  return TrainingNotifier();
});
