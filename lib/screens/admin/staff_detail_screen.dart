import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/attendance_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

/// Fetches a single staff profile by ID.
final staffProfileProvider = FutureProvider.autoDispose.family<Profile?, String>((ref, staffId) async {
  final service = ref.watch(supabaseServiceProvider);
  try {
    final data = await service.client.from('profiles').select().eq('id', staffId).maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Fetches all leads assigned to or created by a specific staff member.
final staffLeadsProvider = FutureProvider.autoDispose.family<List<Lead>, String>((ref, staffId) async {
  final authState = ref.watch(authProvider);
  final companyId = authState.profile?.companyId;
  if (companyId == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  try {
    // Fetch leads where this staff is the assigned agent
    final response = await service.client
        .from('leads')
        .select()
        .eq('company_id', companyId)
        .eq('assigned_agent_id', staffId)
        .order('created_at', ascending: false);

    final leads = (response as List).map((e) => Lead.fromJson(e as Map<String, dynamic>)).toList();
    return leads;
  } catch (e) {
    return [];
  }
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class StaffDetailScreen extends ConsumerStatefulWidget {
  final String staffId;

  const StaffDetailScreen({super.key, required this.staffId});

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  String _searchQuery = '';
  LeadStage? _stageFilter;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _stageColor(LeadStage stage) {
    switch (stage) {
      case LeadStage.newLead:
        return AppColors.info;
      case LeadStage.contacted:
        return Colors.orange;
      case LeadStage.inspectionBooked:
        return Colors.purple;
      case LeadStage.negotiation:
        return Colors.teal;
      case LeadStage.closed:
        return AppColors.success;
      case LeadStage.lost:
        return AppColors.error;
    }
  }

  IconData _stageIcon(LeadStage stage) {
    switch (stage) {
      case LeadStage.newLead:
        return Icons.fiber_new_rounded;
      case LeadStage.contacted:
        return Icons.phone_in_talk_outlined;
      case LeadStage.inspectionBooked:
        return Icons.calendar_today_rounded;
      case LeadStage.negotiation:
        return Icons.handshake_outlined;
      case LeadStage.closed:
        return Icons.check_circle_rounded;
      case LeadStage.lost:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffProfileProvider(widget.staffId));
    final leadsAsync = ref.watch(staffLeadsProvider(widget.staffId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: staffAsync.when(
        loading: () => const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Staff Detail')),
          body: Center(child: Text('Error: $e')),
        ),
        data: (staff) {
          if (staff == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Staff Detail')),
              body: const Center(child: Text('Staff member not found.')),
            );
          }

          return leadsAsync.when(
            loading: () => Scaffold(
              backgroundColor: AppColors.background,
              appBar: _buildAppBar(staff, context),
              body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
            error: (e, _) => Scaffold(
              appBar: _buildAppBar(staff, context),
              body: Center(child: Text('Failed to load clients: $e')),
            ),
            data: (allLeads) {
              // KPI Metrics
              final total = allLeads.length;
              final active = allLeads.where((l) =>
                l.stage == LeadStage.newLead ||
                l.stage == LeadStage.contacted ||
                l.stage == LeadStage.inspectionBooked ||
                l.stage == LeadStage.negotiation
              ).length;
              final closed = allLeads.where((l) => l.stage == LeadStage.closed).length;

              // Filter leads
              final filtered = allLeads.where((l) {
                final matchesSearch = _searchQuery.isEmpty ||
                    l.buyerName.toLowerCase().contains(_searchQuery) ||
                    l.buyerPhone.contains(_searchQuery) ||
                    (l.buyerEmail?.toLowerCase().contains(_searchQuery) ?? false);
                final matchesStage = _stageFilter == null || l.stage == _stageFilter;
                return matchesSearch && matchesStage;
              }).toList();

              return Scaffold(
                backgroundColor: AppColors.background,
                body: CustomScrollView(
                  slivers: [
                    // ── SliverAppBar with staff header ──
                    SliverAppBar(
                      expandedHeight: 220,
                      pinned: true,
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => context.pop(),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildStaffHeader(staff, theme),
                      ),
                    ),

                    // ── KPI Cards ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Row(
                          children: [
                            Expanded(child: _kpiCard('Total Clients', '$total', Icons.people_alt_rounded, AppColors.accent)),
                            const SizedBox(width: 10),
                            Expanded(child: _kpiCard('Active Pipeline', '$active', Icons.timeline_rounded, Colors.orange)),
                            const SizedBox(width: 10),
                            Expanded(child: _kpiCard('Closed Deals', '$closed', Icons.verified_rounded, AppColors.success)),
                          ],
                        ),
                      ),
                    ),

                    // ── Staff Attendance History & Punctuality ──
                    SliverToBoxAdapter(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final attHistoryAsync = ref.watch(staffAttendanceHistoryProvider(widget.staffId));
                          return attHistoryAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (history) {
                              if (history.isEmpty) return const SizedBox.shrink();
                              final totalHours = history.fold<int>(0, (sum, r) => sum + r.totalMinutes) ~/ 60;
                              final lateDays = history.where((r) => r.isLate).length;

                              return Container(
                                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.access_time_filled_rounded, size: 18, color: AppColors.accent),
                                            SizedBox(width: 8),
                                            Text(
                                              'Attendance & Timesheet Log',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${history.length} Days Recorded',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '⏱️ $totalHours hrs logged',
                                            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: (lateDays > 0 ? Colors.amber : Colors.green).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            lateDays > 0 ? '⏰ $lateDays Late Arrivals' : '✅ 100% Punctual',
                                            style: TextStyle(
                                              color: lateDays > 0 ? Colors.amber.shade800 : Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // ── Search & Filter ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                              decoration: InputDecoration(
                                hintText: 'Search clients by name, phone or email...',
                                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Stage filter chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _filterChip('All', null),
                                  const SizedBox(width: 8),
                                  ...LeadStage.values.map((s) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _filterChip(s.label, s),
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Clients (${filtered.length})',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (_stageFilter != null || _searchQuery.isNotEmpty) ...[ 
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _stageFilter = null;
                                      });
                                    },
                                    icon: const Icon(Icons.clear_rounded, size: 14),
                                    label: const Text('Clear'),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.textTertiary),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Client List ──
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_search_rounded, size: 64, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              Text(
                                total == 0 ? 'No clients assigned yet' : 'No clients match your filters',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                total == 0
                                    ? '${staff.fullName?.split(' ').first ?? 'This staff'} has no leads assigned yet.'
                                    : 'Try adjusting your search or stage filter.',
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildClientCard(filtered[index], context),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(Profile staff, BuildContext context) {
    return AppBar(
      title: Text(staff.fullName ?? 'Staff Detail'),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _buildStaffHeader(Profile staff, ThemeData theme) {
    final initials = (staff.fullName?.isNotEmpty == true)
        ? staff.fullName!.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase()
        : (staff.email?.isNotEmpty == true ? staff.email![0].toUpperCase() : '?');
    final roleLabel = staff.role == UserRole.manager
        ? 'Manager'
        : staff.role == UserRole.marketer
            ? 'Agent / Marketer'
            : staff.role.label;
    final roleColor = staff.role == UserRole.manager ? AppColors.info : AppColors.success;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 2),
            ),
            child: staff.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      staff.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                      ),
                    ),
                  )
                : Center(
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  staff.fullName ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Text(roleLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                if (staff.email != null)
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.white70, size: 13),
                      const SizedBox(width: 4),
                      Flexible(child: Text(staff.email!, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                if (staff.phone != null) ...[ 
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, color: Colors.white70, size: 13),
                      const SizedBox(width: 4),
                      Text(staff.phone!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Joined ${DateFormat('MMM dd, yyyy').format(staff.createdAt)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, LeadStage? stage) {
    final isSelected = _stageFilter == stage;
    return GestureDetector(
      onTap: () => setState(() => _stageFilter = stage),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildClientCard(Lead lead, BuildContext context) {
    final stageColor = _stageColor(lead.stage);
    final stageIcon = _stageIcon(lead.stage);
    final formattedDate = DateFormat('dd MMM yyyy').format(lead.createdAt);

    return GestureDetector(
      onTap: () {
        final role = ref.read(authProvider).profile?.role;
        if (role == UserRole.manager) {
          context.push('/manager/leads/${lead.id}');
        } else if (role == UserRole.marketer) {
          context.push('/marketer/leads/${lead.id}');
        } else {
          context.push('/admin/leads/${lead.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stage icon circle
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: stageColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(stageIcon, color: stageColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and stage badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lead.buyerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: stageColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          lead.stage.label,
                          style: TextStyle(
                            color: stageColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Phone
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(lead.buyerPhone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (lead.buyerEmail != null) ...[ 
                        const SizedBox(width: 12),
                        const Icon(Icons.email_outlined, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            lead.buyerEmail!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Source + Date
                  Row(
                    children: [
                      const Icon(Icons.source_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(lead.sourceChannel, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      const Spacer(),
                      const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
