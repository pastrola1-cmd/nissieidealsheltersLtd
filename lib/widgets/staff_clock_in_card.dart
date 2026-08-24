import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/utils/browser_location.dart';
import 'package:nissie_ideal_shelters/core/utils/location_helper.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/attendance_provider.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';

/// A hero card widget displaying real-time Clock-In / Clock-Out controls,
/// live working stopwatch timer, and anti-cheat work mode selector.
class StaffClockInCard extends ConsumerStatefulWidget {
  const StaffClockInCard({super.key});

  @override
  ConsumerState<StaffClockInCard> createState() => _StaffClockInCardState();
}

class _StaffClockInCardState extends ConsumerState<StaffClockInCard> {
  String _selectedMode = 'office'; // 'office', 'field', 'remote'
  String? _selectedPropertyId;
  String? _selectedPropertyName;
  Timer? _liveTimer;
  Duration _elapsed = Duration.zero;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _startTimerIfClockedIn();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _startTimerIfClockedIn() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = ref.read(attendanceProvider).todaySession;
      if (session != null && session.isClockedIn) {
        if (mounted) {
          setState(() {
            _elapsed = DateTime.now().difference(session.clockInAt);
          });
        }
      }
    });
  }

  String _formatTimer(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _handleClockIn() async {
    final notifier = ref.read(attendanceProvider.notifier);
    final scaffold = ScaffoldMessenger.of(context);
    final company = ref.read(authProvider).company;

    setState(() => _isLocating = true);

    // 1. Fetch live GPS location
    final loc = await getBrowserCoordinates();

    setState(() => _isLocating = false);

    // 2. Strict Geofence Check for In-Office duty
    final officeLat = company?.officeLat ?? 9.0345;
    final officeLng = company?.officeLng ?? 7.5450;
    final allowedRadius = company?.officeRadiusMeters ?? 300.0;

    if (_selectedMode == 'office') {
      if (!loc.isSuccess) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Location Required'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GPS location is required to verify that you are physically at the office premises.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.errorMessage ?? 'Please allow location permission in your browser.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '👉 How to allow:\n1. Tap the lock icon 🔒 or site settings in your browser address bar.\n2. Toggle Location / GPS to "Allow".\n3. Click Clock In again.',
                      style: TextStyle(fontSize: 11, color: AppColors.accent, height: 1.4),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Calculate distance to official office building
      final distance = LocationHelper.calculateDistanceMeters(
        loc.latitude,
        loc.longitude,
        officeLat,
        officeLng,
      );

      if (distance > allowedRadius) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 28),
                  SizedBox(width: 8),
                  Text('Geofence Alert'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You are not physically at the office premises!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your live GPS location indicates you are approximately ${LocationHelper.formatDistance(distance)} away from the office building (Suite 2, Shema complex, Asokoro extension).\n\nIn-office clock-in is strictly blocked from outside the office premises (allowed perimeter is ${allowedRadius.toInt()}m).',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Understood'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    final success = await notifier.clockIn(
      workMode: _selectedMode,
      propertyId: _selectedMode == 'field' ? _selectedPropertyId : null,
      propertyName: _selectedMode == 'field' ? _selectedPropertyName : null,
      locationLat: loc.isSuccess ? loc.latitude : null,
      locationLng: loc.isSuccess ? loc.longitude : null,
    );

    if (mounted) {
      if (success) {
        _startTimerIfClockedIn();
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('🎉 Verified & Clocked in successfully! Have a productive day.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final err = ref.read(attendanceProvider).errorMessage ?? 'Clock in failed.';
        scaffold.showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showClockOutModal(AttendanceRecord session) {
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'End Workday / Clock Out',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shift Duration: ${session.durationFormatted} (${session.formattedClockIn} - ${DateFormat('h:mm a').format(DateTime.now())})',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Daily Accomplishments Summary *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Briefly summarize your daily achievements (e.g. Conducted 2 inspections, followed up with 5 leads, sent 3 proposals)...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please provide a brief summary before clocking out';
                      }
                      if (val.trim().length < 10) {
                        return 'Summary must be at least 10 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(modalCtx);

                        final scaffold = ScaffoldMessenger.of(context);
                        final ok = await ref.read(attendanceProvider.notifier).clockOut(
                              notes: notesController.text.trim(),
                            );

                        if (mounted) {
                          if (ok) {
                            scaffold.showSnackBar(
                              const SnackBar(
                                content: Text('✅ Shift ended. Workday logged successfully!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            final err = ref.read(attendanceProvider).errorMessage ?? 'Failed to clock out.';
                            scaffold.showSnackBar(
                              SnackBar(
                                content: Text(err),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm & Clock Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final session = attendanceState.todaySession;
    final properties = ref.watch(propertyProvider).properties;

    // ── CASE 1: ALREADY CLOCKED OUT TODAY ──
    if (session != null && !session.isClockedIn && session.clockOutAt != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Workday Completed',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.durationFormatted,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.formattedClockIn} - ${session.formattedClockOut} • ${session.workModeLabel}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (session.notes != null && session.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '“${session.notes!}”',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── CASE 2: CLOCKED IN (LIVE ON DUTY) ──
    if (session != null && session.isClockedIn) {
      final timerText = _elapsed == Duration.zero
          ? _formatTimer(DateTime.now().difference(session.clockInAt))
          : _formatTimer(_elapsed);

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.greenAccent, blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE ON DUTY',
                      style: GoogleFonts.outfit(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.workModeLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timerText,
                      style: GoogleFonts.robotoMono(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clocked in at ${session.formattedClockIn}${session.isLate ? ' (Late arrival)' : ''}',
                      style: TextStyle(
                        color: session.isLate ? Colors.amberAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight: session.isLate ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showClockOutModal(session),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Clock Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ── CASE 3: NOT CLOCKED IN YET (START SHIFT) ──
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Staff Attendance & Clock-In',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('EEE, MMM d').format(DateTime.now()),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Work Mode:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModeChip('office', '🏢 In-Office'),
                const SizedBox(width: 8),
                _buildModeChip('field', '🚗 Field / Inspection'),
                const SizedBox(width: 8),
                _buildModeChip('remote', '💻 Remote'),
              ],
            ),
          ),

          // Property dropdown if Field Inspection is selected
          if (_selectedMode == 'field') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPropertyId,
                  isExpanded: true,
                  hint: const Text('Select property/site being inspected...', style: TextStyle(fontSize: 12)),
                  items: properties.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text('${p.title} (${p.location})', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPropertyId = val;
                      final prop = properties.where((p) => p.id == val).firstOrNull;
                      _selectedPropertyName = prop?.title;
                    });
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_isLocating || attendanceState.isLoading) ? null : _handleClockIn,
              icon: (_isLocating || attendanceState.isLoading)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.fingerprint_rounded, size: 20),
              label: Text(
                _isLocating
                    ? 'Verifying GPS Location...'
                    : (attendanceState.isLoading ? 'Clocking In...' : 'Clock In to Start Shift'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String mode, String label) {
    final isSelected = _selectedMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedMode = mode);
        }
      },
      selectedColor: AppColors.accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accent : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accent : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
