import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

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

  String _inquiryType = 'Rent an Apartment';
  bool _isSending = false;
  bool _isSuccess = false;
  String? _errorMessage;

  static const String _companyPhone = '+2348000000000';
  static const String _companyWhatsApp = '2348000000000';
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
      await supabaseService.insert('leads', {
        'company_id': AppStrings.defaultCompanyId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'notes': '[$_inquiryType] ${_messageController.text.trim()}',
        'stage': 'new',
        'source': 'website_contact_page',
      });

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
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo.jpg',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 38,
                  height: 38,
                  color: AppColors.primary,
                  child: const Icon(Icons.apartment, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NISSIE IDEAL SHELTERS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Verified Properties • Rent & Sale',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Marketplace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Hero Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? (size.width - 900) / 2 : 24,
                vertical: 40,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'DIRECT CLIENT SUPPORT & INQUIRIES',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Contact Nissie Ideal Shelters Limited',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We are here to assist with verified property viewings, rent agreements, developer land sales, or escrow support.',
                    style: TextStyle(fontSize: 15, color: Color(0xFF94A3B8), height: 1.55),
                  ),
                ],
              ),
            ),

            // Main Interactive Section
            Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fast Contact Actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.chat_bubble_rounded,
                          color: const Color(0xFF25D366),
                          bgColor: const Color(0xFFE8F9EE),
                          title: 'WhatsApp Chat',
                          subtitle: 'Instant Response',
                          onTap: _openWhatsApp,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.phone_in_talk_rounded,
                          color: const Color(0xFF0284C7),
                          bgColor: const Color(0xFFE0F2FE),
                          title: 'Call Desk',
                          subtitle: '+234 800 000 0000',
                          onTap: _callPhone,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.email_rounded,
                          color: const Color(0xFFE11D48),
                          bgColor: const Color(0xFFFFE4E6),
                          title: 'Email Us',
                          subtitle: 'Official Inquiries',
                          onTap: _sendEmail,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Two column layout on wide screens: Form + Office Locations
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isTwoCol = constraints.maxWidth > 700;
                      if (isTwoCol) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildFormCard()),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: _buildOfficesCard()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildFormCard(),
                            const SizedBox(height: 24),
                            _buildOfficesCard(),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              color: Colors.white,
              child: Center(
                child: Text(
                  '© ${DateTime.now().year} Nissie Ideal Shelters Limited. All rights reserved. RC: 1894231',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send an Online Property Inquiry',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Leave a message and an advisor will contact you within 30 minutes.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

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
                  const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inquiry Sent Successfully!',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thank you! Our property advisory team will reach out to you directly.',
                          style: TextStyle(color: Colors.teal.shade800, fontSize: 13),
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
                child: const Text('Send Another Inquiry'),
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
                      child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What can we help you with? *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _inquiryType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. Samuel Adeyemi',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Your Requirements / Message *',
                      hintText: 'Describe preferred location, budget, number of bedrooms, or questions...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please specify your requirements' : null,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _handleSubmitInquiry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Send Inquiry Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildOfficesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Office Locations & Desk Hours',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.location_on_rounded, 'Abuja Head Office', 'Central Business District, Abuja FCT'),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(Icons.apartment_rounded, 'Lagos Branch Office', 'Victoria Island, Lagos State'),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(Icons.access_time_rounded, 'Business Hours', 'Mon – Sat: 8:00 AM – 6:00 PM'),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(Icons.verified_user_rounded, 'Verified Escrow Desk', 'Anti-Extortion PIN releases 24/7'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
