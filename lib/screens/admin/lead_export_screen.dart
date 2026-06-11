import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/models/models.dart';

class LeadExportScreen extends ConsumerStatefulWidget {
  const LeadExportScreen({super.key});

  @override
  ConsumerState<LeadExportScreen> createState() => _LeadExportScreenState();
}

class _LeadExportScreenState extends ConsumerState<LeadExportScreen> {
  LeadStage? _selectedStage;
  String? _selectedAgentId;
  String? _selectedChannel;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leads = ref.watch(leadProvider).leads;
    final marketers = ref.watch(agencyMarketersProvider).value ?? [];

    // Filter leads on the fly to show real-time stats
    final filteredLeads = leads.where((lead) {
      if (_selectedStage != null && lead.stage != _selectedStage) return false;
      if (_selectedAgentId != null && lead.assignedAgentId != _selectedAgentId) return false;
      if (_selectedChannel != null && lead.sourceChannel != _selectedChannel) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Export Leads'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Instructions
            Text(
              'Filter & Export',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select criteria to filter your leads list, then generate and share a CSV format file containing all matching records.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Filters Card
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Stage Filter
                    DropdownButtonFormField<LeadStage?>(
                      value: _selectedStage,
                      decoration: _inputDecoration(label: 'Pipeline Stage', icon: Icons.playlist_add_check_rounded),
                      items: [
                        const DropdownMenuItem<LeadStage?>(value: null, child: Text('All Stages')),
                        ...LeadStage.values.map((stage) {
                          return DropdownMenuItem<LeadStage?>(
                            value: stage,
                            child: Text(stage.label),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _selectedStage = val),
                    ),
                    const SizedBox(height: 16),

                    // Agent Filter
                    DropdownButtonFormField<String?>(
                      value: _selectedAgentId,
                      decoration: _inputDecoration(label: 'Assigned Agent / Marketer', icon: Icons.person_outline),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Agents')),
                        const DropdownMenuItem<String?>(value: 'unassigned', child: Text('Unassigned Leads')),
                        ...marketers.map((m) {
                          return DropdownMenuItem<String?>(
                            value: m.id,
                            child: Text(m.fullName ?? m.email ?? ''),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _selectedAgentId = val),
                    ),
                    const SizedBox(height: 16),

                    // Source Channel Filter
                    DropdownButtonFormField<String?>(
                      value: _selectedChannel,
                      decoration: _inputDecoration(label: 'Lead Source Channel', icon: Icons.campaign_outlined),
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('All Channels')),
                        DropdownMenuItem<String?>(value: 'walk_in', child: Text('Walk In / Offline')),
                        DropdownMenuItem<String?>(value: 'whatsapp', child: Text('WhatsApp')),
                        DropdownMenuItem<String?>(value: 'website', child: Text('Website')),
                        DropdownMenuItem<String?>(value: 'referral', child: Text('Other Referrals')),
                      ],
                      onChanged: (val) => setState(() => _selectedChannel = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Realtime Stats Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${filteredLeads.length} Leads Selected',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Out of ${leads.length} total agency leads.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Export Actions Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _isExporting
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : ElevatedButton.icon(
                      onPressed: filteredLeads.isEmpty ? null : () => _exportLeads(filteredLeads),
                      icon: const Icon(Icons.share_outlined, color: Colors.white),
                      label: Text(
                        'Generate & Share CSV',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLeads(List<Lead> leads) async {
    setState(() => _isExporting = true);
    try {
      final List<List<dynamic>> rows = [
        ['Lead ID', 'Name', 'Phone', 'Email', 'Source Channel', 'Pipeline Stage', 'Assigned Agent ID', 'Created At', 'Notes']
      ];

      for (final lead in leads) {
        rows.add([
          lead.id,
          lead.buyerName,
          lead.buyerPhone,
          lead.buyerEmail ?? '',
          lead.sourceChannel,
          lead.stage.label,
          lead.assignedAgentId ?? 'Unassigned',
          lead.createdAt.toIso8601String(),
          lead.notes ?? ''
        ]);
      }

      final csvContent = Csv().encode(rows);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/leads_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = io.File(path);
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        subject: 'Exported Leads - ${DateTime.now().toLocal().toString().split('.')[0]}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
