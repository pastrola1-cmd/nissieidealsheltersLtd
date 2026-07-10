import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/training_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';

class TrainingMaterialDetailScreen extends ConsumerStatefulWidget {
  final String materialId;
  const TrainingMaterialDetailScreen({super.key, required this.materialId});

  @override
  ConsumerState<TrainingMaterialDetailScreen> createState() => _TrainingMaterialDetailScreenState();
}

class _TrainingMaterialDetailScreenState extends ConsumerState<TrainingMaterialDetailScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainingState = ref.watch(trainingProvider);
    final profile = ref.watch(authProvider).profile;

    final mat = trainingState.materials.cast<TrainingMaterial?>().firstWhere(
          (m) => m?.id == widget.materialId,
          orElse: () => null,
        );

    if (mat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guide Not Found')),
        body: const Center(child: Text('Study guide not found.')),
      );
    }

    final isRead = trainingState.progress.any(
      (p) => p.profileId == profile?.id && p.itemId == mat.id && p.itemType == 'material',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(mat.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AWARDING ${mat.points} XP',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      mat.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (mat.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        mat.description!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Content body text
                    Text(
                      mat.contentText ?? 'This study guide contains details to read. Open PDF attachment if provided above.',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Bottom Action Drawer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : ElevatedButton(
                        onPressed: isRead
                            ? () => context.pop()
                            : () async {
                                setState(() => _isSaving = true);
                                final ok = await ref.read(trainingProvider.notifier).recordProgress(
                                      itemType: 'material',
                                      itemId: mat.id,
                                    );
                                if (mounted) {
                                  setState(() => _isSaving = false);
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Completed! You earned +${mat.points} XP!'),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    context.pop();
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRead ? AppColors.surfaceVariant : AppColors.primary,
                          foregroundColor: isRead ? AppColors.textPrimary : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isRead ? 'Return to Academy' : 'Mark as Read & Claim points',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
