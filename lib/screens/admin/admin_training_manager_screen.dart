import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/training_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class AdminTrainingManagerScreen extends ConsumerStatefulWidget {
  const AdminTrainingManagerScreen({super.key});

  @override
  ConsumerState<AdminTrainingManagerScreen> createState() => _AdminTrainingManagerScreenState();
}

class _AdminTrainingManagerScreenState extends ConsumerState<AdminTrainingManagerScreen> {
  final _materialFormKey = GlobalKey<FormState>();
  final _simulatorFormKey = GlobalKey<FormState>();
  final _examFormKey = GlobalKey<FormState>();

  // Study material form fields
  final _matTitleController = TextEditingController();
  final _matDescController = TextEditingController();
  final _matContentController = TextEditingController();
  final _matPointsController = TextEditingController(text: '50');
  String? _uploadedFileUrl;
  String? _uploadedFileName;
  bool _isUploadingFile = false;
  bool _isSavingMaterial = false;

  // Simulator form fields
  final _simTitleController = TextEditingController();
  final _simDescController = TextEditingController();
  final _simPersonaController = TextEditingController(text: 'Skeptical Buyer');
  final _simMsgController = TextEditingController(text: 'The price of this estate is too expensive.');
  final _simPointsController = TextEditingController(text: '100');
  String _selectedObjectionType = 'price';
  bool _isSavingSimulator = false;

  // Exam form fields
  final _examTitleController = TextEditingController();
  final _examDescController = TextEditingController();
  final _examPassScoreController = TextEditingController(text: '80');
  final _examTimeController = TextEditingController(text: '60');
  final _examPointsController = TextEditingController(text: '200');
  final List<ExamQuestion> _examQuestions = [];
  bool _isSavingExam = false;

  // Exam Question builder fields
  final _qTextController = TextEditingController();
  final _qOpt1Controller = TextEditingController();
  final _qOpt2Controller = TextEditingController();
  final _qOpt3Controller = TextEditingController();
  final _qOpt4Controller = TextEditingController();
  final _qExplanationController = TextEditingController();
  int _correctOptIndex = 0;

  @override
  void dispose() {
    _matTitleController.dispose();
    _matDescController.dispose();
    _matContentController.dispose();
    _matPointsController.dispose();
    _simTitleController.dispose();
    _simDescController.dispose();
    _simPersonaController.dispose();
    _simMsgController.dispose();
    _simPointsController.dispose();
    _examTitleController.dispose();
    _examDescController.dispose();
    _examPassScoreController.dispose();
    _examTimeController.dispose();
    _examPointsController.dispose();
    _qTextController.dispose();
    _qOpt1Controller.dispose();
    _qOpt2Controller.dispose();
    _qOpt3Controller.dispose();
    _qOpt4Controller.dispose();
    _qExplanationController.dispose();
    super.dispose();
  }

  // ── Upload Training Document/PDF/Image ──
  Future<void> _pickAndUploadTrainingFile() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (file == null) return;

