import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/providers/lead_provider.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/providers/partner_provider.dart';

class ManualLeadScreen extends ConsumerStatefulWidget {
  const ManualLeadScreen({super.key});

  @override
  ConsumerState<ManualLeadScreen> createState() => _ManualLeadScreenState();
}

class _ManualLeadScreenState extends ConsumerState<ManualLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPropertyId;
  String? _selectedPartnerId;
  String _sourceChannel = 'walk_in';
  bool _isSaving = false;

  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _buyerEmailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a property listing.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final success = await ref.read(leadProvider.notifier).createLead(
          propertyId: _selectedPropertyId!,
          buyerName: _buyerNameController.text.trim(),
          buyerPhone: _buyerPhoneController.text.trim(),
          buyerEmail: _buyerEmailController.text.trim().isEmpty ? null : _buyerEmailController.text.trim(),
          sourceChannel: _sourceChannel,
          partnerId: _selectedPartnerId,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead registered successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(leadProvider).errorMessage ?? 'Failed to save lead';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
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
    final properties = ref.watch(propertyProvider).properties.where((p) => p.status == PropertyStatus.available).toList();
    final partners = ref.watch(partnerProvider).partners.where((p) => p.status == PartnerStatus.approved).toList();
    
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Lead Manually'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Buyer Details Card ──
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buyer Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _buyerNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(label: 'Buyer Full Name', icon: Icons.person_outline),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter buyer name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _buyerPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration(label: 'Buyer Phone Number', icon: Icons.phone_outlined),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter buyer phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _buyerEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration(label: 'Buyer Email Address (Optional)', icon: Icons.email_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Referral Attribution Card ──
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property & Partner Attribution',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Property Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPropertyId,
                        decoration: _inputDecoration(label: 'Select Property Listing', icon: Icons.home_work_outlined),
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
                        validator: (value) => value == null ? 'Please select a property listing' : null,
                      ),
                      const SizedBox(height: 16),

                      // Partner Dropdown
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedPartnerId,
                        decoration: _inputDecoration(label: 'Attributed Partner (Optional)', icon: Icons.handshake_outlined),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Direct Client (No Partner Referral)'),
                          ),
                          ...partners.map((partner) {
                            return DropdownMenuItem<String?>(
                              value: partner.id,
                              child: Text('${partner.fullName ?? partner.email} (${partner.referralCode})'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPartnerId = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Source Channel
                      DropdownButtonFormField<String>(
                        initialValue: _sourceChannel,
                        decoration: _inputDecoration(label: 'Lead Source Channel', icon: Icons.campaign_outlined),
                        items: const [
                          DropdownMenuItem(value: 'walk_in', child: Text('Walk In / Offline')),
                          DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Referral')),
                          DropdownMenuItem(value: 'website', child: Text('Direct Website')),
                          DropdownMenuItem(value: 'referral', child: Text('Other Referrals')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _sourceChannel = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Notes Card ──
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Negotiation Notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter initial buyer inquiries or walk-in negotiation details...',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Action Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Register Buyer Lead',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }
}
