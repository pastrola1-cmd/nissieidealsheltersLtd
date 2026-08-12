import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';

class MarketerFollowupsScreen extends ConsumerWidget {
  const MarketerFollowupsScreen({super.key});

  String _normalizePhoneForWhatsApp(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      return '234${digits.substring(1)}';
    } else if (digits.length == 10 &&
        (digits.startsWith('7') ||
            digits.startsWith('8') ||
            digits.startsWith('9'))) {
      return '234$digits';
    } else if (digits.startsWith('234')) {
      return digits;
    }
    return digits;
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone call for $phoneNumber'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    final normalized = _normalizePhoneForWhatsApp(phoneNumber);
    final Uri launchUri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp for $phoneNumber'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadState = ref.watch(leadProvider);
    final userProfile = ref.watch(authProvider).profile;
    final currentUserId = userProfile?.id;

    // Filter leads assigned to current agent in 'contacted' or 'inspection_booked' stage
    final followUpLeads = leadState.leads.where((l) {
      final isAssigned = l.assignedAgentId == currentUserId;
      final isTargetStage = l.stage == LeadStage.contacted ||
          l.stage == LeadStage.inspectionBooked;
      return isAssigned && isTargetStage;
    }).toList();

    // Sort by followupDate ascending (soonest first) if present, otherwise by updatedAt ascending
    followUpLeads.sort((a, b) {
      if (a.followupDate != null && b.followupDate != null) {
        return a.followupDate!.compareTo(b.followupDate!);
      } else if (a.followupDate != null) {
        return -1; // Leads with scheduled follow-up date come first
      } else if (b.followupDate != null) {
        return 1;
      } else {
        return a.updatedAt.compareTo(b.updatedAt);
      }
    });

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Follow-ups',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(leadProvider.notifier).loadLeads(),
          color: AppColors.accent,
          child: leadState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Count Badge ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.task_alt_rounded,
                                color: AppColors.accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${followUpLeads.length} ${followUpLeads.length == 1 ? 'lead needs' : 'leads need'} follow-up today',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Empty State vs List ──
                      if (followUpLeads.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 60.0,
                              horizontal: 20.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: AppColors.success,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "You're all caught up! No follow-ups pending.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Check back later or review your new leads.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: followUpLeads.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final lead = followUpLeads[index];
                            final isOverdue = (lead.followupDate != null &&
                                    lead.followupDate!.isBefore(DateTime.now())) ||
                                DateTime.now().difference(lead.updatedAt).inDays > 3;

                            final isContacted =
                                lead.stage == LeadStage.contacted;
                            final badgeColor = isContacted
                                ? AppColors.warning
                                : AppColors.info;
                            final badgeBg = isContacted
                                ? AppColors.warningLight
                                : AppColors.infoLight;

                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: isOverdue
                                        ? const Border(
                                            left: BorderSide(
                                              color: AppColors.error,
                                              width: 4,
                                            ),
                                          )
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Name & Stage Badge
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lead.buyerName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeBg,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              lead.stage.label,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: badgeColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Phone & Last updated
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_outlined,
                                            size: 14,
                                            color: AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            lead.buyerPhone,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(
                                            Icons.schedule_outlined,
                                            size: 14,
                                            color: AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Updated ${_formatTimeAgo(lead.updatedAt)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              color: isOverdue
                                                  ? AppColors.error
                                                  : AppColors.textTertiary,
                                              fontWeight: isOverdue
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),

                                      // Action Buttons Row
                                      Row(
                                        children: [
                                          // Call Button
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _makePhoneCall(
                                                  context, lead.buyerPhone),
                                              icon: const Icon(
                                                Icons.phone_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                'Call',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primary,
                                                side: const BorderSide(
                                                    color: AppColors.primary),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // WhatsApp Button
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _openWhatsApp(
                                                  context, lead.buyerPhone),
                                              icon: const Icon(
                                                Icons.chat_bubble_outline,
                                                size: 16,
                                              ),
                                              label: Text(
                                                'WhatsApp',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.successDark,
                                                side: const BorderSide(
                                                    color: AppColors.success),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // View Lead Button
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => context.push(
                                                  '/marketer/leads/${lead.id}'),
                                              icon: const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                'View',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.accent,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