    setState(() => _isUploadingFile = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final path = 'training/guide_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final service = ref.read(supabaseServiceProvider);
      final publicUrl = await service.uploadFile(
        'company-assets',
        path,
        bytes,
        mimeType: 'image/$ext',
      );

      setState(() {
        _uploadedFileUrl = publicUrl;
        _uploadedFileName = file.name;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Study guide attachment uploaded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  // ── Create Study Material ──
  Future<void> _handleSaveMaterial() async {
    if (!(_materialFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isSavingMaterial = true);
    final ok = await ref.read(trainingProvider.notifier).addMaterial(
          _matTitleController.text.trim(),
          _matDescController.text.trim().isEmpty ? null : _matDescController.text.trim(),
          _matContentController.text.trim().isEmpty ? null : _matContentController.text.trim(),
          _uploadedFileUrl,
          _uploadedFileName,
          int.tryParse(_matPointsController.text) ?? 50,
        );

    setState(() => _isSavingMaterial = false);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study Material created successfully!')),
      );
      _matTitleController.clear();
      _matDescController.clear();
      _matContentController.clear();
      setState(() {
        _uploadedFileUrl = null;
        _uploadedFileName = null;
      });
    }
  }

  // ── Create Objections Simulator ──
  Future<void> _handleSaveSimulator() async {
    if (!(_simulatorFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isSavingSimulator = true);

    // Build some fallback static options just in case Gemini API is not connected
    final List<SimulatorScenarioStep> steps = [
      SimulatorScenarioStep(
        id: 'step_1',
        objectionText: _simMsgController.text.trim(),
        options: [
          SimulatorOption(
            text: 'I understand your budget concern. Let me show you how this property saves you money in the long run through its high rental yields.',
            score: 10,
            feedback: 'Excellent value-proposition closing approach! Highly professional.',
          ),
          SimulatorOption(
            text: 'We are the best in Nigeria. Our properties are expensive because they are quality houses.',
            score: 3,
            feedback: 'Avoid acting defensive or sounding aggressive to the prospect.',
          ),
          SimulatorOption(
            text: 'We have installment plans of up to 18 months, which helps spread the cost.',
            score: 7,
            feedback: 'Good alternative proposal. Installments are highly effective!',
          ),
        ],
      )
    ];

    final ok = await ref.read(trainingProvider.notifier).addSimulator(
          _simTitleController.text.trim(),
          _simDescController.text.trim().isEmpty ? null : _simDescController.text.trim(),
          _selectedObjectionType,
          _simPersonaController.text.trim(),
          _simMsgController.text.trim(),
          steps,
          int.tryParse(_simPointsController.text) ?? 100,
        );

    setState(() => _isSavingSimulator = false);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objection Simulator created successfully!')),
      );
      _simTitleController.clear();
      _simDescController.clear();
      _simPersonaController.clear();
      _simMsgController.clear();
    }
  }

  // ── Add Quiz Question to Exam Builder ──
  void _addQuestionToExamBuilder() {
    if (_qTextController.text.trim().isEmpty || _qOpt1Controller.text.trim().isEmpty || _qOpt2Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question text and at least 2 options are required.')),
      );
      return;
    }

    final opts = [
      _qOpt1Controller.text.trim(),
      _qOpt2Controller.text.trim(),
      if (_qOpt3Controller.text.trim().isNotEmpty) _qOpt3Controller.text.trim(),
      if (_qOpt4Controller.text.trim().isNotEmpty) _qOpt4Controller.text.trim(),
    ];

    final question = ExamQuestion(
      id: UniqueKey().toString(),
      questionText: _qTextController.text.trim(),
      options: opts,
      correctIndex: _correctOptIndex,
      explanation: _qExplanationController.text.trim().isEmpty
          ? 'Professional selling standard: handling objections accurately closes deals.'
          : _qExplanationController.text.trim(),
    );

    setState(() {
      _examQuestions.add(question);
      _qTextController.clear();
      _qOpt1Controller.clear();
      _qOpt2Controller.clear();
      _qOpt3Controller.clear();
      _qOpt4Controller.clear();
      _qExplanationController.clear();
      _correctOptIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Question added to exam! Total: ${_examQuestions.length}')),
    );
  }

  // ── Create Quiz Exam ──
  Future<void> _handleSaveExam() async {
    if (!(_examFormKey.currentState?.validate() ?? false)) return;

    if (_examQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 question to the exam pool first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSavingExam = true);
    final ok = await ref.read(trainingProvider.notifier).addExam(
          _examTitleController.text.trim(),
          _examDescController.text.trim().isEmpty ? null : _examDescController.text.trim(),
          int.tryParse(_examPassScoreController.text) ?? 80,
          int.tryParse(_examTimeController.text) ?? 60,
          _examQuestions,
          int.tryParse(_examPointsController.text) ?? 200,
        );

    setState(() => _isSavingExam = false);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certification Exam created successfully!')),
      );
      _examTitleController.clear();
      _examDescController.clear();
      setState(() {
        _examQuestions.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainingState = ref.watch(trainingProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Manage Academy', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.surface,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Materials'),
              Tab(text: 'Simulators'),
              Tab(text: 'Quizzes / Exams'),
              Tab(text: 'Completions Log'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildManageMaterialsTab(trainingState),
            _buildManageSimulatorsTab(trainingState),
            _buildManageExamsTab(trainingState),
            _buildCompletionsLogTab(trainingState),
          ],
        ),
      ),
    );
  }

  // ── TAB: Manage Study Guides ──
  Widget _buildManageMaterialsTab(TrainingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Creator Form Card
          Card(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _materialFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create Study Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matTitleController,
                      decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matDescController,
                      decoration: const InputDecoration(labelText: 'Summary Description', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matContentController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Article Content Text', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matPointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Completion Points XP', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isUploadingFile ? null : _pickAndUploadTrainingFile,
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text('Add Document Attachment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceVariant,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                          ),
                        ),
                        if (_uploadedFileName != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _uploadedFileName!,
                              style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _isSavingMaterial
                          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                          : ElevatedButton(
                              onPressed: _handleSaveMaterial,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Publish Guide', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // B. List & Delete Card
          const Text('Existing Materials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.materials.length,
            itemBuilder: (context, index) {
              final mat = state.materials[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: Text(mat.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('+${mat.points} XP • ${mat.mediaName ?? "No PDF attachment"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: () => ref.read(trainingProvider.notifier).deleteMaterial(mat.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── TAB: Manage Simulators ──
  Widget _buildManageSimulatorsTab(TrainingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Form Card
          Card(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _simulatorFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create Objection Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _simTitleController,
                      decoration: const InputDecoration(labelText: 'Objection Title', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _simDescController,
                      decoration: const InputDecoration(labelText: 'Short Description', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedObjectionType,
                      decoration: const InputDecoration(labelText: 'Objection Category', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'price', child: Text('Price Objection')),
                        DropdownMenuItem(value: 'location', child: Text('Location Objection')),
                        DropdownMenuItem(value: 'legal', child: Text('Title Deed / Legal Objection')),
                        DropdownMenuItem(value: 'trust', child: Text('Trust / Brand Skepticism')),
                        DropdownMenuItem(value: 'custom', child: Text('Other custom objection')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedObjectionType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _simPersonaController,
                      decoration: const InputDecoration(labelText: 'Client Persona (e.g. Skeptical Investor)', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Persona is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _simMsgController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Prospect Initial Message / Objection', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Initial message is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _simPointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Award Points XP', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _isSavingSimulator
                          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                          : ElevatedButton(
                              onPressed: _handleSaveSimulator,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Publish Simulator', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // B. List
          const Text('Existing Simulators', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.simulators.length,
            itemBuilder: (context, index) {
              final sim = state.simulators[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: Text(sim.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Persona: ${sim.clientPersona} • Category: ${sim.objectionType.toUpperCase()}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: () => ref.read(trainingProvider.notifier).deleteSimulator(sim.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── TAB: Manage Certification Exams ──
  Widget _buildManageExamsTab(TrainingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Exam settings form
          Card(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _examFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create Pro-level Exam & Question Pool', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _examTitleController,
                      decoration: const InputDecoration(labelText: 'Exam Title', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _examDescController,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _examPassScoreController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Passing Score %', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _examTimeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Time Limit (mins)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _examPointsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'XP Points', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // B. Question Builder Section
                    const Text('Question Pool Builder (Seeding)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qTextController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Enter question text...', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _qOpt1Controller, decoration: const InputDecoration(hintText: 'Option 1 (A)', border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(controller: _qOpt2Controller, decoration: const InputDecoration(hintText: 'Option 2 (B)', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _qOpt3Controller, decoration: const InputDecoration(hintText: 'Option 3 (C) (Optional)', border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(controller: _qOpt4Controller, decoration: const InputDecoration(hintText: 'Option 4 (D) (Optional)', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Correct Option Index:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        DropdownButton<int>(
                          value: _correctOptIndex,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Option 1 (A)')),
                            DropdownMenuItem(value: 1, child: Text('Option 2 (B)')),
                            DropdownMenuItem(value: 2, child: Text('Option 3 (C)')),
                            DropdownMenuItem(value: 3, child: Text('Option 4 (D)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _correctOptIndex = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qExplanationController,
                      decoration: const InputDecoration(hintText: 'Explanation for feedback (Why is this correct?)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _addQuestionToExamBuilder,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add Question to Pool'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Questions in Pool: ${_examQuestions.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _isSavingExam
                          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                          : ElevatedButton(
                              onPressed: _handleSaveExam,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Publish Certification Exam', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // C. List
          const Text('Existing Exams', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.exams.length,
            itemBuilder: (context, index) {
              final exam = state.exams[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: Text(exam.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Questions: ${exam.questions.length} • Passing: ${exam.passingScore}% • XP: ${exam.points}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: () => ref.read(trainingProvider.notifier).deleteExam(exam.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── TAB: Completions Log ──
  Widget _buildCompletionsLogTab(TrainingState state) {
    if (state.progress.isEmpty) {
      return const Center(
        child: Text('No training completions recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final sortedProgress = List<TrainingProgress>.from(state.progress)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedProgress.length,
      itemBuilder: (context, index) {
        final prog = sortedProgress[index];
        
        // Map user profile details
        final user = state.companyStaff.cast<Profile?>().firstWhere((u) => u?.id == prog.profileId, orElse: () => null);
        final userName = user?.fullName ?? 'Team Member';
        final roleLabel = user?.role.label ?? '';

        // Map item details
        String itemTitle = 'Academy Module';
        if (prog.itemType == 'material') {
          final m = state.materials.cast<TrainingMaterial?>().firstWhere((mat) => mat?.id == prog.itemId, orElse: () => null);
          itemTitle = m?.title ?? 'Study Material';
        } else if (prog.itemType == 'simulator') {
          final s = state.simulators.cast<TrainingSimulator?>().firstWhere((sim) => sim?.id == prog.itemId, orElse: () => null);
          itemTitle = s?.title ?? 'Objection Simulator';
        } else if (prog.itemType == 'exam') {
          final e = state.exams.cast<TrainingExam?>().firstWhere((ex) => ex?.id == prog.itemId, orElse: () => null);
          itemTitle = e?.title ?? 'Quiz Exam';
        }

        final scoreDisplay = prog.score != null ? 'Score: ${prog.score}%' : 'Completed';
        final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(prog.completedAt.toLocal());

        return Card(
          color: AppColors.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 24),
            title: Text(
              '$userName ($roleLabel)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              '$itemTitle\n$scoreDisplay • $formattedDate',
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
