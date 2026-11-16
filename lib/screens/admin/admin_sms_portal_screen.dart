import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/sms_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/partner_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/widgets/shimmer_loading.dart';
import 'package:nissie_ideal_shelters/widgets/empty_state.dart';

/// Accurate SMS Metrics & Telecom Character Encoding Calculator
class SmsMetrics {
  final int charCount;
  final int pages;
  final int maxPageChars;
  final int charsRemainingInPage;
  final bool isUnicode;
  final bool hasNairaReplaced;
  final String cleanText;

  const SmsMetrics({
    required this.charCount,
    required this.pages,
    required this.maxPageChars,
    required this.charsRemainingInPage,
    required this.isUnicode,
    required this.hasNairaReplaced,
    required this.cleanText,
  });

  factory SmsMetrics.calculate(String text) {
    final hasNaira = text.contains('₦');
    // Normalize smart quotes and dashes to preserve GSM-7
    final clean = text
        .replaceAll('₦', 'N')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('—', '-')
        .replaceAll('–', '-');

    // GSM-7 standard character set check
    final isUnicode = RegExp(r'[^\x20-\x7E\r\n\u00A0-\u00FF\u0391-\u03A9]').hasMatch(clean);
    final len = clean.length;

    if (len == 0) {
      return SmsMetrics(
        charCount: 0,
        pages: 0,
        maxPageChars: isUnicode ? 70 : 160,
        charsRemainingInPage: isUnicode ? 70 : 160,
        isUnicode: isUnicode,
        hasNairaReplaced: hasNaira,
        cleanText: clean,
      );
    }

    if (isUnicode) {
      // UCS-2 Unicode: 70 chars for single page, 67 per page for multi-page
      final pages = len <= 70 ? 1 : ((len - 1) ~/ 67) + 1;
      final charsInCurrentPage = pages == 1 ? len : ((len - 1) % 67 + 1);
      final remaining = pages == 1 ? (70 - len) : (67 - charsInCurrentPage);
      return SmsMetrics(
        charCount: len,
        pages: pages,
        maxPageChars: pages == 1 ? 70 : 67,
        charsRemainingInPage: remaining,
        isUnicode: true,
        hasNairaReplaced: hasNaira,
        cleanText: clean,
      );
    } else {
      // GSM-7: 160 chars for single page, 153 per page for multi-page
      final pages = len <= 160 ? 1 : ((len - 1) ~/ 153) + 1;
      final charsInCurrentPage = pages == 1 ? len : ((len - 1) % 153 + 1);
      final remaining = pages == 1 ? (160 - len) : (153 - charsInCurrentPage);
      return SmsMetrics(
        charCount: len,
        pages: pages,
        maxPageChars: pages == 1 ? 160 : 153,
        charsRemainingInPage: remaining,
        isUnicode: false,
        hasNairaReplaced: hasNaira,
        cleanText: clean,
      );
    }
  }
}

class AdminSmsPortalScreen extends ConsumerStatefulWidget {
  const AdminSmsPortalScreen({super.key});

  @override
  ConsumerState<AdminSmsPortalScreen> createState() => _AdminSmsPortalScreenState();
}

