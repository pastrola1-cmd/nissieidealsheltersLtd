import 'package:flutter/foundation.dart';

@immutable
class TrainingMaterial {
  final String id;
  final String companyId;
  final String title;
  final String? description;
  final String? contentText;
  final String? mediaUrl;
  final String? mediaName;
  final int points;
  final DateTime createdAt;

  const TrainingMaterial({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    this.contentText,
    this.mediaUrl,
    this.mediaName,
    this.points = 50,
    required this.createdAt,
  });

  factory TrainingMaterial.fromJson(Map<String, dynamic> json) {
    return TrainingMaterial(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      contentText: json['content_text'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaName: json['media_name'] as String?,
      points: json['points'] as int? ?? 50,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'description': description,
      'content_text': contentText,
      'media_url': mediaUrl,
      'media_name': mediaName,
      'points': points,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class SimulatorOption {
  final String text;
  final int score;
  final String feedback;
  final String? nextStepId;

  const SimulatorOption({
    required this.text,
    required this.score,
    required this.feedback,
    this.nextStepId,
  });

  factory SimulatorOption.fromJson(Map<String, dynamic> json) {
    return SimulatorOption(
      text: json['text'] as String,
      score: json['score'] as int? ?? 0,
      feedback: json['feedback'] as String? ?? '',
      nextStepId: json['next_step_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'score': score,
      'feedback': feedback,
      'next_step_id': nextStepId,
    };
  }
}

@immutable
class SimulatorScenarioStep {
  final String id;
  final String objectionText;
  final List<SimulatorOption> options;

  const SimulatorScenarioStep({
    required this.id,
    required this.objectionText,
    required this.options,
  });

  factory SimulatorScenarioStep.fromJson(Map<String, dynamic> json) {
    return SimulatorScenarioStep(
      id: json['id'] as String,
      objectionText: json['objection_text'] as String,
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => SimulatorOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'objection_text': objectionText,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}

@immutable
class TrainingSimulator {
  final String id;
  final String companyId;
  final String title;
  final String? description;
  final String objectionType; // 'price', 'location', 'legal', 'trust', 'custom'
  final String clientPersona;
  final String initialMessage;
  final List<SimulatorScenarioStep> scenarios;
  final int points;
  final DateTime createdAt;

  const TrainingSimulator({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    required this.objectionType,
    required this.clientPersona,
    required this.initialMessage,
    this.scenarios = const [],
    this.points = 100,
    required this.createdAt,
  });

  factory TrainingSimulator.fromJson(Map<String, dynamic> json) {
    List<SimulatorScenarioStep> parsedScenarios = [];
    if (json['scenarios'] != null) {
      if (json['scenarios'] is List) {
        parsedScenarios = (json['scenarios'] as List)
            .map((s) => SimulatorScenarioStep.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    }
    return TrainingSimulator(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      objectionType: json['objection_type'] as String? ?? 'custom',
      clientPersona: json['client_persona'] as String? ?? 'Skeptical Prospect',
      initialMessage: json['initial_message'] as String? ?? '',
      scenarios: parsedScenarios,
      points: json['points'] as int? ?? 100,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'description': description,
      'objection_type': objectionType,
      'client_persona': clientPersona,
      'initial_message': initialMessage,
      'scenarios': scenarios.map((s) => s.toJson()).toList(),
      'points': points,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class ExamQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const ExamQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: json['id'] as String? ?? UniqueKey().toString(),
      questionText: json['question_text'] as String,
      options: List<String>.from(json['options'] as List<dynamic>),
      correctIndex: json['correct_index'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'options': options,
      'correct_index': correctIndex,
      'explanation': explanation,
    };
  }
}

@immutable
class TrainingExam {
  final String id;
  final String companyId;
  final String title;
  final String? description;
  final int passingScore;
  final int timeLimitMins;
  final List<ExamQuestion> questions;
  final int points;
  final DateTime createdAt;

  const TrainingExam({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    this.passingScore = 80,
    this.timeLimitMins = 60,
    this.questions = const [],
    this.points = 200,
    required this.createdAt,
  });

  factory TrainingExam.fromJson(Map<String, dynamic> json) {
    List<ExamQuestion> parsedQuestions = [];
    if (json['questions'] != null) {
      if (json['questions'] is List) {
        parsedQuestions = (json['questions'] as List)
            .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
            .toList();
      }
    }
    return TrainingExam(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      passingScore: json['passing_score'] as int? ?? 80,
      timeLimitMins: json['time_limit_mins'] as int? ?? 60,
      questions: parsedQuestions,
      points: json['points'] as int? ?? 200,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'description': description,
      'passing_score': passingScore,
      'time_limit_mins': timeLimitMins,
      'questions': questions.map((q) => q.toJson()).toList(),
      'points': points,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class TrainingProgress {
  final String id;
  final String profileId;
  final String companyId;
  final String itemType; // 'material', 'simulator', 'exam'
  final String itemId;
  final int? score;
  final DateTime completedAt;

  const TrainingProgress({
    required this.id,
    required this.profileId,
    required this.companyId,
    required this.itemType,
    required this.itemId,
    this.score,
    required this.completedAt,
  });

  factory TrainingProgress.fromJson(Map<String, dynamic> json) {
    return TrainingProgress(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      companyId: json['company_id'] as String,
      itemType: json['item_type'] as String,
      itemId: json['item_id'] as String,
      score: json['score'] as int?,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'company_id': companyId,
      'item_type': itemType,
      'item_id': itemId,
      'score': score,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}

@immutable
class TrainingBadge {
  final String id;
  final String profileId;
  final String companyId;
  final String badgeName;
  final DateTime unlockedAt;

  const TrainingBadge({
    required this.id,
    required this.profileId,
    required this.companyId,
    required this.badgeName,
    required this.unlockedAt,
  });

  factory TrainingBadge.fromJson(Map<String, dynamic> json) {
    return TrainingBadge(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      companyId: json['company_id'] as String,
      badgeName: json['badge_name'] as String,
      unlockedAt: DateTime.parse(json['unlocked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'company_id': companyId,
      'badge_name': badgeName,
      'unlocked_at': unlockedAt.toIso8601String(),
    };
  }
}
