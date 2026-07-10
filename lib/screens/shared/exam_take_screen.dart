import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/training_provider.dart';

class ExamTakeScreen extends ConsumerStatefulWidget {
  final String examId;
  const ExamTakeScreen({super.key, required this.examId});

  @override
  ConsumerState<ExamTakeScreen> createState() => _ExamTakeScreenState();
}

class _ExamTakeScreenState extends ConsumerState<ExamTakeScreen> {
  List<ExamQuestion> _examQuestions = [];
  final Map<int, int> _userAnswers = {}; // questionIndex: selectedOptionIndex

  int _currentIndex = 0;
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _isSubmitted = false;
  bool _isSavingProgress = false;
  int _finalScore = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final exam = ref.read(trainingProvider).exams.cast<TrainingExam?>().firstWhere(
            (e) => e?.id == widget.examId,
            orElse: () => null,
          );

      if (exam != null && exam.questions.isNotEmpty) {
        // Shuffle and take a subset of questions to ensure high integrity (e.g. 30 questions from the 100+ pool)
        final shuffled = List<ExamQuestion>.from(exam.questions)..shuffle();
        final subsetSize = shuffled.length > 30 ? 30 : shuffled.length;
        
        setState(() {
          _examQuestions = shuffled.sublist(0, subsetSize);
          _secondsRemaining = exam.timeLimitMins * 60;
        });

        _startTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _handleSubmitExam(); // Time's up! Auto-submit.
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSubmitExam() async {
    if (_isSubmitted) return;
    _timer?.cancel();

    // Compute score
    int correctCount = 0;
    for (int i = 0; i < _examQuestions.length; i++) {
      if (_userAnswers[i] == _examQuestions[i].correctIndex) {
        correctCount++;
      }
    }

    final scorePct = ((correctCount / _examQuestions.length) * 100).round();

    setState(() {
      _isSubmitted = true;
      _finalScore = scorePct;
      _isSavingProgress = true;
    });

    // Save progress to database
    await ref.read(trainingProvider.notifier).recordProgress(
          itemType: 'exam',
          itemId: widget.examId,
          score: scorePct,
        );

    setState(() {
      _isSavingProgress = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trainingState = ref.watch(trainingProvider);
    final exam = trainingState.exams.cast<TrainingExam?>().firstWhere(
          (e) => e?.id == widget.examId,
          orElse: () => null,
        );

    if (exam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Not Found')),
        body: const Center(child: Text('Exam not found.')),
      );
    }

    if (_examQuestions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.title)),
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final isPassed = _finalScore >= exam.passingScore;

    if (_isSubmitted) {
      return _buildScoreSummaryView(exam, isPassed);
    }

    final currentQuestion = _examQuestions[_currentIndex];
    final selectedOption = _userAnswers[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(exam.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _secondsRemaining < 120 ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _secondsRemaining < 120 ? AppColors.error : AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_secondsRemaining),
                  style: TextStyle(
                    color: _secondsRemaining < 120 ? AppColors.error : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Question Progress Bar
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1} of ${_examQuestions.length}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${((_currentIndex / _examQuestions.length) * 100).round()}% Completed',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _examQuestions.length,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),

            // Question Display Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        currentQuestion.questionText,
                        style: const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Select the best answer:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),

                    // Options list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentQuestion.options.length,
                      itemBuilder: (context, optIdx) {
                        final optionText = currentQuestion.options[optIdx];
                        final isSelected = selectedOption == optIdx;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _userAnswers[_currentIndex] = optIdx;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.textTertiary, width: 2),
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                    ),
                                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Controls Drawer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: _currentIndex == 0
                        ? null
                        : () {
                            setState(() {
                              _currentIndex--;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _currentIndex == _examQuestions.length - 1
                      ? ElevatedButton(
                          onPressed: selectedOption == null ? null : _handleSubmitExam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Submit Exam', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      : ElevatedButton(
                          onPressed: selectedOption == null
                              ? null
                              : () {
                                  setState(() {
                                    _currentIndex++;
                                  });
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSummaryView(TrainingExam exam, bool isPassed) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Exam Result', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Result Header Card
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isPassed ? AppColors.success : AppColors.error).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPassed ? Icons.emoji_events_rounded : Icons.cancel_outlined,
                          color: isPassed ? AppColors.success : AppColors.error,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isPassed ? 'Passed Successfully!' : 'Try Again',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isPassed ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Score: $_finalScore% (Passing: ${exam.passingScore}%)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPassed
                            ? 'Outstanding! You have proven expert real estate marketing skills and property knowledge.'
                            : 'To qualify for points and badge certifications, you need at least ${exam.passingScore}% correct answers.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Pro-Level Review Explanations Header
              const Text(
                'Professional Evaluation Review',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),

              // 3. Question Reviews list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _examQuestions.length,
                itemBuilder: (context, qIdx) {
                  final question = _examQuestions[qIdx];
                  final userSelection = _userAnswers[qIdx];
                  final isCorrect = userSelection == question.correctIndex;

                  return Card(
                    color: AppColors.surface,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isCorrect ? AppColors.success : AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Question ${qIdx + 1}: ${question.questionText}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // User answer review
                          Text(
                            'Your Answer: ${userSelection != null ? question.options[userSelection] : "None (Skipped)"}',
                            style: TextStyle(
                              color: isCorrect ? AppColors.success : AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isCorrect) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Correct Answer: ${question.options[question.correctIndex]}',
                              style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Coach Explanation Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SALES COACH EXPLANATION:',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  question.explanation,
                                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Academy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
