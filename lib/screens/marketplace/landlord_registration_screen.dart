import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/marketplace_provider.dart';

class LandlordRegistrationScreen extends ConsumerStatefulWidget {
  const LandlordRegistrationScreen({super.key});

  @override
  ConsumerState<LandlordRegistrationScreen> createState() => _LandlordRegistrationScreenState();
}

class _LandlordRegistrationScreenState extends ConsumerState<LandlordRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Host Details
  String _hostType = 'landlord'; // 'landlord' or 'agency'
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _operatingCity = 'Abuja';

  // Property Details
  final _propTitleController = TextEditingController();
  String _listingType = 'rent'; // 'rent' or 'sale'
  String _propertyCategory = 'apartment';
  final _districtController = TextEditingController();
  final _priceController = TextEditingController();
  int _bedrooms = 3;
  final int _bathrooms = 3;
  final _descController = TextEditingController();

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _submittedTitle;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _propTitleController.dispose();
    _districtController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // 1. Create account under Landlord role
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: UserRole.landlord,
        companyId: AppStrings.defaultCompanyId,
      );

      // 2. Add submitted property to local marketplace provider as pending/verified
      final price = double.tryParse(_priceController.text.replaceAll(',', '').trim()) ?? 0.0;
      final newProp = Property(
        id: 'prop_landlord_${DateTime.now().millisecondsSinceEpoch}',
        companyId: AppStrings.defaultCompanyId,
        title: _propTitleController.text.trim(),
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : 'Verified listing submitted by $fullName ($_hostType). Features modern amenities and secure location.',
        location: '${_districtController.text.trim()}, $_operatingCity',
        price: price,
        status: PropertyStatus.available,
        images: [
          _listingType == 'rent'
              ? 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80'
              : 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=800&q=80',
        ],
        commissionType: CommissionType.percentage,
        commissionValue: 5.0,
        listingType: _listingType,
        propertyCategory: _propertyCategory,
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        city: _operatingCity,
        stateLocation: _operatingCity == 'Lagos' ? 'Lagos' : 'FCT',
        district: _districtController.text.trim(),
        rentPeriod: _listingType == 'rent' ? 'year' : 'total',
        inspectionFee: 3000.0,
        isMarketplace: true,
        isVerified: true,
        shieldedContact: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Prepend to marketplace
      ref.read(marketplaceProvider.notifier).addProperty(newProp);

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _submittedTitle = newProp.title;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text(
          'Landlord & Agency Portal',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _isSuccess ? _buildSuccessScreen() : _buildForm(isWide),
    );
  }

  Widget _buildForm(bool isWide) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? (MediaQuery.of(context).size.width - 760) / 2 : 20.0,
        vertical: 32.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Intro
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '⭐ LIST YOUR PROPERTY',
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Get Paying Renters & Buyers Without Roadside Hassle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'List your apartment, duplex, or commercial property with Nissie. We dispatch pre-screened clients directly to you and protect your rent payments via escrow.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Section 1: Landlord Profile ──
            _buildSectionHeader(
              icon: Icons.person_pin_rounded,
              title: '1. Host & Landlord Profile',
              subtitle: 'Tell us who you are so we can route client inspection alerts directly to you.',
            ),
            const SizedBox(height: 14),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Host Type Toggle
                    const Text('Who is listing this property?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRadioTile(
                            title: 'Direct Landlord',
                            subtitle: 'I own the property',
                            value: 'landlord',
                            groupValue: _hostType,
                            onChanged: (val) => setState(() => _hostType = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildRadioTile(
                            title: 'Licensed Realtor',
                            subtitle: 'Agency / Manager',
                            value: 'agency',
                            groupValue: _hostType,
                            onChanged: (val) => setState(() => _hostType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Full Name / Agency Name
                    Text(
                      _hostType == 'agency' ? 'Agency / Brokerage Name' : 'Landlord Full Name',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: _hostType == 'agency' ? 'e.g. Apex Realty Partners Ltd' : 'e.g. Alhaji Mustapha Bello',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone / WhatsApp
                    const Text('WhatsApp Phone Number (For Inspection Notifications)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. 08031234567',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid Nigerian phone number' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email Address
                    const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'e.g. contact@apexrealty.ng',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    const Text('Create Account Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 16),

                    // Operating City
                    const Text('Operating City', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _operatingCity,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Abuja', child: Text('Abuja (FCT)')),
                        DropdownMenuItem(value: 'Lagos', child: Text('Lagos State')),
                        DropdownMenuItem(value: 'Port Harcourt', child: Text('Port Harcourt')),
                        DropdownMenuItem(value: 'Ibadan', child: Text('Ibadan')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _operatingCity = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Section 2: Property Details ──
            _buildSectionHeader(
              icon: Icons.home_work_rounded,
              title: '2. Your Property Details',
              subtitle: 'Describe the property you want to list for rent or sale.',
            ),
            const SizedBox(height: 14),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Purpose: Rent vs Sale
                    const Text('Listing Purpose', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _listingType = 'rent'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _listingType == 'rent' ? const Color(0xFF059669) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'FOR RENT 🏠',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _listingType == 'rent' ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _listingType = 'sale'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _listingType == 'sale' ? const Color(0xFF2563EB) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'FOR SALE 🏷️',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _listingType == 'sale' ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Title
                    const Text('Property Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _propTitleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Spacious 3-Bedroom Serviced Apartment with BQ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a property title' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category & District
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _propertyCategory,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'apartment', child: Text('Apartment / Flat', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'duplex', child: Text('Duplex / Terrace', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'bungalow', child: Text('Bungalow', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'self_contain', child: Text('Self-Contain / Mini', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'land', child: Text('Land / Plot', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'commercial', child: Text('Commercial / Office', style: TextStyle(fontSize: 13))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _propertyCategory = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('District / Area', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _districtController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Maitama, Lekki',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter district' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price & Rent Period
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _listingType == 'rent' ? 'Annual Rent (₦)' : 'Selling Price (₦)',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: _listingType == 'rent' ? 'e.g. 4,500,000' : 'e.g. 65,000,000',
                                  prefixText: '₦ ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter price' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Bedrooms', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: _bedrooms,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                items: [0, 1, 2, 3, 4, 5, 6].map((b) => DropdownMenuItem(value: b, child: Text('$b Beds', style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _bedrooms = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description / Key Features
                    const Text('Property Features & Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g. 24/7 security, central generator, fitted kitchen, borehole water, tarred access road...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Listing & Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '🛡️ Nissie verifies every listing within 2–4 hours before going live.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppColors.primary : const Color(0xFF1E293B))),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.green, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Property Submitted Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Text(
                'Congratulations! Your property "$_submittedTitle" has been received by the Nissie verification desk.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Your Landlord Account is active.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Our inspection team reviews photos within 2-4 hours.', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('You will receive WhatsApp alerts when clients book site visits.', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => context.go('/'),
                      child: const Text('Back to Marketplace'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => context.go('/login'),
                      child: const Text('Go to Landlord Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
