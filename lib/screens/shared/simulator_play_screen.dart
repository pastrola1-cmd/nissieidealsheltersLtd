import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/training_provider.dart';
import 'package:nissie_ideal_shelters/services/training_service.dart';

class SimulatorPlayScreen extends ConsumerStatefulWidget {
  final String simulatorId;
  const SimulatorPlayScreen({super.key, required this.simulatorId});

  @override
  ConsumerState<SimulatorPlayScreen> createState() => _SimulatorPlayScreenState();
}

class _SimulatorPlayScreenState extends ConsumerState<SimulatorPlayScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, String>> _chatHistory = []; // sender: 'client' | 'agent' | 'coach', text: string
  int _currentScore = 50; // starts at 50% progress
  bool _isSavingProgress = false;
  bool _isGeminiThinking = false;
  bool _isSimulationDone = false;
  String? _latestCritique;

  // Fallback option-based state variables
  int _currentFallbackStepIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final sim = ref.read(trainingProvider).simulators.cast<TrainingSimulator?>().firstWhere(
            (s) => s?.id == widget.simulatorId,
            orElse: () => null,
          );
      if (sim != null) {
        setState(() {
          _chatHistory = [
            {'sender': 'client', 'text': sim.initialMessage}
          ];
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 1. Dynamic Gemini-powered Roleplay ──
  Future<void> _handleSendAiMessage(String apiKey, TrainingSimulator sim) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _chatHistory.add({'sender': 'agent', 'text': text});
      _isGeminiThinking = true;
    });
    _scrollToBottom();

    try {
      final service = ref.read(trainingServiceProvider);
      
      // Remove coach critique logs from raw API chat history to keep token simple
      final cleanHistory = _chatHistory
          .where((m) => m['sender'] != 'coach')
          .map((m) => {'sender': m['sender'] == 'agent' ? 'marketer' : 'prospect', 'text': m['text']!})
          .toList();

      final response = await service.evaluateObjectionResponse(
        apiKey: apiKey,
        clientPersona: sim.clientPersona,
        objectionType: sim.objectionType,
        objectionText: sim.description ?? '',
        marketerMessage: text,
        chatHistory: cleanHistory,
      );

      final nextMsg = response['customerMessage'] as String? ?? 'Hmm, I see.';
      final critique = response['critique'] as String? ?? '';
      final scoreDelta = response['scoreDelta'] as int? ?? 5; // 0 to 10
      final isDone = response['isDone'] as bool? ?? false;

      setState(() {
        _isGeminiThinking = false;
        _chatHistory.add({'sender': 'client', 'text': nextMsg});
        if (critique.isNotEmpty) {
          _chatHistory.add({'sender': 'coach', 'text': critique});
          _latestCritique = critique;
        }
        
        // Update deal closure progress
        final pointsGained = (scoreDelta - 5) * 10; // score 5 is neutral, 10 gives +50, 0 gives -50
        _currentScore = (_currentScore + pointsGained).clamp(0, 100);

        if (isDone || _currentScore >= 100 || _currentScore <= 10) {
          _isSimulationDone = true;
        }
      });
      _scrollToBottom();

      if (_isSimulationDone) {
        await _saveFinalSimulatorResult(sim);
      }
    } catch (e) {
      setState(() {
        _isGeminiThinking = false;
        _chatHistory.add({'sender': 'coach', 'text': 'System Error: Failed to contact AI client ($e)'});
      });
      _scrollToBottom();
    }
  }

  // ── 2. Static Multiple Choice Flow ──
  void _handleSelectStaticOption(SimulatorOption option, TrainingSimulator sim) {
    setState(() {
      _chatHistory.add({'sender': 'agent', 'text': option.text});
      _chatHistory.add({'sender': 'coach', 'text': option.feedback});
      _latestCritique = option.feedback;
      
      // Update score progress
      _currentScore = (_currentScore + (option.score - 5) * 10).clamp(0, 100);

      // Check if there's a next step or if simulation ends
      final currentStep = sim.scenarios[_currentFallbackStepIndex];
      final nextStepIndex = _currentFallbackStepIndex + 1;

      if (nextStepIndex < sim.scenarios.length && _currentScore > 10 && _currentScore < 100) {
        _currentFallbackStepIndex = nextStepIndex;
        final nextStep = sim.scenarios[nextStepIndex];
        _chatHistory.add({'sender': 'client', 'text': nextStep.objectionText});
      } else {
        _isSimulationDone = true;
      }
    });
    _scrollToBottom();

    if (_isSimulationDone) {
      _saveFinalSimulatorResult(sim);
    }
  }

  Future<void> _saveFinalSimulatorResult(TrainingSimulator sim) async {
    setState(() => _isSavingProgress = true);
    final scorePercentage = _currentScore;
    final success = await ref.read(trainingProvider.notifier).recordProgress(
          itemType: 'simulator',
          itemId: sim.id,
          score: scorePercentage,
        );
    setState(() => _isSavingProgress = false);

    if (mounted && success) {
      final isClosed = scorePercentage >= 70;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isClosed ? '🎉 Deal Closed Successfully!' : '😢 Lead Walked Away',
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isClosed
                    ? 'Excellent job! You successfully handled the prospect objections and closed the transaction.'
                    : 'The objections weren\'t addressed appropriately. Refine your pitch and try again!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Final Conversion Score: $scorePercentage%',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
              ),
              const SizedBox(height: 10),
              Text(
                isClosed ? '+${sim.points} XP Awarded!' : 'Earn 70% or more to claim XP points.',
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          actions: [
            Center(
              child: SizedBox(
                width: 150,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    context.pop(); // Exit play screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Back to Academy', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainingState = ref.watch(trainingProvider);
    final company = ref.watch(authProvider).company;
    final geminiKey = company?.geminiApiKey;
    final isAiSupported = geminiKey != null && geminiKey.trim().isNotEmpty;

    final sim = trainingState.simulators.cast<TrainingSimulator?>().firstWhere(
          (s) => s?.id == widget.simulatorId,
          orElse: () => null,
        );

    if (sim == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Simulator Not Found')),
        body: const Center(child: Text('Objection simulator not found.')),
      );
    }

    // Determine current multiple choice options if in static mode
    List<SimulatorOption> currentStaticOptions = [];
    if (!isAiSupported && sim.scenarios.isNotEmpty && !_isSimulationDone) {
      final currentStep = sim.scenarios[_currentFallbackStepIndex];
      currentStaticOptions = currentStep.options;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(sim.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Deal Conversion Progress:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    Text('$_currentScore%', style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentScore / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _currentScore >= 70
                          ? AppColors.success
                          : _currentScore >= 40
                              ? Colors.orange
                              : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Bubble History Area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _chatHistory.length + (_isGeminiThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _chatHistory.length) {
                    return _buildThinkingBubble(sim.clientPersona);
                  }

                  final item = _chatHistory[index];
                  final sender = item['sender'];
                  final text = item['text']!;

                  if (sender == 'coach') {
                    return _buildCoachCritiqueBubble(text);
                  }

                  final isAgent = sender == 'agent';
                  return _buildChatBubble(text, isAgent, isAgent ? 'Me' : sim.clientPersona);
                },
              ),
            ),

            // Input / Multiple Choice Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _isSimulationDone
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'Simulation finished! Saving score...',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : (isAiSupported
                      ? _buildAiInputField(geminiKey, sim)
                      : _buildStaticOptionButtons(currentStaticOptions, sim)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isAgent, String senderName) {
    return Align(
      alignment: isAgent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 290),
        child: Column(
          crossAxisAlignment: isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAgent ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: isAgent ? const Radius.circular(14) : Radius.zero,
                  bottomRight: isAgent ? Radius.zero : const Radius.circular(14),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isAgent ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachCritiqueBubble(String text) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.psychology_outlined, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI SALES COACH COACHING:',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(fontSize: 12, height: 1.4, color: Colors.amber.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble(String clientName) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$clientName is typing', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInputField(String apiKey, TrainingSimulator sim) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _textController,
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _handleSendAiMessage(apiKey, sim),
            decoration: InputDecoration(
              hintText: 'Type your pitch / reply here...',
              fillColor: AppColors.surfaceVariant.withOpacity(0.3),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => _handleSendAiMessage(apiKey, sim),
          icon: const Icon(Icons.send_rounded, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildStaticOptionButtons(List<SimulatorOption> options, TrainingSimulator sim) {
    if (options.isEmpty) {
      return const Center(child: Text('No response options available.', style: TextStyle(color: AppColors.textSecondary)));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((opt) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElevatedButton(
            onPressed: () => _handleSelectStaticOption(opt, sim),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              opt.text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }
}
