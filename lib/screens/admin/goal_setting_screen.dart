import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/goal_provider.dart';
import 'package:ppn/widgets/goal_card.dart';

class GoalSettingScreen extends ConsumerStatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  ConsumerState<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends ConsumerState<GoalSettingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(goalProvider.notifier).fetchGoals());
  }

  @override
  Widget build(BuildContext context) {
    final goalState = ref.watch(goalProvider);
    final userProfile = ref.watch(authProvider).profile;
    final isAdmin = userProfile?.role == UserRole.admin;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Agency Performance Goals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: goalState.isLoading && goalState.goals.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(goalProvider.notifier).fetchGoals(),
              color: AppColors.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (goalState.errorMessage != null)
                      Card(
                        color: AppColors.errorLight,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            goalState.errorMessage!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                    Text(
                      'Track your targets, see current projections and pacing metrics to drive conversions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (goalState.goals.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.track_changes_outlined,
                                size: 80,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No goals defined yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isAdmin
                                    ? 'Tap the button below to configure your first metric target.'
                                    : 'Performance targets defined by agency admin will appear here.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (isAdmin) ...[
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddGoalBottomSheet(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Set First Goal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.1,
                        ),
                        itemCount: goalState.goals.length,
                        itemBuilder: (context, index) {
                          final goal = goalState.goals[index];
                          final progress = goalState.progressCache[goal.id];

                          if (progress == null) {
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          return Stack(
                            children: [
                              GoalCard(
                                progress: progress,
                                onTap: () {
                                  final rolePath = isAdmin ? 'admin' : 'manager';
                                  context.push('/$rolePath/goals/${goal.id}');
                                },
                              ),
                              if (isAdmin)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                    tooltip: 'Delete Goal',
                                    onPressed: () => _confirmDeleteGoal(context, goal.id),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: isAdmin && goalState.goals.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddGoalBottomSheet(context),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _confirmDeleteGoal(BuildContext context, String goalId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text('Are you sure you want to delete this performance target? Progress data won\'t be lost but tracking will stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(goalProvider.notifier).deleteGoal(goalId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goal deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGoalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddGoalFormBottomSheet(),
    );
  }
}

class AddGoalFormBottomSheet extends ConsumerStatefulWidget {
  const AddGoalFormBottomSheet({super.key});

  @override
  ConsumerState<AddGoalFormBottomSheet> createState() => _AddGoalFormBottomSheetState();
}

class _AddGoalFormBottomSheetState extends ConsumerState<AddGoalFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _targetValueController = TextEditingController();

  String _metric = 'leads';
  String _horizon = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setDatesForHorizon();
  }

  @override
  void dispose() {
    _targetValueController.dispose();
    super.dispose();
  }

  void _setDatesForHorizon() {
    final now = DateTime.now();
    setState(() {
      if (_horizon == 'monthly') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
      } else if (_horizon == 'quarterly') {
        final quarter = ((now.month - 1) / 3).floor();
        _startDate = DateTime(now.year, quarter * 3 + 1, 1);
        _endDate = DateTime(now.year, (quarter + 1) * 3 + 1, 0);
      } else if (_horizon == '6month') {
        final half = now.month <= 6 ? 1 : 2;
        _startDate = DateTime(now.year, half == 1 ? 1 : 7, 1);
        _endDate = DateTime(now.year, half == 1 ? 7 : 13, 0);
      } else if (_horizon == 'yearly') {
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        if (isStart) {
          _startDate = selected;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = selected;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyId = ref.read(authProvider).profile?.companyId ?? '';
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Set Performance Goal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Target Metric', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _metric,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'leads', child: Text('Leads Count')),
                  DropdownMenuItem(value: 'closings', child: Text('Deals Closed')),
                  DropdownMenuItem(value: 'revenue', child: Text('Revenue split (₦)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _metric = val);
                },
              ),
              const SizedBox(height: 16),
              const Text('Time Horizon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _horizon,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                  DropdownMenuItem(value: '6month', child: Text('6-Month')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _horizon = val);
                    _setDatesForHorizon();
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Target Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _targetValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: _metric == 'revenue' ? 'Enter target amount in ₦' : 'Enter count target',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter a target value';
                  final numVal = double.tryParse(val);
                  if (numVal == null || numVal <= 0) return 'Please enter a positive value';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dateFormat.format(_startDate)),
                                const Icon(Icons.calendar_month, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dateFormat.format(_endDate)),
                                const Icon(Icons.calendar_month, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    if (_endDate.isBefore(_startDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('End date must be after start date')),
                      );
                      return;
                    }

                    // Local duplicate check
                    final existingGoals = ref.read(goalProvider).goals;
                    final hasDuplicate = existingGoals.any((g) =>
                        g.metric == _metric &&
                        g.horizon == _horizon &&
                        g.periodStart.year == _startDate.year &&
                        g.periodStart.month == _startDate.month &&
                        g.periodStart.day == _startDate.day);

                    if (hasDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('A goal for this metric, horizon, and starting period already exists.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    final goal = Goal(
                      id: '',
                      companyId: companyId,
                      createdBy: ref.read(authProvider).profile?.id,
                      metric: _metric,
                      horizon: _horizon,
                      targetValue: double.parse(_targetValueController.text),
                      periodStart: _startDate,
                      periodEnd: _endDate,
                    );

                    try {
                      await ref.read(goalProvider.notifier).addGoal(goal);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Goal saved successfully')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving goal: ${e.toString().replaceAll('Exception: ', '')}')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save Performance Goal', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