class _AdminSmsPortalScreenState extends ConsumerState<AdminSmsPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _customNumbersController = TextEditingController();

  String _selectedGroup = 'leads'; // 'leads', 'partners', 'custom'
  String _selectedStageFilter = 'all'; // 'all' or specific stage name
  final List<String> _selectedIndividualIds = []; // empty means all matching targets selected

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _messageController.addListener(() {
      setState(() {});
    });
    _customNumbersController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _customNumbersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smsState = ref.watch(smsCampaignProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    final isSmartSmsConfigured = authState.company?.termiiApiKey != null &&
        authState.company!.termiiApiKey!.trim().isNotEmpty &&
        !authState.company!.termiiApiKey!.trim().startsWith('tlv_');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SMS Campaign Portal'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(smsCampaignProvider.notifier).loadSmsCampaigns();
              ref.read(smsCampaignProvider.notifier).refreshWalletBalance();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Wallet / Balance Summary Card ──
          _buildBalanceBanner(smsState, isSmartSmsConfigured),

          // ── Premium Custom TabBar ──
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Compose Broadcast', icon: Icon(Icons.send_rounded, size: 18)),
                Tab(text: 'Campaign History', icon: Icon(Icons.history_rounded, size: 18)),
              ],
            ),
          ),

          // ── Tab View Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildComposeTab(smsState, isSmartSmsConfigured, theme),
                _buildHistoryTab(smsState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBanner(SmsCampaignState smsState, bool isConfigured) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.dashboardHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartSMS Solutions Live Balance',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${smsState.currency} ${smsState.walletBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConfigured ? Colors.greenAccent : Colors.amberAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isConfigured
                            ? 'Live SmartSMS Gateway Active'
                            : 'SmartSMS Token Missing (Go to Settings)',
                        style: TextStyle(
                          color: isConfigured ? Colors.white70 : Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: isConfigured ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (smsState.errorMessage != null && smsState.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    smsState.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                const SnackBar(
                  content: Text('Syncing wallet balance from SmartSMS Solutions...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await ref.read(smsCampaignProvider.notifier).refreshWalletBalance();
              final updated = ref.read(smsCampaignProvider);
              if (mounted) {
                if (updated.errorMessage != null) {
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text(updated.errorMessage!),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('Balance synced: ${updated.currency} ${updated.walletBalance.toStringAsFixed(2)}'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.sync_rounded, size: 14, color: AppColors.accent),
            label: const Text('Sync', style: TextStyle(color: AppColors.accent, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeTab(SmsCampaignState smsState, bool isConfigured, ThemeData theme) {
    final partners = ref.watch(partnerProvider).partners;
    final leads = ref.watch(leadProvider).leads;

    final leadsMatchingFilter = leads.where((l) {
      if (l.buyerPhone.isEmpty) return false;
      if (_selectedStageFilter != 'all' && l.stage.name != _selectedStageFilter) return false;
      return true;
    }).toList();

    final partnersWithPhone = partners.where((p) => p.phone != null && p.phone!.isNotEmpty).toList();

    int recipientCount = 0;
    if (_selectedGroup == 'leads') {
      recipientCount = _selectedIndividualIds.isEmpty ? leadsMatchingFilter.length : _selectedIndividualIds.length;
    } else if (_selectedGroup == 'partners') {
      recipientCount = _selectedIndividualIds.isEmpty ? partnersWithPhone.length : _selectedIndividualIds.length;
    } else if (_selectedGroup == 'custom') {
      recipientCount = _customNumbersController.text
          .split(RegExp(r'[\s,\n;\r]+'))
          .where((s) => s.trim().isNotEmpty)
          .length;
    }

    final metrics = SmsMetrics.calculate(_messageController.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Audience Selector
            Text('Target Audience', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildGroupChip('Leads (${leadsMatchingFilter.length})', 'leads', Icons.leaderboard_rounded),
                const SizedBox(width: 8),
                _buildGroupChip('Partners (${partnersWithPhone.length})', 'partners', Icons.handshake_rounded),
                const SizedBox(width: 8),
                _buildGroupChip('Custom Numbers', 'custom', Icons.dialpad_rounded),
              ],
            ),

            // Pipeline Stage Filter (for leads)
            if (_selectedGroup == 'leads') ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedStageFilter,
                decoration: InputDecoration(
                  labelText: 'Filter by Pipeline Stage',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Pipeline Stages')),
                  ...LeadStage.values.map((stage) {
                    return DropdownMenuItem(value: stage.name, child: Text(stage.label));
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedStageFilter = val ?? 'all';
                    _selectedIndividualIds.clear(); // Reset custom selections when filter changes
                  });
                },
              ),
            ],

            // Select Specific Leads / Partners Selector Button
            if (_selectedGroup == 'leads' || _selectedGroup == 'partners') ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  final targetList = _selectedGroup == 'leads' ? leadsMatchingFilter : partnersWithPhone;
                  _showContactSelectionModal(context, targetList);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedIndividualIds.isEmpty
                              ? 'Targeting all ${_selectedGroup == 'leads' ? 'matching leads' : 'partners'} ($recipientCount total • Tap to customize)'
                              : 'Targeting ${_selectedIndividualIds.length} specific ${_selectedGroup == 'leads' ? 'leads' : 'partners'} (Tap to edit)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],

            // Custom numbers field
            if (_selectedGroup == 'custom') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customNumbersController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Phone Numbers',
                  hintText: 'Enter phone numbers separated by commas, spaces, or newlines\ne.g. 08012345678, 09087654321',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                validator: (val) {
                  if (_selectedGroup == 'custom' && (val == null || val.trim().isEmpty)) {
                    return 'Please enter at least one phone number';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),

            // Campaign Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Campaign Title / Reference',
                hintText: 'e.g. Ember Promo Announcement, New Property Alert',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a campaign reference title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Message text field
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Message Body',
                hintText: 'Type your campaign message here... Use {{name}} to personalize.',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                alignLabelWithHint: true,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a message';
                }
                return null;
              },
            ),

            // ── Live SMS Metrics & Cost Calculator ──
            _buildSmsMetricsCard(metrics, recipientCount, smsState.walletBalance),

            const SizedBox(height: 16),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: smsState.isLoading || recipientCount == 0
                    ? null
                    : () => _handleSendBroadcast(recipientCount, partnersWithPhone, leadsMatchingFilter, metrics),
                icon: smsState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.campaign_rounded, size: 20),
                label: Text(
                  smsState.isLoading ? 'Sending Broadcast...' : 'Launch Broadcast to $recipientCount Contacts',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsMetricsCard(SmsMetrics metrics, int recipientCount, double walletBalance) {
    final pages = metrics.pages == 0 ? 1 : metrics.pages;
    final estimatedUnits = recipientCount * pages;
    final estimatedCost = estimatedUnits * 4.5;
    final hasShortage = walletBalance > 0 && walletBalance < estimatedCost;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: metrics.isUnicode ? Colors.orange.withValues(alpha: 0.4) : AppColors.border,
          width: metrics.isUnicode ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Exact Pages and Character Counts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: metrics.pages > 1 ? Colors.orange : AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    metrics.pages == 0
                        ? '0 Pages'
                        : '${metrics.pages} SMS Page${metrics.pages > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: metrics.pages > 1 ? Colors.orange[800] : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                metrics.charCount == 0
                    ? 'Max ${metrics.maxPageChars} chars/page'
                    : '${metrics.charCount} chars (${metrics.charsRemainingInPage} left on page ${metrics.pages})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: metrics.charsRemainingInPage <= 15 ? Colors.redAccent : AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Encoding Badges & Tag Guidance
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: metrics.isUnicode ? Colors.orange.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: metrics.isUnicode ? Colors.orange.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      metrics.isUnicode ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                      size: 13,
                      color: metrics.isUnicode ? Colors.orange[800] : Colors.green[800],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      metrics.isUnicode ? 'Unicode UCS-2 (70 chars/page)' : 'Standard GSM-7 (160 chars/page)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: metrics.isUnicode ? Colors.orange[800] : Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),

              if (metrics.hasNairaReplaced)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    '₦ auto-optimized to N (saves 60% fee)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Tag: Use {{name}} to personalize',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),

          if (metrics.isUnicode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber[900]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Emojis or special symbols force 70 chars per page. Removing emojis reduces page count and lowers broadcast cost by over 50%.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[900], height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Row 3: Live Cost Calculator & Wallet Status
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Broadcast Cost', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '$recipientCount contacts × $pages page${pages > 1 ? 's' : ''} = $estimatedUnits units (≈ ₦${estimatedCost.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasShortage ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasShortage ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasShortage ? Icons.warning_rounded : Icons.account_balance_wallet_rounded,
                        size: 13,
                        color: hasShortage ? Colors.red[800] : Colors.green[800],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasShortage
                            ? 'Short by ₦${(estimatedCost - walletBalance).toStringAsFixed(2)}'
                            : 'Balance: ₦${walletBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasShortage ? Colors.red[800] : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChip(String label, String value, IconData icon) {
    final isSelected = _selectedGroup == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGroup = value;
            _selectedStageFilter = 'all';
            _selectedIndividualIds.clear();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.accent : AppColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendBroadcast(
    int count,
    List<Profile> partnersWithPhone,
    List<Lead> leadsMatchingFilter,
    SmsMetrics metrics,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final smsState = ref.read(smsCampaignProvider);
    final pages = metrics.pages == 0 ? 1 : metrics.pages;
    final estimatedUnits = count * pages;
    final estimatedCost = estimatedUnits * 4.5; // ~N4.50 per unit on corporate route

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm SMS Broadcast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ready to broadcast to $count contacts in the "$_selectedGroup" group?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _confirmRow('Recipients', '$count contacts'),
                  _confirmRow('Pages per Recipient', '$pages SMS page${pages > 1 ? 's' : ''}'),
                  _confirmRow('Total Units Required', '$estimatedUnits units'),
                  _confirmRow('Estimated Cost', '≈ ₦${estimatedCost.toStringAsFixed(2)}'),
                  _confirmRow('Wallet Balance', '₦${smsState.walletBalance.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Launch Broadcast'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Pre-flight balance check
    if (smsState.walletBalance > 0 && smsState.walletBalance < estimatedCost) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Low Wallet Balance'),
            ],
          ),
          content: Text(
            'Your SmartSMS wallet balance is ₦${smsState.walletBalance.toStringAsFixed(2)}, but sending to $count contacts ($pages page${pages > 1 ? 's' : ''} each = $estimatedUnits units) will cost approx ₦${estimatedCost.toStringAsFixed(2)}.\n\nSmartSMS will reject the broadcast if the balance is too low.\n\nWould you like to try sending anyway, or top up first?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Top Up Wallet First', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Send Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    String normalizePhone(String raw) {
      String digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('0') && digits.length == 11) {
        return '234${digits.substring(1)}';
      } else if (digits.length == 10 && RegExp(r'^[789]').hasMatch(digits)) {
        return '234$digits';
      } else if (digits.startsWith('234') && digits.length == 13) {
        return digits;
      }
      return '';
    }

    final List<({String? name, String phone, String? type})> recipients = [];

    if (_selectedGroup == 'leads') {
      final targets = _selectedIndividualIds.isEmpty
          ? leadsMatchingFilter
          : leadsMatchingFilter.where((l) => _selectedIndividualIds.contains(l.id)).toList();
      for (final lead in targets) {
        final normalized = normalizePhone(lead.buyerPhone);
        if (normalized.isNotEmpty) {
          recipients.add((
            name: lead.buyerName,
            phone: normalized,
            type: 'lead',
          ));
        }
      }
    } else if (_selectedGroup == 'partners') {
      final targets = _selectedIndividualIds.isEmpty
          ? partnersWithPhone
          : partnersWithPhone.where((p) => _selectedIndividualIds.contains(p.id)).toList();
      for (final p in targets) {
        final normalized = normalizePhone(p.phone ?? "");
        if (normalized.isNotEmpty) {
          recipients.add((
            name: p.fullName,
            phone: normalized,
            type: 'partner',
          ));
        }
      }
    } else if (_selectedGroup == 'custom') {
      final customNumbers = _customNumbersController.text
          .split(RegExp(r'[\s,\n;\r]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final rawNum in customNumbers) {
        String digits = rawNum.replaceAll(RegExp(r'\D'), '');
        if (digits.startsWith('0') && digits.length == 11) {
          digits = '234${digits.substring(1)}';
        } else if (digits.length == 10 && RegExp(r'^[789]').hasMatch(digits)) {
          digits = '234$digits';
        }

        if (digits.length >= 10 && digits.length <= 15) {
          recipients.add((
            name: 'Custom Recipient ($digits)',
            phone: digits,
            type: 'custom',
          ));
        }
      }
    }

    final ok = await ref.read(smsCampaignProvider.notifier).sendCampaign(
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          recipients: recipients,
        );

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Broadcast launched successfully! Check Campaign History tab for logs.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
        _titleController.clear();
        _messageController.clear();
        _customNumbersController.clear();
        _selectedIndividualIds.clear();
        _tabController.animateTo(1); // switch to history tab
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to send broadcast: ${ref.read(smsCampaignProvider).errorMessage ?? "Check SmartSMS balance or Sender ID"}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  /// Interactive Recipient Selection Modal with fully working Select All & Deselect All
  void _showContactSelectionModal(BuildContext context, List<dynamic> contacts) {
    // If _selectedIndividualIds is empty, all contacts are targeted by default
    final Set<String> selectedIds = Set<String>.from(
      _selectedIndividualIds.isEmpty
          ? contacts.map((c) => c.id as String)
          : _selectedIndividualIds,
    );
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);

            final filtered = contacts.where((c) {
              final name = (c is Lead ? c.buyerName : (c as Profile).fullName ?? 'Unnamed').toLowerCase();
              final phone = (c is Lead ? c.buyerPhone : (c as Profile).phone ?? '').toLowerCase();
              return name.contains(searchQuery) || phone.contains(searchQuery);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Recipients',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${selectedIds.length} of ${contacts.length} selected',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setModalState(() {
                                      selectedIds.addAll(filtered.map((c) => c.id as String));
                                    });
                                  },
                                  child: const Text('Select All', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: () {
                                    setModalState(() {
                                      for (final c in filtered) {
                                        selectedIds.remove(c.id as String);
                                      }
                                    });
                                  },
                                  child: const Text('Deselect All', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val.trim().toLowerCase();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No contacts found matching search', style: TextStyle(color: AppColors.textSecondary)))
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final contact = filtered[index];
                                  final id = contact.id as String;
                                  final name = contact is Lead ? contact.buyerName : (contact as Profile).fullName ?? 'Unnamed';
                                  final phone = contact is Lead ? contact.buyerPhone : (contact as Profile).phone ?? 'No phone';

                                  final isChecked = selectedIds.contains(id);

                                  return CheckboxListTile(
                                    value: isChecked,
                                    activeColor: AppColors.accent,
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          selectedIds.add(id);
                                        } else {
                                          selectedIds.remove(id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedIds.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select at least 1 recipient.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                if (selectedIds.length == contacts.length) {
                                  _selectedIndividualIds.clear(); // Empty means all selected
                                } else {
                                  _selectedIndividualIds.clear();
                                  _selectedIndividualIds.addAll(selectedIds);
                                }
                              });
                              Navigator.pop(modalCtx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Confirm (${selectedIds.length} Selected)'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(SmsCampaignState smsState) {
    if (smsState.isLoading && smsState.campaigns.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: ShimmerList(),
      );
    }

    if (smsState.campaigns.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: 'No campaigns found',
        description: 'Send your first bulk broadcast using the Compose tab.',
        actionLabel: 'Refresh',
        onActionPressed: () => ref.read(smsCampaignProvider.notifier).loadSmsCampaigns(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: smsState.campaigns.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final campaign = smsState.campaigns[index];
        final formattedDate = DateFormat('MMM d, yyyy @ h:mm a').format(campaign.createdAt);

        return Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: ExpansionTile(
            title: Text(
              campaign.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Sent: $formattedDate',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              child: const Icon(Icons.sms_outlined, color: AppColors.accent, size: 20),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip('Recipients: ${campaign.totalRecipients}', Colors.blue),
                  _buildStatusChip('Delivered: ${campaign.deliveredCount}', Colors.green),
                  _buildStatusChip('Failed: ${campaign.failedCount}', Colors.red),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Message Body:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  campaign.message,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons to Inspect Recipients & Failed Contacts
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCampaignDeliveryDetails(context, campaign),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: Text('View Recipient Log (${campaign.totalRecipients})'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (campaign.failedCount > 0) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCampaignDeliveryDetails(context, campaign, initialFilter: 'failed'),
                      icon: const Icon(Icons.error_outline_rounded, size: 16),
                      label: Text('Failed (${campaign.failedCount})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        foregroundColor: Colors.red[800],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Modal sheet showing exact contacts that received or failed to receive SMS
  void _showCampaignDeliveryDetails(BuildContext context, SmsCampaign campaign, {String initialFilter = 'all'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = initialFilter; // 'all', 'delivered', 'failed'
        String query = '';

        return StatefulBuilder(
          builder: (context, setDetailsState) {
            final theme = Theme.of(context);
            final formattedDate = DateFormat('MMM d, yyyy @ h:mm a').format(campaign.createdAt);

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: FutureBuilder<List<SmsMessageLog>>(
                    future: ref.read(smsCampaignProvider.notifier).getCampaignMessages(campaign.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final allLogs = snapshot.data ?? [];
                      final deliveredLogs = allLogs.where((m) => m.status.toLowerCase() == 'delivered').toList();
                      final failedLogs = allLogs.where((m) => m.status.toLowerCase() == 'failed').toList();

                      final activeLogs = (filter == 'delivered'
                              ? deliveredLogs
                              : (filter == 'failed' ? failedLogs : allLogs))
                          .where((m) {
                        if (query.isEmpty) return true;
                        final name = (m.recipientName ?? '').toLowerCase();
                        final phone = m.recipientPhone.toLowerCase();
                        return name.contains(query) || phone.contains(query);
                      }).toList();

                      return Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        campaign.title,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Sent: $formattedDate • Sender ID: ${campaign.senderId}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 12),

                                // Summary Stats row
                                Row(
                                  children: [
                                    _buildDeliveryStatChip('Total: ${allLogs.isEmpty ? campaign.totalRecipients : allLogs.length}', Colors.blue),
                                    const SizedBox(width: 8),
                                    _buildDeliveryStatChip('Delivered: ${deliveredLogs.length}', Colors.green),
                                    const SizedBox(width: 8),
                                    _buildDeliveryStatChip('Failed: ${failedLogs.length}', Colors.red),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Filter Segmented Buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                _buildFilterButton('All (${allLogs.length})', filter == 'all', () {
                                  setDetailsState(() => filter = 'all');
                                }),
                                const SizedBox(width: 8),
                                _buildFilterButton('Delivered (${deliveredLogs.length})', filter == 'delivered', () {
                                  setDetailsState(() => filter = 'delivered');
                                }),
                                const SizedBox(width: 8),
                                _buildFilterButton('Failed (${failedLogs.length})', filter == 'failed', () {
                                  setDetailsState(() => filter = 'failed');
                                }),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Search Box
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search recipients by name or phone...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                              ),
                              onChanged: (val) {
                                setDetailsState(() => query = val.trim().toLowerCase());
                              },
                            ),
                          ),

                          // Action Buttons if failed contacts exist
                          if (failedLogs.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        final phones = failedLogs.map((m) => m.recipientPhone).join(', ');
                                        Clipboard.setData(ClipboardData(text: phones));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Copied ${failedLogs.length} failed phone numbers to clipboard!'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      label: Text('Copy ${failedLogs.length} Failed Numbers'),
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      final phones = failedLogs.map((m) => m.recipientPhone).join(', ');
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _selectedGroup = 'custom';
                                        _customNumbersController.text = phones;
                                        _titleController.text = 'Retry: ${campaign.title}';
                                        _messageController.text = campaign.message;
                                      });
                                      _tabController.animateTo(0);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Loaded ${failedLogs.length} failed contacts into Compose tab. Check balance and tap Launch Broadcast.'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: AppColors.accent,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    ),
                                    icon: const Icon(Icons.replay_rounded, size: 16),
                                    label: const Text('Resend to Failed'),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Recipient List
                          Expanded(
                            child: activeLogs.isEmpty
                                ? Center(
                                    child: Text(
                                      allLogs.isEmpty
                                          ? 'No individual recipient logs recorded for this campaign.'
                                          : 'No recipients match current filter.',
                                      style: const TextStyle(color: AppColors.textSecondary),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    itemCount: activeLogs.length,
                                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                    itemBuilder: (ctx, i) {
                                      final item = activeLogs[i];
                                      final isDelivered = item.status.toLowerCase() == 'delivered';

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDelivered ? AppColors.border : Colors.red.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: isDelivered
                                                      ? Colors.green.withValues(alpha: 0.1)
                                                      : Colors.red.withValues(alpha: 0.1),
                                                  child: Icon(
                                                    isDelivered ? Icons.check_rounded : Icons.close_rounded,
                                                    color: isDelivered ? Colors.green : Colors.red,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              item.recipientName ?? 'Contact',
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (item.recipientType != null) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.surfaceVariant,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                item.recipientType!.toUpperCase(),
                                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        item.recipientPhone,
                                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isDelivered ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isDelivered ? 'Delivered' : 'Failed',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDelivered ? Colors.green[800] : Colors.red[800],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (!isDelivered && item.errorMessage != null && item.errorMessage!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.info_outline, size: 14, color: Colors.red),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Reason: ${item.errorMessage}',
                                                        style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
