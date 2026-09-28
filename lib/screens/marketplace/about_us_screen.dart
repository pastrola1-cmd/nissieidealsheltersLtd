import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const String _whatsAppNumber = '2349135598800';

  Future<void> _openWhatsApp() async {
    const msg = 'Hello Nissie Ideal Shelters, I am contacting you from your website.';
    final url = 'https://wa.me/$_whatsAppNumber?text=${Uri.encodeComponent(msg)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            // ── Hero Banner ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? (size.width - 1100) / 2 : 24,
                vertical: 60,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0077B6), Color(0xFF023E8A)],
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'RC: 7867098 • CORPORATE PROFILE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Building More Than Properties — Creating Secure Futures',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'At NISSIE IDEAL Shelters, we believe that real estate is more than land and buildings; it is the foundation for wealth creation, family security, and lasting legacy.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFE0F2FE),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Content Container ──
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Building More Than Properties
                    _buildTextSection(
                      title: 'Building More Than Properties',
                      content:
                          'At NISSIE IDEAL Shelters, we believe that real estate is more than land and buildings; it is the foundation for wealth creation, family security, and lasting legacy.\n\nWe are a trusted real estate and property development company committed to helping individuals, families, and investors acquire genuine, strategically located, and high-value properties with confidence. Through integrity, innovation, and excellence, we provide opportunities that transform dreams of ownership into reality.\n\nWhether you are purchasing your first property, securing land for future development, or building a diversified investment portfolio, we are dedicated to guiding you every step of the way.',
                    ),
                    const SizedBox(height: 40),

                    // Section 2: Your Trusted Partner
                    _buildTextSection(
                      title: 'Your Trusted Partner',
                      badge: 'RC: 7867098',
                      content:
                          'NISSIE IDEAL Shelters Ltd (RC: 7867098) was established with a clear vision: to make property ownership accessible, secure, profitable, and stress-free.\n\nOver the years, we have built a reputation for delivering verified real estate opportunities backed by professional expertise, transparent processes, and exceptional customer service.\n\nOur team combines market knowledge, strategic insights, and industry experience to help clients make informed property decisions that generate long-term value. We do not simply sell properties—we help people build futures, create wealth, and achieve financial freedom through real estate.',
                    ),
                    const SizedBox(height: 48),

                    // Section 3: Mission & Vision
                    isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildMissionVisionCard(
                                  emoji: '🎯',
                                  title: 'Our Mission',
                                  description:
                                      'To provide secure, transparent, and rewarding real estate solutions that empower individuals, families, and investors to achieve their property ownership and wealth-building goals.',
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildMissionVisionCard(
                                  emoji: '👁',
                                  title: 'Our Vision',
                                  description:
                                      "To become one of Nigeria's most trusted and respected real estate companies, delivering innovative property solutions that transform communities and create lasting value for generations.",
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildMissionVisionCard(
                                emoji: '🎯',
                                title: 'Our Mission',
                                description:
                                    'To provide secure, transparent, and rewarding real estate solutions that empower individuals, families, and investors to achieve their property ownership and wealth-building goals.',
                              ),
                              const SizedBox(height: 18),
                              _buildMissionVisionCard(
                                emoji: '👁',
                                title: 'Our Vision',
                                description:
                                    "To become one of Nigeria's most trusted and respected real estate companies, delivering innovative property solutions that transform communities and create lasting value for generations.",
                              ),
                            ],
                          ),
                    const SizedBox(height: 52),

                    // Section 4: Core Values
                    const Text(
                      'Core Values',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'These values define our corporate culture and guide our interactions with clients, partners, and regulators daily.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildValueCard('Integrity', 'We uphold honesty, transparency, and ethical practices in every transaction.', isWide),
                        _buildValueCard('Excellence', 'We strive for the highest standards in service delivery, project execution, and customer satisfaction.', isWide),
                        _buildValueCard('Trust', 'We build lasting relationships through reliability, accountability, and consistency.', isWide),
                        _buildValueCard('Innovation', 'We embrace modern solutions and technologies that enhance the real estate experience.', isWide),
                        _buildValueCard('Customer Success', "Our clients' goals and satisfaction remain at the center of everything we do.", isWide),
                      ],
                    ),
                    const SizedBox(height: 52),

                    // Section 5: Core Services
                    const Text(
                      'Our Core Services',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Delivering specialized, secure, and professional real estate solutions across our core services.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildServiceItem(Icons.home_work_rounded, 'Property Sales', 'Helping clients acquire verified residential and commercial properties in strategic locations.')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildServiceItem(Icons.landscape_rounded, 'Land Acquisition', 'Providing access to genuine land investments with proper documentation and growth potential.')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildServiceItem(Icons.trending_up_rounded, 'Investment Advisory', 'Guiding investors toward opportunities that maximize returns and long-term value.')),
                            ],
                          )
                        : Column(
                            children: [
                              _buildServiceItem(Icons.home_work_rounded, 'Property Sales', 'Helping clients acquire verified residential and commercial properties in strategic locations.'),
                              const SizedBox(height: 14),
                              _buildServiceItem(Icons.landscape_rounded, 'Land Acquisition', 'Providing access to genuine land investments with proper documentation and growth potential.'),
                              const SizedBox(height: 14),
                              _buildServiceItem(Icons.trending_up_rounded, 'Investment Advisory', 'Guiding investors toward opportunities that maximize returns and long-term value.'),
                            ],
                          ),
                    const SizedBox(height: 16),
                    isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildServiceItem(Icons.construction_rounded, 'Property Development', 'Developing quality projects that combine functionality, comfort, and investment potential.')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildServiceItem(Icons.support_agent_rounded, 'Real Estate Consultancy', 'Offering professional advice to help clients make informed and profitable property decisions.')),
                              const SizedBox(width: 16),
                              const Expanded(child: SizedBox()),
                            ],
                          )
                        : Column(
                            children: [
                              _buildServiceItem(Icons.construction_rounded, 'Property Development', 'Developing quality projects that combine functionality, comfort, and investment potential.'),
                              const SizedBox(height: 14),
                              _buildServiceItem(Icons.support_agent_rounded, 'Real Estate Consultancy', 'Offering professional advice to help clients make informed and profitable property decisions.'),
                            ],
                          ),
                    const SizedBox(height: 52),

                    // Section 6: Why Choose NISSIE IDEAL Shelters?
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            'Why Choose NISSIE IDEAL Shelters?',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We believe that real estate transactions should be built on security, efficiency, and absolute trust. Over the years, we have optimized our process to deliver unmatched reliability for all property acquisitions.',
                            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          _buildPillarItem('Verified and secure property transactions', 'Every property undergoes rigid ownership and structural auditing.'),
                          _buildPillarItem('Strategic investment opportunities', 'Properties situated inside high-growth areas with premium returns.'),
                          _buildPillarItem('Transparent documentation process', 'Clear titles, survey plans, and official plot allocations without hassle.'),
                          _buildPillarItem('Professional customer support', 'Dedicated advisory teams to walk you through the purchasing steps.'),
                          _buildPillarItem('Flexible acquisition options', 'Structured plans designed to accommodate varying budgets.'),
                          _buildPillarItem('Commitment to excellence and integrity', 'High corporate standard aligned with trust and absolute legal verification.'),
                          _buildPillarItem('Long-term wealth creation focus', 'We help you construct a secure property portfolio for generational value.', isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),

                    // Section 7: Turning Dreams Into Valuable Assets (Quote & CTA)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0077B6), Color(0xFF023E8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Turning Dreams Into Valuable Assets',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '"Every property represents an opportunity. Every client represents a partnership. Every transaction represents trust. Together, let\'s build a future of security, prosperity, and lasting value."',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: Color(0xFFE0F2FE), fontStyle: FontStyle.italic, height: 1.6),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'NISSIE IDEAL Shelters — Where Vision Meets Value.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: Color(0xFFBAE6FD), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 14,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => context.go('/'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0077B6),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Browse Listings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              ElevatedButton(
                                onPressed: () => context.push('/contact'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Contact Our Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNavBar(BuildContext context, bool isWide) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      automaticallyImplyLeading: false,
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
          _navLink('About Us', () {}, isActive: true),
          _navLink('Contact', () => context.push('/contact')),
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
            icon: const Icon(Icons.support_agent_outlined, color: Color(0xFF0F172A)),
            onPressed: () => context.push('/contact'),
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

  Widget _buildTextSection({required String title, required String content, String? badge}) {
    return Container(
      padding: const EdgeInsets.all(32),
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
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0077B6)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(fontSize: 14.5, color: Colors.grey.shade700, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionVisionCard({required String emoji, required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(String title, String desc, bool isWide) {
    return Container(
      width: isWide ? 340 : double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0077B6), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildServiceItem(IconData icon, String title, String desc) {
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
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0077B6), size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarItem(String title, String desc, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF0077B6), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) const Divider(height: 24, color: Color(0xFFF1F5F9)),
      ],
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
