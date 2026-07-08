import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/utils/validators.dart';
import 'package:nissie_ideal_shelters/providers/company_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/services/whatsapp_service.dart';

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
  final _fbPixelIdController = TextEditingController();
  final _fbCapiTokenController = TextEditingController();
  final _waPhoneIdController = TextEditingController();
  final _waWabaIdController = TextEditingController();
  final _waTokenController = TextEditingController();
  final _waTemplateController = TextEditingController();
  final _customDomainController = TextEditingController();
  
  String? _logoUrl;
  bool _isUploadingLogo = false;
  bool _obscureCapiToken = true;
  bool _lpModuleEnabled = true;
  bool _obscureWaToken = true;
  bool _waEnabled = false;
  bool _isTestingWhatsApp = false;

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
      _fbPixelIdController.text = company.fbPixelId ?? '';
      _fbCapiTokenController.text = company.fbCapiToken ?? '';
      _lpModuleEnabled = company.lpModuleEnabled;
      _waPhoneIdController.text = company.whatsappPhoneNumberId ?? '';
      _waWabaIdController.text = company.whatsappWabaId ?? '';
      _waTokenController.text = company.whatsappAccessToken ?? '';
      _waTemplateController.text = company.whatsappTemplateName.isNotEmpty ? company.whatsappTemplateName : 'property_inquiry_auto';
      _waEnabled = company.whatsappEnabled;
      _customDomainController.text = company.customDomain ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _fbPixelIdController.dispose();
    _fbCapiTokenController.dispose();
    _waPhoneIdController.dispose();
    _waWabaIdController.dispose();
    _waTokenController.dispose();
    _waTemplateController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final company = ref.read(companyProvider).company;
    if (company == null) return;

    if (company.subscriptionTier == 'free') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo upload is disabled on the Free tier. Upgrade your plan or request a dedicated app to customize your branding.'),
          backgroundColor: AppColors.warningDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

  Future<void> _sendTestWhatsAppMessage() async {
    final phoneId = _waPhoneIdController.text.trim();
    final token = _waTokenController.text.trim();
    final template = _waTemplateController.text.trim();
    final recipient = _phoneController.text.trim();

    if (phoneId.isEmpty || token.isEmpty || recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill Phone Number ID, Access Token, and Contact Phone to test.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isTestingWhatsApp = true);
    try {
      final success = await ref.read(whatsAppServiceProvider).sendTestMessage(
        phoneId: phoneId,
        accessToken: token,
        templateName: template,
        recipientPhone: recipient,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test template message sent successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send test message. Check configuration and Meta Graph settings.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingWhatsApp = false);
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
          fbPixelId: _fbPixelIdController.text.trim().isNotEmpty ? _fbPixelIdController.text.trim() : null,
          fbCapiToken: _fbCapiTokenController.text.trim().isNotEmpty ? _fbCapiTokenController.text.trim() : null,
          lpModuleEnabled: _lpModuleEnabled,
          whatsappPhoneNumberId: _waPhoneIdController.text.trim().isNotEmpty ? _waPhoneIdController.text.trim() : null,
          whatsappWabaId: _waWabaIdController.text.trim().isNotEmpty ? _waWabaIdController.text.trim() : null,
          whatsappAccessToken: _waTokenController.text.trim().isNotEmpty ? _waTokenController.text.trim() : null,
          whatsappEnabled: _waEnabled,
          whatsappTemplateName: _waTemplateController.text.trim().isNotEmpty ? _waTemplateController.text.trim() : 'property_inquiry_auto',
          customDomain: _customDomainController.text.trim().isNotEmpty ? _customDomainController.text.trim() : null,
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
          ? Center(
              child: state.errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              final companyId = ref.read(authProvider).profile?.companyId;
                              if (companyId != null) {
                                ref.read(companyProvider.notifier).loadCompany(companyId);
                              }
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: AppColors.accent),
            )
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

                    // ── Company Code display for partners invitation ──
                    Card(
                      color: AppColors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.vpn_key_rounded, color: AppColors.accent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Company Code (Tenant ID)',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: AppColors.accent),
                                  tooltip: 'Copy Company Code',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: state.company!.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Company Code copied to clipboard!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              state.company!.id,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share this code with partners so they can join your agency directly when they sign up.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state.company?.subscriptionTier == 'free') ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Free Trial Plan Active',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Want your own logo branding, custom domains, and unlimited listings? Upgrade your plan or request a dedicated custom-branded app!',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

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
                    const SizedBox(height: 32),

                    // ── Marketing & Tracking ──
                    Text(
                      'Marketing & Tracking (FB Pixel / CAPI)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _fbPixelIdController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'Facebook Pixel ID',
                        icon: Icons.analytics_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _fbCapiTokenController,
                      keyboardType: TextInputType.text,
                      obscureText: _obscureCapiToken,
                      decoration: _inputDecoration(
                        label: 'Meta Conversions API Token',
                        icon: Icons.vpn_key_outlined,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCapiToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: () {
                            setState(() => _obscureCapiToken = !_obscureCapiToken);
                          },
                        ),
                        helperText: 'Required for server-side event deduplication and offline conversion matching.',
                      ),
                    ),
                    // ── Custom Domain Section ──
                    if (state.company?.subscriptionTier == 'enterprise') ...[
                      const SizedBox(height: 24),
                      Text(
                        'White Label Custom Domain',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customDomainController,
                        keyboardType: TextInputType.url,
                        decoration: _inputDecoration(
                          label: 'Custom Domain',
                          icon: Icons.link_rounded,
                        ).copyWith(
                          helperText: 'Point your domain (CNAME) to scalewealth.app. Example: agency.com',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Module Toggle ──
                    Card(
                      color: AppColors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: SwitchListTile.adaptive(
                        title: const Text(
                          'Landing Pages & Ads Module',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          state.company?.subscriptionTier == 'basic'
                              ? 'Disabled on Starter Plan. Upgrade to enable.'
                              : state.company?.subscriptionTier == 'free'
                                  ? 'Disabled on Free Tier. Upgrade to enable.'
                                  : 'Enable conversion-optimized public property landing pages.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        value: state.company?.subscriptionTier == 'basic' || state.company?.subscriptionTier == 'free' ? false : _lpModuleEnabled,
                        activeColor: AppColors.accent,
                        onChanged: state.company?.subscriptionTier == 'basic' || state.company?.subscriptionTier == 'free'
                            ? null
                            : (val) {
                                setState(() => _lpModuleEnabled = val);
                              },
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Only show WhatsApp configs if module is enabled and not Starter/Free
                    if (_lpModuleEnabled && state.company?.subscriptionTier != 'basic' && state.company?.subscriptionTier != 'free') ...[
                      Text(
                        'WhatsApp Business API Automation (Meta)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        color: AppColors.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: SwitchListTile.adaptive(
                          title: const Text(
                            'Enable WhatsApp Auto-Broker',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          subtitle: const Text(
                            'Send transactional brochures and location details to new leads instantly.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          value: _waEnabled,
                          activeColor: const Color(0xFF25D366),
                          onChanged: (val) {
                            setState(() => _waEnabled = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _waPhoneIdController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'WhatsApp Phone Number ID',
                          icon: Icons.phone_android_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _waWabaIdController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'WhatsApp Business Account ID (WABA)',
                          icon: Icons.business_center_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _waTokenController,
                        keyboardType: TextInputType.text,
                        obscureText: _obscureWaToken,
                        decoration: _inputDecoration(
                          label: 'WhatsApp Permanent Access Token',
                          icon: Icons.vpn_key_outlined,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureWaToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textTertiary,
                            ),
                            onPressed: () {
                              setState(() => _obscureWaToken = !_obscureWaToken);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _waTemplateController,
                        keyboardType: TextInputType.text,
                        decoration: _inputDecoration(
                          label: 'Meta Approved Template Name',
                          icon: Icons.description_outlined,
                        ).copyWith(
                          helperText: 'Defaults to property_inquiry_auto. Ensure template variables match standard layout.',
                        ),
                      ),
                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: _isTestingWhatsApp ? null : _sendTestWhatsAppMessage,
                        icon: _isTestingWhatsApp 
                            ? const SizedBox(
                                width: 16, 
                                height: 16, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366))
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Send Test WhatsApp Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],

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
