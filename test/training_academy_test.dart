import 'package:flutter_test/flutter_test.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';

void main() {
  group('Training Academy Models & Leaderboard Tests', () {
    test('TrainingMaterial JSON serialization and points parsing', () {
      final json = {
        'id': 'mat_1',
        'company_id': 'company_123',
        'title': 'Objection Handling Guide',
        'description': 'How to close real estate deals',
        'content_text': 'Step 1: Listen. Step 2: Validate.',
        'media_url': 'http://example.com/guide.pdf',
        'media_name': 'guide.pdf',
        'points': 75,
        'created_at': '2026-07-09T00:00:00.000Z',
      };

      final mat = TrainingMaterial.fromJson(json);

      expect(mat.id, 'mat_1');
      expect(mat.points, 75);
      expect(mat.title, 'Objection Handling Guide');
      expect(mat.mediaName, 'guide.pdf');

      final serialized = mat.toJson();
      expect(serialized['points'], 75);
      expect(serialized['title'], 'Objection Handling Guide');
    });

    test('TrainingSimulator scenario parsing', () {
      final json = {
        'id': 'sim_1',
        'company_id': 'company_123',
        'title': 'Pricing Objection',
        'description': 'Handle pricing objections',
        'objection_type': 'price',
        'client_persona': 'Skeptical Investor',
        'initial_message': '₦50M is too expensive!',
        'points': 100,
        'scenarios': [
          {
            'id': 'step_1',
            'objection_text': '₦50M is too expensive!',
            'options': [
              {
                'text': 'We offer installments',
                'score': 10,
                'feedback': 'Excellent response',
                'next_step_id': null,
              }
            ]
          }
        ],
        'created_at': '2026-07-09T00:00:00.000Z',
      };

      final sim = TrainingSimulator.fromJson(json);

      expect(sim.id, 'sim_1');
      expect(sim.objectionType, 'price');
      expect(sim.scenarios.length, 1);
      expect(sim.scenarios[0].options[0].score, 10);
    });

    test('ExamQuestion and TrainingExam validation', () {
      final json = {
        'id': 'exam_1',
        'company_id': 'company_123',
        'title': 'Pro Real Estate Quiz',
        'description': 'Comprehensive test of real estate',
        'passing_score': 85,
        'time_limit_mins': 45,
        'points': 250,
        'questions': [
          {
            'id': 'q_1',
            'question_text': 'What is C of O?',
            'options': ['Certificate of Occupancy', 'Cost of Ownership', 'Contract of Option'],
            'correct_index': 0,
            'explanation': 'Certificate of Occupancy is the title deed.',
          }
        ],
        'created_at': '2026-07-09T00:00:00.000Z',
      };

      final exam = TrainingExam.fromJson(json);

      expect(exam.id, 'exam_1');
      expect(exam.passingScore, 85);
      expect(exam.questions.length, 1);
      expect(exam.questions[0].correctIndex, 0);
      expect(exam.questions[0].options[0], 'Certificate of Occupancy');
    });

    test('Leaderboard points computation logic mock simulation', () {
      final materials = [
        TrainingMaterial(
          id: 'mat_1',
          companyId: 'company_123',
          title: 'Guide 1',
          points: 50,
          createdAt: DateTime.now(),
        ),
      ];

      final simulators = [
        TrainingSimulator(
          id: 'sim_1',
          companyId: 'company_123',
          title: 'Sim 1',
          objectionType: 'price',
          clientPersona: 'Investor',
          initialMessage: 'Objection',
          points: 100,
          createdAt: DateTime.now(),
        ),
      ];

      final exams = [
        TrainingExam(
          id: 'exam_1',
          companyId: 'company_123',
          title: 'Exam 1',
          passingScore: 80,
          points: 200,
          createdAt: DateTime.now(),
        ),
      ];

      final staff = [
        Profile(
          id: 'user_1',
          companyId: 'company_123',
          fullName: 'Agent A',
          email: 'agent_a@nissie.com',
          role: UserRole.marketer,
          status: PartnerStatus.approved,
          createdAt: DateTime.now(),
        ),
      ];

      final progress = [
        TrainingProgress(
          id: 'prog_1',
          profileId: 'user_1',
          companyId: 'company_123',
          itemType: 'material',
          itemId: 'mat_1',
          completedAt: DateTime.now(),
        ),
        TrainingProgress(
          id: 'prog_2',
          profileId: 'user_1',
          companyId: 'company_123',
          itemType: 'simulator',
          itemId: 'sim_1',
          score: 85,
          completedAt: DateTime.now(),
        ),
        // Exam passed
        TrainingProgress(
          id: 'prog_3',
          profileId: 'user_1',
          companyId: 'company_123',
          itemType: 'exam',
          itemId: 'exam_1',
          score: 90, // Passed (>80)
          completedAt: DateTime.now(),
        ),
      ];

      // Points calculation
      final Map<String, int> pointsMap = {};
      for (final s in staff) {
        pointsMap[s.id] = 0;
      }

      for (final prog in progress) {
        final userId = prog.profileId;
        int pointsToAdd = 0;

        if (prog.itemType == 'material') {
          final mat = materials.firstWhere((m) => m.id == prog.itemId);
          pointsToAdd = mat.points;
        } else if (prog.itemType == 'simulator') {
          final sim = simulators.firstWhere((s) => s.id == prog.itemId);
          pointsToAdd = sim.points;
        } else if (prog.itemType == 'exam') {
          final exam = exams.firstWhere((e) => e.id == prog.itemId);
          if (prog.score != null && prog.score! >= exam.passingScore) {
            pointsToAdd = exam.points;
          }
        }

        pointsMap[userId] = (pointsMap[userId] ?? 0) + pointsToAdd;
      }

      // Expected total: 50 (material) + 100 (simulator) + 200 (exam passed) = 350 XP
      expect(pointsMap['user_1'], 350);
    });
  });
}
