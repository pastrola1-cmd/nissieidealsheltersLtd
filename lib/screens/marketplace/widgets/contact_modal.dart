import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

/// Interactive Contact & Inquiry Modal for Nissie Ideal Shelters
class ContactModal extends ConsumerStatefulWidget {
  final bool isDialog;
  const ContactModal({super.key, this.isDialog = false});

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 650;
    if (isDesktop) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (dialogContext) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ContactModal(isDialog: true),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => const ContactModal(isDialog: false),
      );
    }
  }

  @override
  ConsumerState<ContactModal> createState() => _ContactModalState();
}

class _ContactModalState extends ConsumerState<ContactModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  String _inquiryType = 'Rent an Apartment';
  bool _isSending = false;
  bool _isSuccess = false;
  String? _errorMessage;

  static const String _companyPhone = '+2349135598800';
  static const String _companyWhatsApp = '2349135598800';
  static const String _companyEmail = 'nissieidealshelterslimited@gmail.com';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final msg = Uri.encodeComponent(
      'Hello Nissie Ideal Shelters, I am contacting you from your website to inquire about your verified properties.',
    );
    final url = Uri.parse('https://wa.me/$_companyWhatsApp?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone() async {
    final url = Uri.parse('tel:$_companyPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendEmail() async {
    final url = Uri.parse('mailto:$_companyEmail?subject=Property%20Inquiry%20-%20Nissie%20Ideal%20Shelters');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _handleSubmitInquiry() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      await supabaseService.submitPublicLead(
        companyId: AppStrings.defaultCompanyId,
        buyerName: _nameController.text.trim(),
        buyerPhone: _phoneController.text.trim(),
        buyerEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        notes: '[$_inquiryType] ${_messageController.text.trim()}',
        consentText: 'Inquiry submitted from Nissie website contact modal.',
      );

      if (!mounted) return;
      setState(() {
        _isSending = false;
        _isSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = 'Could not submit inquiry right now. Please message us directly on WhatsApp!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: size.height * (widget.isDialog ? 0.88 : 0.9),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: widget.isDialog
              ? BorderRadius.circular(24)
              : const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          elevation: widget.isDialog ? 12 : 4,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isDialog) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],

                // Pinned Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Nissie Ideal Shelters',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'RC: 7867098 • Abuja, Nigeria',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22, color: Color(0xFF64748B)),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                // Scrollable Body Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [

              // Direct Quick Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF25D366),
                      bgColor: const Color(0xFFE8F9EE),
                      title: 'WhatsApp',
                      subtitle: 'Chat Instantly',
                      onTap: _openWhatsApp,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.phone_in_talk_rounded,
                      color: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFE0F2FE),
                      title: 'Call Desk',
                      subtitle: '+234 913 559 8800',
                      onTap: _callPhone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.email_rounded,
                      color: const Color(0xFFE11D48),
                      bgColor: const Color(0xFFFFE4E6),
                      title: 'Email',
                      subtitle: 'Inquiries',
                      onTap: _sendEmail,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Physical Office Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Headquarters & Office Hours',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Suite 2, Shema filling station complex, Asokoro extension, After Abacha barracks bridge, Abuja Keffi Expressway.\nMonday – Saturday: 8:00 AM – 6:00 PM',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Form Divider
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR SEND AN INQUIRY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                ],
              ),
              const SizedBox(height: 16),

              if (_isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inquiry Submitted Successfully!',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Our property team will review your request and get in touch with you shortly.',
                              style: TextStyle(color: Colors.teal.shade800, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isSuccess = false;
                        _nameController.clear();
                        _phoneController.clear();
                        _emailController.clear();
                        _messageController.clear();
                      });
                    },
                    child: const Text('Send Another Message'),
                  ),
                ),
              ] else ...[
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Inquiry Type Selector
                      const Text(
                        'What can we help you with?',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _inquiryType,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Rent an Apartment', child: Text('Rent a House / Apartment')),
                          DropdownMenuItem(value: 'Buy a Property', child: Text('Buy a House or Land')),
                          DropdownMenuItem(value: 'Shortlet Booking', child: Text('Shortlet / Serviced Apartment')),
                          DropdownMenuItem(value: 'List Property (Landlord)', child: Text('List My Property as a Landlord')),
                          DropdownMenuItem(value: 'Partnership / Realtor', child: Text('Realtor / Partner Program')),
                          DropdownMenuItem(value: 'General Inquiry', child: Text('General Inquiry')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _inquiryType = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Full Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Your Full Name *',
                          hintText: 'e.g. Samuel Adeyemi',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 12),

                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone / WhatsApp Number *',
                          hintText: 'e.g. 0801 234 5678',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                        validator: (v) => (v == null || v.trim().length < 8) ? 'Enter a valid phone number' : null,
                      ),
                      const SizedBox(height: 12),

                      // Email Address (Optional)
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address (Optional)',
                          hintText: 'e.g. you@example.com',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Message
                      TextFormField(
                        controller: _messageController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Your Message / Requirements',
                          hintText: 'Tell us preferred location, budget, bedrooms, or questions...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please write your message or requirements' : null,
                      ),
                      const SizedBox(height: 18),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _handleSubmitInquiry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Send Inquiry to Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
),
);
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
