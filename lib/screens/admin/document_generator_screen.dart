import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/document_provider.dart';
import 'package:nissie_ideal_shelters/services/document_template_service.dart';

class DocumentGeneratorScreen extends ConsumerStatefulWidget {
  final String leadId;
  const DocumentGeneratorScreen({super.key, required this.leadId});

  @override
  ConsumerState<DocumentGeneratorScreen> createState() => _DocumentGeneratorScreenState();
}

class _DocumentGeneratorScreenState extends ConsumerState<DocumentGeneratorScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _payoutController;
  late final TextEditingController _notesController;

  DateTime _issueDate = DateTime.now();
  bool _isGenerating = false;

  Lead? _lead;
  Property? _property;
  Profile? _partner;
  Company? _company;
  Profile? _creator;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initial load of data
    final leadState = ref.read(leadProvider);
    _lead = leadState.leads.cast<Lead?>().firstWhere((l) => l?.id == widget.leadId, orElse: () => null);

    if (_lead != null) {
      final propState = ref.read(propertyProvider);
      _property = propState.properties.cast<Property?>().firstWhere((p) => p?.id == _lead!.propertyId, orElse: () => null);

      if (_lead!.partnerId != null) {
        final partState = ref.read(partnerProvider);
        _partner = partState.partners.cast<Profile?>().firstWhere((p) => p?.id == _lead!.partnerId, orElse: () => null);
      }
    }

    _company = ref.read(companyProvider).company;
    _creator = ref.read(authProvider).profile;

    // Controllers initialization
    final buyerName = _lead?.buyerName ?? '';
    final propTitle = _property?.title ?? '';
    _titleController = TextEditingController(text: 'Offer Letter - $buyerName - $propTitle');

    final listPrice = _property?.price ?? 0.0;
    _priceController = TextEditingController(text: listPrice.toStringAsFixed(0));

    // Calculate default payout
    double defaultPayout = 0.0;
    if (_property != null) {
      if (_property!.commissionType == CommissionType.percentage) {
        defaultPayout = listPrice * (_property!.commissionValue / 100);
      } else {
        defaultPayout = _property!.commissionValue;
      }
    }
    _payoutController = TextEditingController(text: defaultPayout.toStringAsFixed(0));

    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _payoutController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _issueDate) {
      setState(() {
        _issueDate = picked;
      });
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final negotiatedPrice = double.tryParse(_priceController.text) ?? 0.0;
    final expectedPayout = double.tryParse(_payoutController.text) ?? 0.0;

    return await DocumentTemplateService.generateOfferLetter(
      company: _company!,
      lead: _lead!,
      property: _property!,
      creator: _creator!,
      negotiatedPrice: negotiatedPrice,
      expectedPayout: expectedPayout,
      issueDate: _issueDate,
      notes: _notesController.text.trim(),
      partner: _partner,
    );
  }

  Future<void> _saveAndGenerate() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final pdfBytes = await _generatePdfBytes();
      
      final variables = {
        'negotiated_price': double.tryParse(_priceController.text) ?? 0.0,
        'expected_payout': double.tryParse(_payoutController.text) ?? 0.0,
        'issue_date': _issueDate.toIso8601String(),
        'notes': _notesController.text.trim(),
        'title': _titleController.text.trim(),
      };

      final record = await ref.read(documentProvider.notifier).uploadAndCreateDocument(
            leadId: _lead!.id,
            type: DocumentType.offerLetter,
            title: _titleController.text.trim(),
            variables: variables,
            pdfBytes: pdfBytes,
          );

      if (mounted) {
        setState(() => _isGenerating = false);
        if (record != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offer Letter generated and saved to deal history!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        } else {
          final error = ref.read(documentProvider).errorMessage ?? 'Generation failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_lead == null || _property == null || _company == null || _creator == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generate Document')),
        body: const Center(
          child: Text('Required deal info could not be loaded.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Document Generator'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '1. CONFIGURE TERMS', icon: Icon(Icons.settings_outlined, size: 20)),
            Tab(text: '2. BRANDING & PREVIEW', icon: Icon(Icons.picture_as_pdf_outlined, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: CONFIGURE TERMS ───
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client & Property Summary (ReadOnly)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Deal Context Details',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryItem('Client / Buyer', _lead!.buyerName),
                        const SizedBox(height: 8),
                        _buildSummaryItem('Property Listing', _property!.title),
                        const SizedBox(height: 8),
                        _buildSummaryItem('Attributed Partner', _partner?.fullName ?? 'Direct Sale (No Partner)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Inputs Section
                  Text(
                    'Customize Template Parameters',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // Document Title Input
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Document Title',
                      prefixIcon: const Icon(Icons.title_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a document title' : null,
                  ),
                  const SizedBox(height: 16),

                  // Negotiated Price Input
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Final Negotiated Price (₦)',
                      prefixIcon: const Icon(Icons.monetization_on_outlined),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter negotiated price';
                      if (double.tryParse(v) == null) return 'Enter a valid amount';
                      return null;
                    },
                    onChanged: (val) {
                      // Proactively auto-calculate commission payout if partner exists
                      if (_partner != null && _property != null) {
                        final parsedPrice = double.tryParse(val) ?? 0.0;
                        double calcPayout = 0.0;
                        if (_property!.commissionType == CommissionType.percentage) {
                          calcPayout = parsedPrice * (_property!.commissionValue / 100);
                        } else {
                          calcPayout = _property!.commissionValue;
                        }
                        _payoutController.text = calcPayout.toStringAsFixed(0);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Expected Payout Input
                  TextFormField(
                    controller: _payoutController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Expected Partner Payout (₦)',
                      prefixIcon: const Icon(Icons.handshake_outlined),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter payout amount';
                      if (double.tryParse(v) == null) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Issue Date Input
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Document Issue Date',
                        prefixIcon: const Icon(Icons.calendar_month_rounded),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        DateFormat('MMMM dd, yyyy').format(_issueDate),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Custom Special Conditions/Notes Input
                  TextFormField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Special Conditions / Remarks (Optional)',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 50),
                        child: Icon(Icons.notes_rounded),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: 'Enter any payment plans, installment terms, or legal clarifications...',
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Navigate to Preview Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _tabController.animateTo(1);
                        }
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Proceed to Preview & Branding', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── TAB 2: BRANDING & PREVIEW ───
          Column(
            children: [
              // Notice panel about logo loading
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: AppColors.accent.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using dynamic agency header: ${_company!.name}',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Interactive PDF Preview Viewport
              Expanded(
                child: PdfPreview(
                  build: (format) => _generatePdfBytes(),
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  loadingWidget: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.accent),
                        SizedBox(height: 12),
                        Text('Compiling PDF template...', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  pdfPreviewPageDecoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Confirm & Save Action Area
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _isGenerating
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : ElevatedButton.icon(
                          onPressed: _saveAndGenerate,
                          icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                          label: const Text('Confirm & Save to Deal History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
