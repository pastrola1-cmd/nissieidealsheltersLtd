import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/utils/validators.dart';
import 'package:ppn/providers/company_provider.dart';
import 'package:ppn/services/supabase_service.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  String? _logoUrl;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final company = ref.read(companyProvider).company;
    if (company != null) {
      _nameController.text = company.name;
      _emailController.text = company.email ?? '';
      _phoneController.text = company.phone ?? '';
      _addressController.text = company.address ?? '';
      _logoUrl = company.logoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final company = ref.read(companyProvider).company;
    if (company == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploadingLogo = true);

    try {
      final Uint8List bytes = await image.readAsBytes();
      final extension = image.path.split('.').last.toLowerCase();
      final path = 'logos/${company.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      final service = ref.read(supabaseServiceProvider);
      final publicUrl = await service.uploadFile(
        'company-assets',
        path,
        bytes,
        mimeType: 'image/$extension',
      );

      setState(() {
        _logoUrl = publicUrl;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully! Save to apply branding.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref.read(companyProvider.notifier).updateCompany(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          logoUrl: _logoUrl,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company profile saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      final error = ref.read(companyProvider).errorMessage ?? 'Failed to save';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(companyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Company Profile'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: state.company == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Logo Upload Section ──
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border, width: 2),
                              image: _logoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_logoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _logoUrl == null
                                ? const Icon(Icons.business_rounded, size: 48, color: AppColors.textTertiary)
                                : null,
                          ),
                          if (_isUploadingLogo)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadLogo,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Change Company Logo',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Fields ──
                    Text(
                      'Company Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      decoration: _inputDecoration(label: 'Company Name', icon: Icons.business_rounded),
                      validator: (value) => Validators.validateRequired(value, 'Company name'),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(label: 'Support Email', icon: Icons.email_outlined),
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(label: 'Contact Phone', icon: Icons.phone_outlined),
                      validator: Validators.validatePhone,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      keyboardType: TextInputType.streetAddress,
                      maxLines: 2,
                      decoration: _inputDecoration(label: 'Office Address', icon: Icons.map_outlined),
                      validator: (value) => Validators.validateRequired(value, 'Office address'),
                    ),
                    const SizedBox(height: 40),

                    // ── Save Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: state.isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                          : ElevatedButton(
                              onPressed: _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.textOnAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Save Settings',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.textOnAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
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
    );
  }
}
