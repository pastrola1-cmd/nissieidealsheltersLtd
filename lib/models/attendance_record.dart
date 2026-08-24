import 'package:intl/intl.dart';

/// Represents a single staff clock-in / clock-out attendance session.
class AttendanceRecord {
  final String id;
  final String companyId;
  final String userId;
  final DateTime workDate;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final String workMode; // 'office', 'field', 'remote'
  final String status; // 'clocked_in', 'clocked_out', 'on_break'
  final bool isLate;
  final double? locationLat;
  final double? locationLng;
  final String? locationName;
  final double? clockOutLat;
  final double? clockOutLng;
  final String? clockOutLocationName;
  final String? propertyId;
  final String? propertyName;
  final String? notes;
  final int totalMinutes;
  final String? staffName;
  final String? staffEmail;
  final String? staffRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceRecord({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.workDate,
    required this.clockInAt,
    this.clockOutAt,
    this.workMode = 'office',
    this.status = 'clocked_in',
    this.isLate = false,
    this.locationLat,
    this.locationLng,
    this.locationName,
    this.clockOutLat,
    this.clockOutLng,
    this.clockOutLocationName,
    this.propertyId,
    this.propertyName,
    this.notes,
    this.totalMinutes = 0,
    this.staffName,
    this.staffEmail,
    this.staffRole,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isClockedIn => status == 'clocked_in' && clockOutAt == null;
  bool get isFieldWork => workMode == 'field';
  bool get isOfficeWork => workMode == 'office';
  bool get isRemoteWork => workMode == 'remote';

  Duration get duration {
    if (clockOutAt != null) {
      return clockOutAt!.difference(clockInAt);
    }
    final now = DateTime.now();
    return now.difference(clockInAt);
  }

  String get durationFormatted {
    final dur = duration;
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String get formattedClockIn => DateFormat('h:mm a').format(clockInAt.toLocal());
  String get formattedClockOut => clockOutAt != null ? DateFormat('h:mm a').format(clockOutAt!.toLocal()) : '--:--';
  String get formattedDate => DateFormat('EEE, MMM d, yyyy').format(workDate);

  String get workModeLabel {
    switch (workMode) {
      case 'field':
        return propertyName != null && propertyName!.isNotEmpty
            ? '🚗 Inspection: $propertyName'
            : '🚗 Field / Inspection';
      case 'remote':
        return '💻 Remote';
      case 'office':
      default:
        return '🏢 In-Office';
    }
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? fallback;
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final profilesMap = json['profiles'] as Map<String, dynamic>?;

    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      workDate: parseDate(json['work_date'], DateTime.now()),
      clockInAt: parseDate(json['clock_in_at'], DateTime.now()),
      clockOutAt: json['clock_out_at'] != null ? parseDate(json['clock_out_at'], DateTime.now()) : null,
      workMode: json['work_mode']?.toString() ?? 'office',
      status: json['status']?.toString() ?? 'clocked_in',
      isLate: json['is_late'] == true,
      locationLat: parseDouble(json['location_lat']),
      locationLng: parseDouble(json['location_lng']),
      locationName: json['location_name']?.toString(),
      clockOutLat: parseDouble(json['clock_out_lat']),
      clockOutLng: parseDouble(json['clock_out_lng']),
      clockOutLocationName: json['clock_out_location_name']?.toString(),
      propertyId: json['property_id']?.toString(),
      propertyName: json['property_name']?.toString(),
      notes: json['notes']?.toString(),
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      staffName: json['staff_name']?.toString() ?? profilesMap?['full_name']?.toString(),
      staffEmail: json['staff_email']?.toString() ?? profilesMap?['email']?.toString(),
      staffRole: json['staff_role']?.toString() ?? profilesMap?['role']?.toString(),
      createdAt: parseDate(json['created_at'], DateTime.now()),
      updatedAt: parseDate(json['updated_at'], DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'user_id': userId,
      'work_date': DateFormat('yyyy-MM-dd').format(workDate),
      'clock_in_at': clockInAt.toIso8601String(),
      'clock_out_at': clockOutAt?.toIso8601String(),
      'work_mode': workMode,
      'status': status,
      'is_late': isLate,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'location_name': locationName,
      'clock_out_lat': clockOutLat,
      'clock_out_lng': clockOutLng,
      'clock_out_location_name': clockOutLocationName,
      'property_id': propertyId,
      'property_name': propertyName,
      'notes': notes,
      'total_minutes': totalMinutes,
    };
  }

  AttendanceRecord copyWith({
    String? id,
    String? companyId,
    String? userId,
    DateTime? workDate,
    DateTime? clockInAt,
    DateTime? clockOutAt,
    String? workMode,
    String? status,
    bool? isLate,
    double? locationLat,
    double? locationLng,
    String? locationName,
    double? clockOutLat,
    double? clockOutLng,
    String? clockOutLocationName,
    String? propertyId,
    String? propertyName,
    String? notes,
    int? totalMinutes,
    String? staffName,
    String? staffEmail,
    String? staffRole,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      workDate: workDate ?? this.workDate,
      clockInAt: clockInAt ?? this.clockInAt,
      clockOutAt: clockOutAt ?? this.clockOutAt,
      workMode: workMode ?? this.workMode,
      status: status ?? this.status,
      isLate: isLate ?? this.isLate,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationName: locationName ?? this.locationName,
      clockOutLat: clockOutLat ?? this.clockOutLat,
      clockOutLng: clockOutLng ?? this.clockOutLng,
      clockOutLocationName: clockOutLocationName ?? this.clockOutLocationName,
      propertyId: propertyId ?? this.propertyId,
      propertyName: propertyName ?? this.propertyName,
      notes: notes ?? this.notes,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      staffName: staffName ?? this.staffName,
      staffEmail: staffEmail ?? this.staffEmail,
      staffRole: staffRole ?? this.staffRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
