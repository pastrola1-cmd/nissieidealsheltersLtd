import 'package:flutter/material.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/screens/marketplace/widgets/contact_modal.dart';

/// Informational modal highlighting Nissie Ideal Shelters Limited corporate profile & credentials.
class AboutNissieModal extends StatelessWidget {
  final bool isDialog;
  const AboutNissieModal({super.key, this.isDialog = false});

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
          child: AboutNissieModal(isDialog: true),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => const AboutNissieModal(isDialog: false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: size.height * (isDialog ? 0.85 : 0.9),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: isDialog
              ? BorderRadius.circular(24)
              : const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          elevation: isDialog ? 12 : 4,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDialog) ...[
                    // Drag Indicator for mobile bottom sheet
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
                    const SizedBox(height: 16),
                  ],

              // Header
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.apartment_rounded,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nissie Ideal Shelters Ltd',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'RC: 1894231 • Real Estate & Development Firm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Company Mission
              Text(
                'About Our Company',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nissie Ideal Shelters Limited is a registered Nigerian property development, brokerage, and facility management company with corporate presence across Abuja (FCT) and Lagos State.\n\nWe provide authentic, title-verified residential estates, luxury terrace duplexes, and rental apartments, backed by our breakthrough anti-extortion inspection guarantee.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),

              // 3 Core Pillars
              _buildPillarTile(
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF059669),
                title: '100% Escrow & Verification Guarantee',
                description: 'No inspection fee is ever handed to agents on-site without confirmation. Our platform locks deposits in escrow with a 4-digit PIN released only after physical viewing.',
              ),
              const SizedBox(height: 12),
              _buildPillarTile(
                icon: Icons.foundation_rounded,
                iconColor: AppColors.primary,
                title: 'Developer Estates & Prime Land',
                description: 'We develop master-planned residential estates in fast-appreciating growth corridors of Abuja and Lagos with verifiable titles (C of O, Governor\'s Consent, Gazette).',
              ),
              const SizedBox(height: 12),
              _buildPillarTile(
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Licensed Realtor Partner Network',
                description: 'Our digital academy and agency software empowers over 200+ trained realtors, ensuring transparent client service, scheduled viewings, and professional representation.',
              ),
              const SizedBox(height: 24),

              // Headquarters Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Corporate Offices & Operating Hours',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    _buildOfficeRow(Icons.place_rounded, 'Abuja HQ: Central Business District, Abuja FCT'),
                    const SizedBox(height: 6),
                    _buildOfficeRow(Icons.place_rounded, 'Lagos Branch: Victoria Island, Lagos State'),
                    const SizedBox(height: 6),
                    _buildOfficeRow(Icons.access_time_rounded, 'Working Hours: Monday – Saturday (8:00 AM – 6:00 PM)'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Contact Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final rootNav = Navigator.of(context, rootNavigator: true);
                    rootNav.pop();
                    Future.microtask(() {
                      if (context.mounted) {
                        ContactModal.show(context);
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Contact a Property Advisor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildPillarTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }
}
