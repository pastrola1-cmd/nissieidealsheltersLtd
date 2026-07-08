import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';

class LeadImportScreen extends ConsumerStatefulWidget {
  const LeadImportScreen({super.key});

  @override
  ConsumerState<LeadImportScreen> createState() => _LeadImportScreenState();
}

class _LeadImportScreenState extends ConsumerState<LeadImportScreen> {
  int _currentStep = 0;
  PlatformFile? _selectedFile;
  List<List<dynamic>> _csvData = [];
  List<dynamic> _headers = [];
  
  // Mapping of Lead fields to CSV Column indices
  int? _nameColIdx;
  int? _phoneColIdx;
  int? _emailColIdx;
  int? _notesColIdx;
  int? _channelColIdx;

  String? _selectedPropertyId;
  bool _isProcessingFile = false;
  bool _isImporting = false;
  
  // Preview Row Model
  List<_ImportRowPreview> _previewRows = [];
  int _validCount = 0;
  int _dupCount = 0;
  int _invalidCount = 0;

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import Leads from CSV'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        onStepContinue: _handleNextStep,
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isImporting || _isProcessingFile ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(isLast ? 'Import Selected' : 'Continue'),
                  ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Upload File'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            content: _buildUploadStep(),
          ),
          Step(
            title: const Text('Map Fields'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
            content: _buildMappingStep(),
          ),
          Step(
            title: const Text('Preview'),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.complete,
            content: _buildPreviewStep(),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Upload File ──
  Widget _buildUploadStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a CSV file containing your lead contacts. Please verify that the file contains columns for Name and Phone Number.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.accent),
                const SizedBox(height: 12),
                Text(
                  _selectedFile != null ? _selectedFile!.name : 'Click to Browse File',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Map Fields & Target Property ──
  Widget _buildMappingStep() {
    final properties = ref.watch(propertyProvider).properties.where((p) => p.status == PropertyStatus.available).toList();
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attribute leads to a listing and map target lead fields to CSV columns.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),

        // Target Property Selection
        DropdownButtonFormField<String>(
          value: _selectedPropertyId,
          decoration: _dropdownDecoration(label: 'Attribute Listing (Required)', icon: Icons.home_work_outlined),
          items: properties.map((property) {
            return DropdownMenuItem<String>(
              value: property.id,
              child: Text(
                '${property.title} (${currencyFormat.format(property.price)})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => _selectedPropertyId = val);
          },
        ),
        const SizedBox(height: 24),

        const Text(
          'Map Fields',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 12),
        
        _buildMappingDropdown('Buyer Full Name (Required)', _nameColIdx, (val) {
          setState(() => _nameColIdx = val);
        }),
        _buildMappingDropdown('Buyer Phone Number (Required)', _phoneColIdx, (val) {
          setState(() => _phoneColIdx = val);
        }),
        _buildMappingDropdown('Buyer Email (Optional)', _emailColIdx, (val) {
          setState(() => _emailColIdx = val);
        }),
        _buildMappingDropdown('Notes / Inquiries (Optional)', _notesColIdx, (val) {
          setState(() => _notesColIdx = val);
        }),
        _buildMappingDropdown('Lead Source Channel (Optional)', _channelColIdx, (val) {
          setState(() => _channelColIdx = val);
        }),
      ],
    );
  }

  Widget _buildMappingDropdown(String label, int? currentIdx, Function(int?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<int?>(
        value: currentIdx,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        ),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('-- Do Not Import / Map --')),
          ...List.generate(_headers.length, (index) {
            return DropdownMenuItem<int?>(
              value: index,
              child: Text('Column ${index + 1}: "${_headers[index]}"'),
            );
          }),
        ],
        onChanged: onChanged,
      ),
    );
  }

  // ── Step 3: Preview Step ──
  Widget _buildPreviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatBadge('${_validCount} Ready', AppColors.success),
            const SizedBox(width: 8),
            _buildStatBadge('${_dupCount} Duplicates', AppColors.warning),
            const SizedBox(width: 8),
            _buildStatBadge('${_invalidCount} Invalid', AppColors.error),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _previewRows.length,
            separatorBuilder: (c, i) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final row = _previewRows[index];
              return ListTile(
                dense: true,
                title: Text(row.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: Text('${row.phone} • ${row.email ?? 'No email'}', style: const TextStyle(color: AppColors.textSecondary)),
                trailing: _buildStatusChip(row.status),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildStatusChip(_RowStatus status) {
    switch (status) {
      case _RowStatus.ready:
        return const Chip(
          label: Text('Ready', style: TextStyle(color: Colors.white, fontSize: 11)),
          backgroundColor: AppColors.success,
          padding: EdgeInsets.zero,
        );
      case _RowStatus.duplicate:
        return const Chip(
          label: Text('Duplicate (Skip)', style: TextStyle(color: AppColors.textPrimary, fontSize: 11)),
          backgroundColor: AppColors.warning,
          padding: EdgeInsets.zero,
        );
      case _RowStatus.invalid:
        return const Chip(
          label: Text('Missing Fields', style: TextStyle(color: Colors.white, fontSize: 11)),
          backgroundColor: AppColors.error,
          padding: EdgeInsets.zero,
        );
    }
  }

  // ── Operations ──

  Future<void> _pickFile() async {
    setState(() => _isProcessingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        
        String csvContent = '';
        if (bytes != null) {
          csvContent = utf8.decode(bytes);
        } else if (file.path != null) {
          final path = file.path!;
          final ioFile = io.File(path);
          csvContent = await ioFile.readAsString();
        }

        final List<List<dynamic>> rows = Csv().decode(csvContent);
        if (rows.isNotEmpty) {
          setState(() {
            _selectedFile = file;
            _headers = rows.first;
            _csvData = rows.sublist(1);
            
            // Try to auto-detect mappings
            _autoMapHeaders(_headers);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse file: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isProcessingFile = false);
    }
  }

  void _autoMapHeaders(List<dynamic> headers) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toString().toLowerCase().trim();
      if (h.contains('name') || h.contains('buyer')) {
        _nameColIdx = i;
      } else if (h.contains('phone') || h.contains('mobile') || h.contains('contact')) {
        _phoneColIdx = i;
      } else if (h.contains('email') || h.contains('mail')) {
        _emailColIdx = i;
      } else if (h.contains('note') || h.contains('inquiry') || h.contains('comment')) {
        _notesColIdx = i;
      } else if (h.contains('source') || h.contains('channel')) {
        _channelColIdx = i;
      }
    }
  }

  Future<void> _handleNextStep() async {
    if (_currentStep == 0) {
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a CSV file first.'), backgroundColor: AppColors.error),
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedPropertyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an attribution property.'), backgroundColor: AppColors.error),
        );
        return;
      }
      if (_nameColIdx == null || _phoneColIdx == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and Phone mapping are required.'), backgroundColor: AppColors.error),
        );
        return;
      }
      
      setState(() => _isProcessingFile = true);
      await _generatePreview();
      setState(() {
        _isProcessingFile = false;
        _currentStep = 2;
      });
    } else if (_currentStep == 2) {
      await _executeImport();
    }
  }

  Future<void> _generatePreview() async {
    _previewRows.clear();
    _validCount = 0;
    _dupCount = 0;
    _invalidCount = 0;

    final leadNotifier = ref.read(leadProvider.notifier);

    for (final row in _csvData) {
      if (row.length <= _nameColIdx! || row.length <= _phoneColIdx!) {
        _previewRows.add(_ImportRowPreview(
          name: 'N/A',
          phone: 'N/A',
          status: _RowStatus.invalid,
        ));
        _invalidCount++;
        continue;
      }

      final name = row[_nameColIdx!].toString().trim();
      final phone = row[_phoneColIdx!].toString().trim();
      
      if (name.isEmpty || phone.isEmpty) {
        _previewRows.add(_ImportRowPreview(
          name: name.isEmpty ? 'Empty Name' : name,
          phone: phone.isEmpty ? 'Empty Phone' : phone,
          status: _RowStatus.invalid,
        ));
        _invalidCount++;
        continue;
      }

      final email = _emailColIdx != null && row.length > _emailColIdx!
          ? row[_emailColIdx!].toString().trim()
          : null;
      final notes = _notesColIdx != null && row.length > _notesColIdx!
          ? row[_notesColIdx!].toString().trim()
          : null;
      final channel = _channelColIdx != null && row.length > _channelColIdx!
          ? row[_channelColIdx!].toString().trim()
          : 'walk_in';

      // Check for local/database duplicate
      final duplicate = await leadNotifier.checkDuplicateLead(phone, email ?? '');
      if (duplicate != null) {
        _previewRows.add(_ImportRowPreview(
          name: name,
          phone: phone,
          email: email,
          notes: notes,
          channel: channel,
          status: _RowStatus.duplicate,
        ));
        _dupCount++;
      } else {
        _previewRows.add(_ImportRowPreview(
          name: name,
          phone: phone,
          email: email,
          notes: notes,
          channel: channel,
          status: _RowStatus.ready,
        ));
        _validCount++;
      }
    }
  }

  Future<void> _executeImport() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null || profile.companyId == null) return;

    final leadsToInsert = _previewRows
        .where((r) => r.status == _RowStatus.ready)
        .map((r) => {
              'company_id': profile.companyId,
              'property_id': _selectedPropertyId,
              'buyer_name': r.name,
              'buyer_phone': r.phone,
              'buyer_email': r.email?.isEmpty ?? true ? null : r.email,
              'notes': r.notes?.isEmpty ?? true ? null : r.notes,
              'source_channel': r.channel?.isEmpty ?? true ? 'walk_in' : r.channel,
              'stage': LeadStage.newLead.value,
            })
        .toList();

    if (leadsToInsert.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid leads to import.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isImporting = true);
    final success = await ref.read(leadProvider.notifier).bulkInsertLeads(leadsToInsert);
    setState(() => _isImporting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported ${leadsToInsert.length} leads!')),
        );
        Navigator.pop(context);
      } else {
        final error = ref.read(leadProvider).errorMessage ?? 'Import failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  InputDecoration _dropdownDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    );
  }
}

enum _RowStatus { ready, duplicate, invalid }

class _ImportRowPreview {
  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final String? channel;
  final _RowStatus status;

  _ImportRowPreview({
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    this.channel,
    required this.status,
  });
}
