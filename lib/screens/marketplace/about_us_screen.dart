import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.support_agent_rounded, size: 18),
              label: const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => context.push('/contact'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? (size.width - 900) / 2 : 24,
                vertical: 48,
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
                      'RC: 1894231 • FEDERAL REPUBLIC OF NIGERIA',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Building Integrity & Transparency into Nigerian Real Estate',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Nissie Ideal Shelters Limited is a registered real estate firm committed to authentic property development, brokerage, and our breakthrough Anti-Extortion Inspection Guarantee.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF94A3B8),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Body
            Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Overview Card
                  Container(
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.corporate_fare_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'About Nissie Ideal Shelters Limited',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Licensed Property Development & Facility Brokerage',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Founded with a mission to eliminate fraud and extortion from the Nigerian property market, Nissie Ideal Shelters Limited operates as an integrated property firm headquartered in the Central Business District of Abuja, with operational presence in Lagos State.\n\nWe provide verified residential homes, luxury terraces, serviced apartments, and title-cleared commercial lands for individuals, corporate institutions, and diaspora investors.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 3 Core Pillars
                  const Text(
                    'Our Core Operating Pillars',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCardWide = constraints.maxWidth > 700;
                      if (isCardWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPillarCard(
                              icon: Icons.verified_user_rounded,
                              iconColor: const Color(0xFF059669),
                              title: '100% Escrow Guarantee',
                              description: 'No inspection fee is ever handed in cash. Client deposits are held securely in escrow and released to agents with a 4-digit PIN only upon successful physical inspection.',
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPillarCard(
                              icon: Icons.foundation_rounded,
                              iconColor: AppColors.primary,
                              title: 'Direct Developer Estates',
                              description: 'We develop and manage master-planned residential properties in Abuja and Lagos with verifiable titles (C of O, Governor\'s Consent, Gazette).',
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPillarCard(
                              icon: Icons.groups_rounded,
                              iconColor: const Color(0xFF2563EB),
                              title: 'Licensed Partner Realtors',
                              description: 'Our digital academy and accredited realtor network ensures verified viewings, transparent paperwork, and zero unannounced markups.',
                            )),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildPillarCard(
                              icon: Icons.verified_user_rounded,
                              iconColor: const Color(0xFF059669),
                              title: '100% Escrow Guarantee',
                              description: 'No inspection fee is ever handed in cash. Client deposits are held securely in escrow and released to agents with a 4-digit PIN only upon successful physical inspection.',
                            ),
                            const SizedBox(height: 14),
                            _buildPillarCard(
                              icon: Icons.foundation_rounded,
                              iconColor: AppColors.primary,
                              title: 'Direct Developer Estates',
                              description: 'We develop and manage master-planned residential properties in Abuja and Lagos with verifiable titles (C of O, Governor\'s Consent, Gazette).',
                            ),
                            const SizedBox(height: 14),
                            _buildPillarCard(
                              icon: Icons.groups_rounded,
                              iconColor: const Color(0xFF2563EB),
                              title: 'Licensed Partner Realtors',
                              description: 'Our digital academy and accredited realtor network ensures verified viewings, transparent paperwork, and zero unannounced markups.',
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 36),

                  // Physical Offices & Operating Hours
                  Container(
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
                          'Corporate Headquarters & Operating Hours',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 16),
                        _buildOfficeItem(
                          icon: Icons.location_city_rounded,
                          title: 'Abuja Head Office (FCT)',
                          detail: 'Central Business District, Abuja, Federal Capital Territory, Nigeria',
                        ),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        _buildOfficeItem(
                          icon: Icons.apartment_rounded,
                          title: 'Lagos Branch Office',
                          detail: 'Victoria Island, Lagos State, Nigeria',
                        ),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        _buildOfficeItem(
                          icon: Icons.access_time_rounded,
                          title: 'Operating Hours',
                          detail: 'Monday – Saturday: 8:00 AM – 6:00 PM (Emergency lines active 24/7)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Bottom Action Callout
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Have Questions or Need a Verified Tour?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Speak directly with our property advisory desk or chat with us on WhatsApp.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => context.push('/contact'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.support_agent_rounded, size: 20),
                              label: const Text('Contact Property Desk', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.search, size: 20),
                              label: const Text('Browse Properties', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Widget _buildPillarCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeItem({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
