import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/core/utils/navigation_helpers.dart';

class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key});

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;
  bool _isSuccess = false;
  String? _errorMessage;

  static const String _phone1 = '+2349135598800';
  static const String _phone2 = '+2348065441537';
  static const String _whatsAppNumber = '2349135598800';
  static const String _email = 'nissieidealshelterslimited@gmail.com';
  static const String _address =
      'Suite 2, Shema filling station complex, Asokoro extension, After Abacha barracks bridge, Abuja Keffi Expressway.';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrlHelper(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp() async {
    const msg = 'Hello Nissie Ideal Shelters, I am contacting you from your website to inquire about your verified properties.';
    final url = 'https://wa.me/$_whatsAppNumber?text=${Uri.encodeComponent(msg)}';
    await _launchUrlHelper(url);
  }

  Future<void> _handleSubmit() async {
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
        notes: _messageController.text.trim(),
        consentText: 'Inquiry submitted from Nissie website contact page.',
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
        _errorMessage = 'Could not send message right now. Please reach out via WhatsApp!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 960;

    return SafeBackScope(
      fallbackRoute: '/',
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWhatsApp,
        backgroundColor: const Color(0xFF25D366),
        elevation: 6,
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
      ),
      appBar: _buildNavBar(context, isWide),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    children: [
                      const Text(
                        'Get In Touch',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Have questions about our listings or want to schedule a site inspection? Contact our Abuja team today.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Two-column Card (Matching Screenshot exactly)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildContactInfoPanel()),
                          Expanded(flex: 7, child: _buildMessageFormPanel(isWide)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildContactInfoPanel(),
                          _buildMessageFormPanel(isWide),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 50),

            // Official Footer
            _buildFooter(context),
          ],
        ),
      ),
    ),
  );
  }

  PreferredSizeWidget _buildNavBar(BuildContext context, bool isWide) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
        onPressed: () => context.popOrGo('/'),
      ),
      toolbarHeight: 70,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.jpg',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 40,
                height: 40,
                color: const Color(0xFF0077B6),
                child: const Icon(Icons.apartment, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'NIS LTD',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        if (isWide) ...[
          _navLink('Home', () => context.go('/')),
          _navLink('Properties', () => context.go('/')),
          _navLink('About Us', () => context.push('/about')),
          _navLink('Contact', () {}, isActive: true),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 18.0),
            child: ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              child: const Text('Portal Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Color(0xFF0F172A)),
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF0F172A)),
            onPressed: () => context.push('/about'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Portal', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0088CC))),
            ),
          ),
        ],
      ],
    );
  }

  Widget _navLink(String label, VoidCallback onTap, {bool isActive = false}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: isActive ? const Color(0xFF0088CC) : const Color(0xFF334155),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2.5,
              width: 36,
              color: const Color(0xFF0088CC),
            ),
        ],
      ),
    );
  }

  Widget _buildContactInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: const BoxDecoration(
        color: Color(0xFF0077B6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Reach out through any of our channels or visit our office. Our client advisors are ready to assist you.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFE0F2FE),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),

          // Office Headquarters
          _buildInfoItem(
            icon: Icons.location_on_rounded,
            title: 'OFFICE HEADQUARTERS',
            content: _address,
          ),
          const SizedBox(height: 28),

          // Call Representatives
          _buildInfoItem(
            icon: Icons.phone_rounded,
            title: 'CALL REPRESENTATIVE',
            content: '$_phone1\n$_phone2',
            onTap: () => _launchUrlHelper('tel:$_phone1'),
          ),
          const SizedBox(height: 28),

          // Email Inquiries
          _buildInfoItem(
            icon: Icons.email_rounded,
            title: 'EMAIL INQUIRIES',
            content: _email,
            onTap: () => _launchUrlHelper('mailto:$_email'),
          ),
          const SizedBox(height: 36),

          // WhatsApp Direct Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWhatsApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 20),
              label: const Text('Chat On WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String content,
    VoidCallback? onTap,
  }) {
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBAE6FD),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: body);
    }
    return body;
  }

  Widget _buildMessageFormPanel(bool isWide) {
    return Container(
      padding: const EdgeInsets.all(36),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send A Message',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0077B6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fill in the form fields. A customer representative will get in touch with you shortly.',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 28),

          if (_isSuccess) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Message Received!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Our representative will contact you via WhatsApp/call shortly.', style: TextStyle(color: Color(0xFF047857), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
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
          ] else ...[
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name
                  _formLabel('YOUR FULL NAME'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _nameController,
                    hintText: 'e.g. John Doe',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 18),

                  // Phone & Email Row
                  if (isWide)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _formLabel('WHATSAPP NUMBER'),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _phoneController,
                                hintText: 'e.g. 08123456789',
                                keyboardType: TextInputType.phone,
                                validator: (v) => (v == null || v.trim().length < 8) ? 'Enter valid number' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _formLabel('EMAIL ADDRESS'),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'e.g. j.doe@example.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _formLabel('WHATSAPP NUMBER'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _phoneController,
                      hintText: 'e.g. 08123456789',
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 8) ? 'Enter valid number' : null,
                    ),
                    const SizedBox(height: 18),
                    _formLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'e.g. j.doe@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Message / Property Interest
                  _formLabel('MESSAGE / PROPERTY INTEREST'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _messageController,
                    hintText: "I'm interested in properties around Asokoro...",
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your message' : null,
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0077B6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Send Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0077B6),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0077B6), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NISSIE IDEALSHELTERS LTD',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Premium real estate agency delivering modern duplexes, serviced apartments, and secure lands across Abuja and surrounding districts.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'RC: 7867098',
                          style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 40),
              Text(
                '© 2026 Nissie Ideal Shelters Ltd. All rights reserved. | RC: 7867098',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
