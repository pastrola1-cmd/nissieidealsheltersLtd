import 'package:flutter/material.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/models/models.dart';

class MergeDialog extends StatelessWidget {
  final Lead existingLead;
  final String newName;
  final String newPhone;
  final String? newEmail;
  final String? newNotes;
  final VoidCallback onViewExisting;
  final Function(String mergedNotes) onMerge;

  const MergeDialog({
    super.key,
    required this.existingLead,
    required this.newName,
    required this.newPhone,
    this.newEmail,
    this.newNotes,
    required this.onViewExisting,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mergedNotesController = TextEditingController(
      text: existingLead.notes != null
          ? '${existingLead.notes}\n---\n[Merged on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}]: ${newNotes ?? 'Additional lead submission'}'
          : (newNotes ?? ''),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: AppColors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Duplicate Lead Detected',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'A lead with this contact information already exists in your agency. Would you like to merge the new details into the existing lead?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            // Comparison Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildComparisonRow('Field', 'Existing Lead', 'New Input', isHeader: true),
                  const Divider(height: 16, color: AppColors.border),
                  _buildComparisonRow('Name', existingLead.buyerName, newName),
                  _buildComparisonRow('Phone', existingLead.buyerPhone, newPhone),
                  _buildComparisonRow('Email', existingLead.buyerEmail ?? 'N/A', newEmail ?? 'N/A'),
                  _buildComparisonRow('Stage', existingLead.stage.label, 'New'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Merge Notes / Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: mergedNotesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter additional notes to merge...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onViewExisting();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View Existing', style: TextStyle(color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onMerge(mergedNotesController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Merge & Update'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String field, String existingVal, String newVal, {bool isHeader = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      color: isHeader ? AppColors.textPrimary : AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(field, style: style)),
          Expanded(flex: 3, child: Text(existingVal, style: style.copyWith(color: isHeader ? AppColors.textPrimary : AppColors.primary))),
          Expanded(flex: 3, child: Text(newVal, style: style.copyWith(color: isHeader ? AppColors.textPrimary : AppColors.success))),
        ],
      ),
    );
  }
}
