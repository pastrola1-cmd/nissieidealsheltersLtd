import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/report_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';

class DailyReportsScreen extends ConsumerStatefulWidget {
  const DailyReportsScreen({super.key});

  @override
  ConsumerState<DailyReportsScreen> createState() => _DailyReportsScreenState();
}

class _DailyReportsScreenState extends ConsumerState<DailyReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  DailyReport? _report;
  bool _isLoadingReport = false;
  String? _error;
  String _reportType = 'daily'; // 'daily', 'weekly', 'monthly'

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<DailyReport> _compileWeeklyReport() async {
    final companyId = ref.read(authProvider).profile?.companyId ?? '';
    final list = <DailyReport>[];
    
    // Fetch reports for the last 7 days (ending on _selectedDate)
    for (int i = 0; i < 7; i++) {
      final date = _selectedDate.subtract(Duration(days: i));
      final rep = await ref.read(reportProvider.notifier).fetchReportForDate(date);
      if (rep != null) {
        list.add(rep);
      }
    }

    if (list.isEmpty) {
      return DailyReport(
        id: 'weekly',
        companyId: companyId,
        reportDate: _selectedDate,
        newLeads: 0,
        followUps: 0,
        inspectionsBooked: 0,
        inspectionsCompleted: 0,
        closedDeals: 0,
        revenueToday: 0,
        topStaff: [],
        leadsByStage: {},
      );
    }

    // Aggregate
    int newLeads = 0;
    int followUps = 0;
    int inspectionsBooked = 0;
    int inspectionsCompleted = 0;
    int closedDeals = 0;
    double revenue = 0;
    
    final staffMap = <String, StaffPerformance>{};
    final stageMap = <String, int>{};

    for (final r in list) {
      newLeads += r.newLeads;
      followUps += r.followUps;
      inspectionsBooked += r.inspectionsBooked;
      inspectionsCompleted += r.inspectionsCompleted;
      closedDeals += r.closedDeals;
      revenue += r.revenueToday;

      for (final s in r.topStaff) {
        if (staffMap.containsKey(s.profileId)) {
          final prev = staffMap[s.profileId]!;
          final totalLeads = prev.leadsHandled + s.leadsHandled;
          final totalConv = prev.conversions + s.conversions;
          staffMap[s.profileId] = StaffPerformance(
            profileId: s.profileId,
            name: s.name,
            leadsHandled: totalLeads,
            conversions: totalConv,
            conversionRate: totalLeads == 0 ? 0 : (totalConv / totalLeads) * 100,
          );
        } else {
          staffMap[s.profileId] = s;
        }
      }

      r.leadsByStage.forEach((key, val) {
        stageMap[key] = (stageMap[key] ?? 0) + val;
      });
    }

    final sortedStaff = staffMap.values.toList()
      ..sort((a, b) => b.conversions.compareTo(a.conversions));

    return DailyReport(
      id: 'weekly',
      companyId: companyId,
      reportDate: _selectedDate,
      newLeads: newLeads,
      followUps: followUps,
      inspectionsBooked: inspectionsBooked,
      inspectionsCompleted: inspectionsCompleted,
      closedDeals: closedDeals,
      revenueToday: revenue,
      topStaff: sortedStaff,
      leadsByStage: stageMap,
    );
  }

  Future<DailyReport> _compileMonthlyReport() async {
    final companyId = ref.read(authProvider).profile?.companyId ?? '';
    final list = <DailyReport>[];
    
    // Fetch reports for the last 30 days (ending on _selectedDate)
    for (int i = 0; i < 30; i++) {
      final date = _selectedDate.subtract(Duration(days: i));
      final rep = await ref.read(reportProvider.notifier).fetchReportForDate(date);
      if (rep != null) {
        list.add(rep);
      }
    }

    if (list.isEmpty) {
      return DailyReport(
        id: 'monthly',
        companyId: companyId,
        reportDate: _selectedDate,
        newLeads: 0,
        followUps: 0,
        inspectionsBooked: 0,
        inspectionsCompleted: 0,
        closedDeals: 0,
        revenueToday: 0,
        topStaff: [],
        leadsByStage: {},
      );
    }

    // Aggregate
    int newLeads = 0;
    int followUps = 0;
    int inspectionsBooked = 0;
    int inspectionsCompleted = 0;
    int closedDeals = 0;
    double revenue = 0;
    
    final staffMap = <String, StaffPerformance>{};
    final stageMap = <String, int>{};

    for (final r in list) {
      newLeads += r.newLeads;
      followUps += r.followUps;
      inspectionsBooked += r.inspectionsBooked;
      inspectionsCompleted += r.inspectionsCompleted;
      closedDeals += r.closedDeals;
      revenue += r.revenueToday;

      for (final s in r.topStaff) {
        if (staffMap.containsKey(s.profileId)) {
          final prev = staffMap[s.profileId]!;
          final totalLeads = prev.leadsHandled + s.leadsHandled;
          final totalConv = prev.conversions + s.conversions;
          staffMap[s.profileId] = StaffPerformance(
            profileId: s.profileId,
            name: s.name,
            leadsHandled: totalLeads,
            conversions: totalConv,
            conversionRate: totalLeads == 0 ? 0 : (totalConv / totalLeads) * 100,
          );
        } else {
          staffMap[s.profileId] = s;
        }
      }

      r.leadsByStage.forEach((key, val) {
        stageMap[key] = (stageMap[key] ?? 0) + val;
      });
    }

    final sortedStaff = staffMap.values.toList()
      ..sort((a, b) => b.conversions.compareTo(a.conversions));

    return DailyReport(
      id: 'monthly',
      companyId: companyId,
      reportDate: _selectedDate,
      newLeads: newLeads,
      followUps: followUps,
      inspectionsBooked: inspectionsBooked,
      inspectionsCompleted: inspectionsCompleted,
      closedDeals: closedDeals,
      revenueToday: revenue,
      topStaff: sortedStaff,
      leadsByStage: stageMap,
    );
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoadingReport = true;
      _error = null;
    });

    try {
      DailyReport? report;
      if (_reportType == 'weekly') {
        report = await _compileWeeklyReport();
      } else if (_reportType == 'monthly') {
        report = await _compileMonthlyReport();
      } else {
        report = await ref.read(reportProvider.notifier).fetchReportForDate(_selectedDate);
      }
      if (mounted) {
        setState(() {
          _report = report;
          _isLoadingReport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingReport = false;
        });
      }
    }
  }

  void _changeDate(int multiplier) {
    int days = 1;
    if (_reportType == 'weekly') {
      days = 7;
    } else if (_reportType == 'monthly') {
      days = 30;
    }
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: multiplier * days));
    });
    _loadReport();
  }

  Future<void> _exportPdfReport() async {
    final report = _report;
    if (report == null) return;

    final doc = pw.Document();
    
    final formattedDate = _reportType == 'weekly'
        ? "${DateFormat('MMM d').format(_selectedDate.subtract(const Duration(days: 6)))} - ${DateFormat('yMMMMd').format(_selectedDate)}"
        : _reportType == 'monthly'
            ? "${DateFormat('MMM d').format(_selectedDate.subtract(const Duration(days: 29)))} - ${DateFormat('yMMMMd').format(_selectedDate)}"
            : DateFormat('yMMMMd').format(_selectedDate);
    
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final company = ref.read(authProvider).company;
    final companyName = company?.name ?? 'Nissie Ideal Shelters';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E6BE6'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _reportType == 'weekly'
                          ? 'Weekly Performance Report'
                          : _reportType == 'monthly'
                              ? 'Monthly Performance Report'
                              : 'Daily Performance Report',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Report Date: $formattedDate',
                      style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
                    ),
                  ],
                ),
                pw.Text(
                  DateTime.now().toIso8601String().split('T').first,
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#94A3B8')),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 20),

            // Key Metrics Grid
            pw.Text(
              'KEY PERFORMANCE INDICATORS',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8')),
            ),
            pw.SizedBox(height: 10),
            pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 0.25,
              children: [
                _buildPdfKpiCard('New Leads', report.newLeads.toString()),
                _buildPdfKpiCard('Follow-ups', report.followUps.toString()),
                _buildPdfKpiCard('Inspections Booked / Completed', '${report.inspectionsBooked} / ${report.inspectionsCompleted}'),
                _buildPdfKpiCard('Revenue Generated', currencyFormat.format(report.revenueToday)),
              ],
            ),
            pw.SizedBox(height: 30),

            // Lead Pipeline Stages
            pw.Text(
              'PIPELINE STAGES',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8')),
            ),
            pw.SizedBox(height: 10),
            if (report.leadsByStage.isEmpty)
              pw.Text('No active leads recorded in pipeline for this period.', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('STAGE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('COUNT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    ],
                  ),
                  ...report.leadsByStage.entries.map((entry) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.key.toUpperCase(), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.value.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 30),

            // Leaderboard
            pw.Text(
              'STAFF PERFORMANCE LEADERBOARD',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8')),
            ),
            pw.SizedBox(height: 10),
            if (report.topStaff.isEmpty)
              pw.Text('No staff performance logs recorded for this period.', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')))
            else
              pw.Table(
                border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.5)),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('STAFF NAME', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('LEADS HANDLED', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('CONVERSIONS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('CONV. RATE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    ],
                  ),
                  ...report.topStaff.map((staff) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(staff.name, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(staff.leadsHandled.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(staff.conversions.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${staff.conversionRate.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E6BE6')), textAlign: pw.TextAlign.center)),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: _reportType == 'weekly'
            ? 'weekly_report_${_selectedDate.toIso8601String().split("T").first}.pdf'
            : _reportType == 'monthly'
                ? 'monthly_report_${_selectedDate.toIso8601String().split("T").first}.pdf'
                : 'daily_report_${_selectedDate.toIso8601String().split("T").first}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  pw.Widget _buildPdfKpiCard(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'))),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Performance Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_report != null && !_isLoadingReport && _error == null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export PDF',
              onPressed: _exportPdfReport,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Toggle Daily / Weekly ──
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'daily',
                        label: Text('Daily Report'),
                        icon: Icon(Icons.today),
                      ),
                      ButtonSegment<String>(
                        value: 'weekly',
                        label: Text('Weekly Report'),
                        icon: Icon(Icons.date_range),
                      ),
                      ButtonSegment<String>(
                        value: 'monthly',
                        label: Text('Monthly Report'),
                        icon: Icon(Icons.calendar_month),
                      ),
                    ],
                    selected: {_reportType},
                    onSelectionChanged: (value) {
                      setState(() {
                        _reportType = value.first;
                      });
                      _loadReport();
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.accent.withOpacity(0.12),
                      selectedForegroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Calendar Navigation Header ──
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                  onPressed: () => _changeDate(-1),
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          _reportType == 'weekly'
                              ? "${DateFormat('MMM d').format(_selectedDate.subtract(const Duration(days: 6)))} - ${DateFormat('yMMMMd').format(_selectedDate)}"
                              : _reportType == 'monthly'
                                  ? "${DateFormat('MMM d').format(_selectedDate.subtract(const Duration(days: 29)))} - ${DateFormat('yMMMMd').format(_selectedDate)}"
                                  : DateFormat('yMMMMd').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
                  onPressed: _selectedDate.day == DateTime.now().day &&
                          _selectedDate.month == DateTime.now().month &&
                          _selectedDate.year == DateTime.now().year
                      ? null
                      : () => _changeDate(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // ── Scrollable Report Body ──
          Expanded(
            child: _isLoadingReport
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null
                    ? _buildErrorState()
                    : _report == null
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadReport,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Grid KPI cards
                                  _buildStatsGrid(isMobile),
                                  const SizedBox(height: 32),

                                  // Pipeline distribution snapshot
                                  _buildPipelineSnapshot(theme),
                                  const SizedBox(height: 32),

                                  // Leaderboard section
                                  _buildStaffLeaderboard(theme),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred.',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Report Generated',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'We were unable to fetch compiled aggregates for this date.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Refresh & Compile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool isMobile) {
    final report = _report!;
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    final stats = [
      _StatItem('New Leads', report.newLeads.toString(), Icons.person_add_outlined, AppColors.primary),
      _StatItem('Follow-ups', report.followUps.toString(), Icons.history_rounded, AppColors.info),
      _StatItem('Inspections', '${report.inspectionsCompleted}/${report.inspectionsBooked}', Icons.calendar_today_rounded, Colors.purple),
      _StatItem('Revenue Today', currencyFormat.format(report.revenueToday), Icons.monetization_on_outlined, AppColors.success),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: stats.map((s) => _buildStatCard(s)).toList(),
      );
    }

    return Row(
      children: stats.map((s) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildStatCard(s),
        ),
      )).toList(),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineSnapshot(ThemeData theme) {
    final report = _report!;
    final distribution = report.leadsByStage;
    final total = distribution.values.fold<int>(0, (sum, val) => sum + val);

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pipeline Stage Snapshot',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('No active lead pipeline records.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...distribution.entries.map((entry) {
                final ratio = total == 0 ? 0.0 : entry.value / total;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            '${entry.value} (${(ratio * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: AppColors.background,
                          color: _getStageColor(entry.key),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffLeaderboard(ThemeData theme) {
    final report = _report!;
    final staffList = report.topStaff;

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff Performance Leaderboard',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (staffList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('No agency staff activity recorded.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                },
                children: [
                  const TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text('NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text('HANDLED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary), textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text('CONV.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary), textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text('RATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary), textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                  ...staffList.map((staff) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Text(
                            staff.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Text(
                            staff.leadsHandled.toString(),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Text(
                            staff.conversions.toString(),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Text(
                            '${staff.conversionRate.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'new':
        return AppColors.info;
      case 'contacted':
        return Colors.indigo;
      case 'nurturing':
        return Colors.purple;
      case 'negotiating':
        return Colors.orange;
      case 'closed':
        return AppColors.success;
      case 'lost':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _StatItem(this.label, this.value, this.icon, this.color);
}
