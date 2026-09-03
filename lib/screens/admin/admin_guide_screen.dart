import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';

class AdminGuideScreen extends StatefulWidget {
  const AdminGuideScreen({super.key});

  @override
  State<AdminGuideScreen> createState() => _AdminGuideScreenState();
}

class _AdminGuideScreenState extends State<AdminGuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Quick Start',
    'Properties',
    'Leads & Sales',
    'Attendance & GPS',
    'Site Inspections',
    'Installments & Cashflow',
    'Receipts & Letters',
    'Staff & Partners',
    'Reports & KPIs',
    'Bulk SMS & Email',
    'Nissie Academy',
  ];

  late final List<GuideSection> _sections;

  @override
  void initState() {
    super.initState();
    _sections = _buildGuideSections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final filteredSections = _sections.where((section) {
      final matchesCategory = _selectedCategory == 'All' || section.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          section.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          section.summary.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          section.items.any((item) =>
              item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.content.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Admin Operating Manual & Guide',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print / Save Guide',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Use your browser print shortcut (Ctrl+P / Cmd+P) to save this manual as PDF.'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Banner ──
                _buildHeroHeader(theme),
                const SizedBox(height: 24),

                // ── Search & Filter Row ──
                _buildSearchAndFilter(),
                const SizedBox(height: 20),

                // ── Category Pills ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedCategory = cat);
                          },
                          selectedColor: AppColors.accent.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.accent : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Guide Content Sections ──
                if (filteredSections.isEmpty)
                  _buildNoResults()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredSections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (ctx, idx) => _buildSectionCard(filteredSections[idx]),
                  ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 14, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text(
                      'CONFIDENTIAL & ADMIN ACCESS ONLY',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Nissie Ideal Shelters Operating Manual',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The comprehensive reference guide for agency leadership. Explains every feature, anti-cheat control, cashflow recovery tool, and daily management workflow.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search guide (e.g., properties, sms, termii, academy, geofence, receipt, whatsapp)...',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(GuideSection section) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _searchQuery.isNotEmpty || section.initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: section.badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: section.badgeColor, size: 22),
          ),
          title: Text(
            section.title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              section.summary,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          children: [
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            ...section.items.map((item) => _buildGuideItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(GuideItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.tag != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (item.tagColor ?? AppColors.accent).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.tag!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.tagColor ?? AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (item.steps != null && item.steps!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Step-by-Step Procedure:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  ...item.steps!.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 2, right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$index',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          if (item.tip != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Executive Tip: ${item.tip}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.4),
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

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No guide entries found matching "$_searchQuery" in category "$_selectedCategory"',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try selecting "All" categories or searching for another keyword like "properties", "sms", "attendance", "installments", or "receipt".',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<GuideSection> _buildGuideSections() {
    return [
      // ── 1. QUICK START ──
      GuideSection(
        title: '1. Quick Start & Executive System Overview',
        summary: 'How user roles, access hierarchy, and core navigation operate.',
        category: 'Quick Start',
        icon: Icons.rocket_launch_rounded,
        badgeColor: AppColors.accent,
        initiallyExpanded: true,
        items: [
          const GuideItem(
            title: 'Role Hierarchy & Access Levels',
            tag: 'CORE ARCHITECTURE',
            content:
                'Nissie Ideal Shelters is architected into 5 distinct permission levels to ensure staff only see what they need to see:\n\n'
                '• Administrator (MD/CEO): Unrestricted access to financial ledgers, staff attendance, commission payouts, billing, office geofence settings, company documents, and system guides.\n'
                '• Manager: Operational supervision over team marketers, lead assignment, and inspection approvals.\n'
                '• Marketer (Internal Staff): Dedicated to lead follow-ups, logging tasks, clocking in with GPS, and completing site inspections.\n'
                '• Partner (External Realtor / Affiliate): Dedicated portal showing available property inventory, their custom referral link, inspection bookings, and commission wallet.\n'
                '• Buyer / Investor: Client portal to view property subscriptions, plot allocations, and payment receipts.',
            tip: 'Only Administrators have access to this System Guide and Company Geofence settings.',
          ),
          GuideItem(
            title: 'Navigating the Admin Dashboard',
            tag: 'NAVIGATION',
            content: 'The Admin Dashboard gives real-time visibility over the 4 vital organs of the agency:',
            steps: [
              'Leads Pipeline & Conversion Rate: Tracks count of prospects in each stage from New to Closed.',
              'Active Properties: Inventory count of estates, active listings, and sold plots.',
              'Staff Attendance Summary: Live count of who is present, who arrived on time (before 8:30 AM), and who is absent.',
              'Quick Action Drawer: Tap the top-left menu icon (☰) to access Installments, Inspections, Staff Management, and Daily Reports.',
            ],
          ),
        ],
      ),

      // ── 2. PROPERTIES & INVENTORY ──
      GuideSection(
        title: '2. Properties & Estate Inventory Management',
        summary: 'Adding land & building listings, uploading photos, generating PDF brochures, and tracking plots.',
        category: 'Properties',
        icon: Icons.domain_rounded,
        badgeColor: const Color(0xFF3B82F6),
        items: [
          GuideItem(
            title: 'Adding an Estate or Property Listing',
            tag: 'INVENTORY',
            content: 'To publish a new estate or property for marketing and sales:',
            steps: [
              'Go to Drawer Menu (☰) ➔ Properties (/admin/properties) or tap Properties in bottom navigation.',
              'Click the "+ Add Property" button at the top right.',
              'Fill in the Estate Title, Location, State/City, and Detailed Description.',
              'Select Property Category: Land / Residential / Commercial.',
              'Enter Price (₦), Available Plots, and Plot Sizes (e.g. 300 SQM, 500 SQM, 1,000 SQM).',
              'Specify Title Documents (C of O, Right of Occupancy, Governor\'s Consent, Excision, Gazette).',
              'Upload estate layout plan, flyers, and on-site photos.',
              'Click "Publish Property" to make it instantly visible to all marketers and affiliate realtors.',
            ],
            tip: 'Setting accurate GPS coordinates for the estate allows the system to verify staff site inspections automatically.',
          ),
          GuideItem(
            title: '1-Click Branded PDF Property Brochure Generator',
            tag: 'SALES TOOL',
            content:
                'Every property listing comes with a built-in, automated PDF Brochure Generator:\n\n'
                '• On any property detail page, click "Generate Brochure PDF".\n'
                '• The system instantly compiles a high-resolution, multi-page branded brochure featuring your company logo, estate pictures, title details, payment plan terms, and agency contact numbers.\n'
                '• Marketers can share this PDF directly with high-net-worth prospects and diaspora investors on WhatsApp.',
            tip: 'Brochures include a scan-to-verify QR code that links directly to the estate\'s online video walkthrough.',
          ),
          GuideItem(
            title: 'Plot Inventory & Sold Status Tracking',
            tag: 'ALLOCATION',
            content:
                '• Each estate allows setting the Total Plots Available.\n'
                '• When deals are closed and plot numbers are allocated in Installments & Recovery, the available plot counter automatically updates.\n'
                '• Prevents double allocation of the same plot to two different buyers.',
          ),
        ],
      ),

      // ── 3. LEADS & PIPELINE ──
      GuideSection(
        title: '3. Leads Pipeline & Sales Conversion',
        summary: 'How to manage leads, prevent lead stealing, and track conversions.',
        category: 'Leads & Sales',
        icon: Icons.trending_up_rounded,
        badgeColor: AppColors.accent,
        items: [
          GuideItem(
            title: '6 Stages of the Lead Pipeline',
            tag: 'SALES PROCESS',
            content:
                'Every prospective buyer moves through 6 standardized stages:\n\n'
                '1. New: Fresh lead from landing page, Facebook, or manual entry.\n'
                '2. Contacted: Agent has called or messaged the prospect on WhatsApp.\n'
                '3. Inspection Booked: Date and time scheduled for on-site visit.\n'
                '4. Negotiation: Client has inspected and is discussing plot price or payment plan.\n'
                '5. Closed: Down payment made, contract/subscription created.\n'
                '6. Lost: Prospect declined, bought elsewhere, or budget mismatch.',
          ),
          GuideItem(
            title: 'Importing & Exporting Leads (CSV / Excel)',
            tag: 'DATA',
            content:
                '• Under /admin/leads, click "Import Leads" to bulk-upload leads from Facebook Ads or phone databases.\n'
                '• Click "Export Leads" to download your full client contact database into CSV/Excel for executive analysis or SMS campaigns.',
          ),
          GuideItem(
            title: 'Preventing Lead Theft (Off-Portal Deals)',
            tag: 'POLICY',
            content:
                '• Every lead assigned to an agent is timestamped.\n'
                '• If an agent does not log an activity update within 4 hours, management can reassign the lead to another marketer.\n'
                '• All communication notes are stored centrally on the client\'s timeline.',
          ),
        ],
      ),

      // ── 4. ATTENDANCE & GEOFENCE ──
      GuideSection(
        title: '4. Staff Attendance & GPS Geofence Anti-Cheat',
        summary: 'How physical office presence, 8:30 AM cutoff, and anti-cheat work.',
        category: 'Attendance & GPS',
        icon: Icons.location_on_rounded,
        badgeColor: const Color(0xFF10B981),
        items: [
          GuideItem(
            title: 'The Strict 300-Meter Office Geofence',
            tag: 'ANTI-CHEAT',
            tagColor: const Color(0xFFEF4444),
            content:
                'To prevent staff from clocking in from their beds or en route to work, the system enforces a strict physical GPS perimeter around the company office (Suite 2, Shema complex, Asokoro extension, Abuja):\n\n'
                '• When a marketer taps "Clock In for In-Office Duty", the device browser queries the exact satellite GPS coordinates.\n'
                '• The Haversine formula computes the physical distance between the employee and the office.\n'
                '• If the distance is greater than 300 meters, clock-in is BLOCKED immediately with a popup showing how far away they are.',
            tip: 'The 300-meter radius allows comfortable coverage throughout the entire Shema filling station complex and parking area.',
          ),
          GuideItem(
            title: 'Two-Layer Security (Browser + Database Level)',
            tag: 'SECURITY',
            content:
                'Even if an employee tries to bypass frontend checks, use an outdated browser, or use developer tools:\n\n'
                '• Layer 1 (Browser App): Requests HTML5 GPS coordinates and validates physical radius before allowing the button click.\n'
                '• Layer 2 (Supabase PostgreSQL Trigger): The database itself validates coordinates upon receipt. Any clock-in record with missing GPS or coordinates > 300m is REJECTED with a database exception.',
          ),
          GuideItem(
            title: '8:30 AM WAT Punctuality Cutoff',
            tag: 'PUNCTUALITY',
            content:
                '• Official morning start cutoff is 08:30:00 AM West Africa Time (Africa/Lagos).\n'
                '• Any staff clocking in at 08:30:01 AM or later is automatically flagged as "LATE" (badge turns orange).\n'
                '• Attendance reports automatically calculate the percentage of on-time vs late arrivals for monthly performance reviews.',
          ),
          GuideItem(
            title: 'How Staff Allow Browser Location Access',
            tag: 'TROUBLESHOOTING',
            content: 'If a staff member complains that location is not working on their phone or laptop:',
            steps: [
              'Tap the lock icon (🔒) or site settings icon next to the URL in Chrome/Safari address bar.',
              'Find "Location" / "Permissions" and toggle it to "Allow".',
              'Ensure the phone\'s main device GPS / Location toggle is turned ON.',
              'Refresh the page and tap Clock In again.',
            ],
            tip: 'If staff refuse or block location permission, clock-in is 100% blocked. They cannot start their shift.',
          ),
        ],
      ),

      // ── 5. SITE INSPECTIONS ──
      GuideSection(
        title: '5. Anti-Cheat Geotagged Site Inspections',
        summary: 'How to verify staff actually took clients to the estate before paying transport claims.',
        category: 'Site Inspections',
        icon: Icons.camera_alt_rounded,
        badgeColor: const Color(0xFF06B6D4),
        items: [
          GuideItem(
            title: 'The Problem with Site Inspections in Nigeria',
            tag: 'MONEY SAVER',
            content:
                'Field marketers frequently request transport or fuel allowance to take prospects on inspections. Without verification, there is no proof the client actually attended or that the agent visited your estate rather than a competitor\'s.',
          ),
          GuideItem(
            title: 'How Geotagged Verification Works',
            tag: 'VERIFICATION',
            content:
                'When an inspection is marked as "Completed" on the portal (/admin/inspections):\n\n'
                '1. The agent must upload or snap an on-site photo with the client at the estate banner/plot.\n'
                '2. The agent taps "Capture Live Estate GPS Coordinates".\n'
                '3. The agent enters client remarks and feedback.\n'
                '4. Management immediately sees the green "VERIFIED ON-SITE INSPECTION" badge with exact GPS coordinates and client notes.',
            tip: 'Management should establish a policy: No Geotagged Photo + GPS = No transport reimbursement and no closing commission.',
          ),
        ],
      ),

      // ── 6. INSTALLMENTS & CASHFLOW ──
      GuideSection(
        title: '6. Installment Payment & Cashflow Recovery Engine',
        summary: 'Automating buyer payment plans, monthly milestones, and WhatsApp reminders.',
        category: 'Installments & Cashflow',
        icon: Icons.payments_rounded,
        badgeColor: const Color(0xFFF59E0B),
        items: [
          GuideItem(
            title: 'Why the Installment Engine Was Built',
            tag: 'CASHFLOW',
            content:
                'Over 80% of real estate buyers in Nigeria purchase land on installment (3, 6, 12, or 24 months). Previously, receivables were tracked on manual paper or Excel spreadsheets, leading to missed due dates and delayed cashflow.\n\n'
                'The Installments & Recovery module (/admin/installments) gives you an automated ledger of all active buyer payment schedules.',
          ),
          GuideItem(
            title: 'Creating a New Buyer Installment Plan',
            tag: 'PROCEDURE',
            content: 'When a buyer closes a deal with an initial deposit:',
            steps: [
              'Go to Drawer Menu (☰) ➔ Installments & Recovery.',
              'Click the "+ New Installment Plan" floating button.',
              'Enter Buyer Full Name, Phone Number, and select the Estate Property.',
              'Enter Total Price (e.g. ₦15,000,000) and Initial Deposit (e.g. ₦3,000,000).',
              'Select Duration (3, 6, 12, or 24 Months) and click "Create Plan".',
              'The system automatically calculates equal monthly milestones and schedules due dates 30 days apart.',
            ],
            tip: 'A progress bar immediately visualizes how much of the property has been paid to date.',
          ),
          GuideItem(
            title: '1-Tap WhatsApp Due Date Reminders',
            tag: 'ZERO COST',
            tagColor: const Color(0xFF10B981),
            content:
                '• Tap on any buyer\'s installment card to expand it.\n'
                '• Click the green "WhatsApp Reminder" button.\n'
                '• It automatically launches WhatsApp with the buyer\'s phone number and a pre-formatted polite reminder stating the milestone number, amount due, and bank details.\n'
                '• Zero setup, zero monthly fees, and 100% free.',
          ),
          GuideItem(
            title: 'Logging a Milestone Payment',
            tag: 'ACCOUNTING',
            content: 'When a buyer\'s monthly payment reflects in the bank account:',
            steps: [
              'Expand the buyer\'s card in Installments & Recovery.',
              'Find the pending milestone and tap "Log Payment".',
              'Enter the Amount Paid, Receipt/Teller Number, and Payment Method (Bank Transfer, POS, Cheque).',
              'Click "Confirm Payment".',
              'The milestone instantly turns green (PAID), the balance is updated, and the official receipt button appears.',
            ],
          ),
        ],
      ),

      // ── 7. RECEIPTS & LETTERS ──
      GuideSection(
        title: '7. Official Branded PDF Receipts & Allocation Letters',
        summary: 'Instant generation of professional documents with amount in words and QR codes.',
        category: 'Receipts & Letters',
        icon: Icons.receipt_long_rounded,
        badgeColor: const Color(0xFF8B5CF6),
        items: [
          GuideItem(
            title: '1-Click Official Payment Receipt Generator',
            tag: 'BRANDING',
            content:
                'Rather than designing manual receipts in Word or CorelDraw, you can generate an official branded PDF in 1 second:\n\n'
                '• Go to Installments & Recovery ➔ Expand any buyer card.\n'
                '• Click the receipt icon (🧾) next to any paid milestone.\n'
                '• Features included on the receipt:\n'
                '  - Official Nissie Ideal Shelters header & logo\n'
                '  - Unique Receipt Number (e.g. NIS/REC/2026/0042)\n'
                '  - Amount in Figures AND English Words (e.g. "One Million, Five Hundred Thousand Naira Only")\n'
                '  - Total Property Price, Total Paid to Date, and Outstanding Balance\n'
                '  - Encrypted QR Code for authentication\n'
                '  - Authorized signature and stamp line',
          ),
          GuideItem(
            title: 'Provisional Plot Allocation Letter',
            tag: 'LEGAL',
            content:
                '• Tap "Allocation Letter" on the buyer\'s card.\n'
                '• Generates a formal Letter of Provisional Allocation on company letterhead.\n'
                '• Outlines plot specifications, estate name, payment terms, building guidelines, and MD signature line.\n'
                '• Instant confidence builder for Diaspora and local investors.',
          ),
        ],
      ),

      // ── 8. STAFF & PARTNERS ──
      GuideSection(
        title: '8. Staff Management & Partner Network',
        summary: 'Managing internal team marketers, onboarding external affiliate realtors, and paying commissions.',
        category: 'Staff & Partners',
        icon: Icons.people_alt_rounded,
        badgeColor: const Color(0xFF6366F1),
        items: [
          GuideItem(
            title: 'Inviting & Onboarding Staff Members',
            tag: 'STAFF',
            content: 'To add new employees to your agency portal:',
            steps: [
              'Go to Drawer Menu (☰) ➔ Staff Management (/admin/staff).',
              'Click "Invite Staff" or go to /admin/invite-staff.',
              'Enter their Full Name, Email Address, and select their Role (Manager or Marketer).',
              'Staff receives an invitation link to set their password and log in.',
              'Once registered, they appear under Staff Management with real-time tracking.',
            ],
            tip: 'Marketers only see their assigned leads and their own attendance.',
          ),
          GuideItem(
            title: 'Reviewing Staff Timesheets & Daily Accomplishments',
            tag: 'OVERSIGHT',
            content:
                '• Under Staff Management, clicking on any staff card opens their full 30-Day Attendance Timesheet.\n'
                '• Displays exact clock-in time, punctuality badge (On-Time vs Late), clock-out time, and total working minutes.\n'
                '• When staff clock out, they must submit their "Daily Accomplishments Report" (e.g. calls made, inspections attended), which management can review anytime.',
          ),
          GuideItem(
            title: 'Partner / Realtor Affiliate Network',
            tag: 'PARTNERS',
            content:
                'External realtors and affiliate marketers register on the Partner portal:\n\n'
                '• Each partner receives a unique referral code/link for each estate.\n'
                '• When their clients click the link and register or book an inspection, the lead is automatically linked to that partner.\n'
                '• When the sale closes, commission is credited to the partner\'s wallet automatically.',
          ),
          GuideItem(
            title: 'Commission Approvals & Payout Withdrawals',
            tag: 'FINANCE',
            content:
                '• Under /admin/commissions: Review all earned commissions and approve or reject pending payouts.\n'
                '• Under /admin/withdrawals: View partner bank account details (Bank Name, Account Number, Account Name) for requested withdrawals. Once bank transfer is made, mark as "Completed".',
          ),
        ],
      ),

      // ── 9. REPORTS & KPIS ──
      GuideSection(
        title: '9. Automated Daily, Weekly & Monthly Reports',
        summary: 'How executive performance reports are compiled and exported to PDF.',
        category: 'Reports & KPIs',
        icon: Icons.summarize_rounded,
        badgeColor: const Color(0xFF10B981),
        items: [
          GuideItem(
            title: 'Client-Side Aggregated Reports',
            tag: 'AUTOMATION',
            content:
                'Under Drawer Menu ➔ Daily Reports (/admin/reports):\n\n'
                '• Automatically aggregates all leads captured, follow-ups conducted, site visits completed, and deals closed for any selected date.\n'
                '• Weekly & Monthly tabs compile rolling totals for board presentations.\n'
                '• Generates an executive PDF report ready to print or email with 1 click.',
          ),
        ],
      ),

      // ── 10. BULK SMS & EMAIL ──
      GuideSection(
        title: '10. Bulk SMS (Termii) & Bulk Email Messaging',
        summary: 'Direct broadcast campaigns via Termii API and investor email updates.',
        category: 'Bulk SMS & Email',
        icon: Icons.sms_rounded,
        badgeColor: const Color(0xFFEC4899),
        items: [
          GuideItem(
            title: 'Bulk SMS Portal via Termii Integration',
            tag: 'TERMII SMS',
            content:
                'Your portal is integrated with Termii for high-deliverability SMS broadcasting across all Nigerian networks (MTN, Airtel, Glo, 9mobile):\n\n'
                '• Go to Drawer Menu (☰) ➔ Bulk SMS Portal (/admin/sms-portal).\n'
                '• View your Live Wallet Balance in real-time Naira.\n'
                '• Sender ID: Messages are delivered with your official company brand name (e.g. "NISSIE").\n'
                '• Auto-Phone Formatter: Automatically converts numbers like 0803... to international format +234803... so messages never fail.',
            steps: [
              'Select recipient audience: All Leads, Site Inspection Clients, Active Buyers, or Custom Numbers.',
              'Type your promotional or alert message.',
              'Click "Send Bulk SMS". Delivery reports log sent, delivered, and failed counts in real-time.',
            ],
            tip: 'SMS open rates in Nigeria exceed 90%. Use this to announce estate price increments or inspection batches.',
          ),
          GuideItem(
            title: 'Bulk Email & Investor Newsletters',
            tag: 'EMAIL',
            content:
                'Under Drawer Menu (☰) ➔ Bulk Email Portal (/admin/email-portal):\n\n'
                '• Send rich email broadcasts to corporate clients, diaspora investors, and registered buyers.\n'
                '• Ideal for sending formal documentation updates, physical plot allocation dates, and quarterly estate infrastructure progress photos.',
          ),
        ],
      ),

      // ── 11. NISSIE ACADEMY ──
      GuideSection(
        title: '11. Nissie Academy & Sales Training',
        summary: 'Training materials, closing scripts, objection handling simulator, and staff certification.',
        category: 'Nissie Academy',
        icon: Icons.school_rounded,
        badgeColor: const Color(0xFF8B5CF6),
        items: [
          GuideItem(
            title: 'Academy Materials & Real Estate Closing Playbooks',
            tag: 'TRAINING',
            content:
                'Under Drawer Menu (☰) ➔ Nissie Academy (/training):\n\n'
                '• Houses your agency\'s sales playbooks, video guides, and closing scripts.\n'
                '• Examples of topics:\n'
                '  - "How to close ₦30M+ land deals in Abuja and Lagos"\n'
                '  - "Explaining Land Titles to Buyers (C of O vs R of O vs Gazette)"\n'
                '  - "How to follow up on cold leads without sounding desperate"',
          ),
          GuideItem(
            title: 'Interactive Sales Simulator',
            tag: 'SIMULATOR',
            content:
                'The built-in Simulator (/training) lets marketers practice handling tough client objections before talking to real prospects:\n\n'
                '• Marketers choose how to respond to real scenarios (e.g., *"Why is this estate more expensive than the one next to it?", "Can I build immediately?"*).\n'
                '• Scores their responses and teaches them the psychological triggers to win buyer trust.',
          ),
          GuideItem(
            title: 'Staff Exams & Leaderboard Ranking',
            tag: 'CERTIFICATION',
            content:
                '• Agency exams test staff on property prices, location advantages, and company policies.\n'
                '• Leaderboard awards points for completed trainings, encouraging positive competition among your marketing team.',
          ),
        ],
      ),

      // ── 12. COMPANY SETTINGS ──
      GuideSection(
        title: '12. Company Settings & Office Coordinates Setup',
        summary: 'Configuring office location for the geofence and updating company branding.',
        category: 'Attendance & GPS',
        icon: Icons.settings_suggest_rounded,
        badgeColor: const Color(0xFF64748B),
        items: [
          GuideItem(
            title: 'Updating Official Office GPS Coordinates',
            tag: 'SETUP',
            content: 'To change or fine-tune your office geofence location:',
            steps: [
              'Go to Drawer Menu (☰) ➔ Company Profile (/admin/company-profile).',
              'Scroll down to the "Office Geofence & Anti-Cheat Attendance" section.',
              'Click "📍 Capture Current Location" while physically standing in the office building.',
              'The app automatically inputs your exact latitude and longitude.',
              'Set Allowed Radius (default is 300 meters) and click "Save Changes".',
            ],
            tip: 'The database fallback coordinates are already pre-loaded to Asokoro Extension, Abuja.',
          ),
        ],
      ),
    ];
  }
}

class GuideSection {
  final String title;
  final String summary;
  final String category;
  final IconData icon;
  final Color badgeColor;
  final bool initiallyExpanded;
  final List<GuideItem> items;

  GuideSection({
    required this.title,
    required this.summary,
    required this.category,
    required this.icon,
    required this.badgeColor,
    this.initiallyExpanded = false,
    required this.items,
  });
}

class GuideItem {
  final String title;
  final String? tag;
  final Color? tagColor;
  final String content;
  final List<String>? steps;
  final String? tip;

  const GuideItem({
    required this.title,
    this.tag,
    this.tagColor,
    required this.content,
    this.steps,
    this.tip,
  });
}
