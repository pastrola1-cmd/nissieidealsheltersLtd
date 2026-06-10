import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ppn/config/supabase_config.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';

/// Provider for the base SupabaseService.
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Base service providing common CRUD operations against Supabase tables.
///
/// All methods operate on a given [table] name and return decoded JSON maps.
/// Use [companyId] filtering in multi-tenant scenarios where rows are
/// scoped by a `company_id` column.
///
/// Example:
/// ```dart
/// final service = SupabaseService();
/// final properties = await service.getAll('properties', companyId: '123');
/// ```
class SupabaseService {
  /// The Supabase client used for all database operations.
  final SupabaseClient _client = SupabaseConfig.client;

  /// Fetches all rows from [table].
  ///
  /// If [companyId] is provided the query is filtered to rows whose
  /// `company_id` column matches the given value.
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    String? companyId,
  }) async {
    var query = _client.from(table).select();

    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches a single row from [table] by its primary key [id].
  ///
  /// Returns `null` if no matching row is found.
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final response =
        await _client.from(table).select().eq('id', id).maybeSingle();
    return response;
  }

  /// Inserts [data] into [table] and returns the newly created row.
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response =
        await _client.from(table).insert(data).select().single();
    return response;
  }

  /// Updates the row identified by [id] in [table] with the provided [data].
  ///
  /// Returns the updated row.
  Future<Map<String, dynamic>> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    final response =
        await _client.from(table).update(data).eq('id', id).select().single();
    return response;
  }

  /// Deletes the row identified by [id] from [table].
  Future<void> delete(String table, String id) async {
    await _client.from(table).delete().eq('id', id);
  }

  // ─── Type-Safe Helpers ───

  /// Fetches properties with optional company filtering.
  Future<List<Property>> getProperties({String? companyId}) async {
    final list = await getAll('properties', companyId: companyId);
    return list.map((json) => Property.fromJson(json)).toList();
  }

  /// Fetches a single property by ID.
  Future<Property?> getProperty(String id) async {
    final data = await getById('properties', id);
    return data != null ? Property.fromJson(data) : null;
  }

  /// Fetches a single profile by ID.
  Future<Profile?> getProfile(String id) async {
    final data = await getById('profiles', id);
    return data != null ? Profile.fromJson(data) : null;
  }

  /// Fetches leads with optional company and partner filters.
  Future<List<Lead>> getLeads({String? companyId, String? partnerId}) async {
    var query = _client.from('leads').select();
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    if (partnerId != null) {
      query = query.eq('partner_id', partnerId);
    }
    final response = await query;
    return List<Map<String, dynamic>>.from(response)
        .map((json) => Lead.fromJson(json))
        .toList();
  }

  /// Uploads a file (bytes) to a Supabase Storage bucket and returns its public URL.
  Future<String> uploadFile(
    String bucket,
    String path,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    final storage = _client.storage.from(bucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );
    return storage.getPublicUrl(path);
  }

  /// Fetches all profiles with a specific role and optional company filter.
  Future<List<Profile>> getProfilesByRole(UserRole role, {String? companyId}) async {
    var query = _client.from('profiles').select().eq('role', role.value);
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response)
        .map((json) => Profile.fromJson(json))
        .toList();
  }

  /// Updates a profile status (and optionally referral code).
  Future<Profile> updateProfileStatus(
    String profileId,
    PartnerStatus status, {
    String? referralCode,
  }) async {
    final Map<String, dynamic> data = {'status': status.value};
    if (referralCode != null) {
      data['referral_code'] = referralCode;
    }
    final response = await update('profiles', profileId, data);
    return Profile.fromJson(response);
  }

  /// Resolves a profile using its unique referral code.
  Future<Profile?> getProfileByReferralCode(String code) async {
    final data = await _client.from('profiles').select().eq('referral_code', code).maybeSingle();
    return data != null ? Profile.fromJson(data) : null;
  }

  /// Logs a referral link click.
  Future<void> logReferralClick({
    required String referralCode,
    required String propertyId,
    String? partnerId,
    String? userAgent,
    String? ipAddress,
  }) async {
    await _client.from('referral_clicks').insert({
      'referral_code': referralCode,
      'property_id': propertyId,
      'partner_id': partnerId,
      'user_agent': userAgent,
      'ip_address': ipAddress,
    });
  }

  /// Inserts a new lead and returns it as a type-safe Lead model.
  Future<Lead> createLead(Map<String, dynamic> data) async {
    final response = await insert('leads', data);
    return Lead.fromJson(response);
  }

  /// Updates a lead's pipeline stage and notes.
  Future<Lead> updateLeadStage(String leadId, LeadStage stage, {String? notes}) async {
    final Map<String, dynamic> data = {
      'stage': stage.value,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) {
      data['notes'] = notes;
    }
    final response = await update('leads', leadId, data);
    return Lead.fromJson(response);
  }

  /// Fetches inspections with optional filtering by company, buyer, or partner.
  Future<List<Inspection>> getInspections({
    String? companyId,
    String? buyerId,
    String? partnerId,
  }) async {
    var query = _client.from('inspections').select();
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    if (buyerId != null) {
      query = query.eq('buyer_id', buyerId);
    }
    if (partnerId != null) {
      query = query.eq('partner_id', partnerId);
    }
    final response = await query;
    return List<Map<String, dynamic>>.from(response)
        .map((json) => Inspection.fromJson(json))
        .toList();
  }

  /// Inserts a new inspection and returns it as a type-safe Inspection model.
  Future<Inspection> createInspection(Map<String, dynamic> data) async {
    final response = await insert('inspections', data);
    return Inspection.fromJson(response);
  }

  /// Updates an inspection's status and notes.
  Future<Inspection> updateInspectionStatus(
    String inspectionId,
    InspectionStatus status, {
    String? notes,
  }) async {
    final Map<String, dynamic> data = {
      'status': status.value,
    };
    if (notes != null) {
      data['notes'] = notes;
    }
    final response = await update('inspections', inspectionId, data);
    return Inspection.fromJson(response);
  }

  /// Fetches commissions with optional company and partner filtering.
  Future<List<Commission>> getCommissions({String? companyId, String? partnerId}) async {
    var query = _client.from('commissions').select();
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    if (partnerId != null) {
      query = query.eq('partner_id', partnerId);
    }
    final response = await query;
    return List<Map<String, dynamic>>.from(response)
        .map((json) => Commission.fromJson(json))
        .toList();
  }

  /// Records a new pending commission.
  Future<Commission> createCommission(Map<String, dynamic> data) async {
    final response = await insert('commissions', data);
    return Commission.fromJson(response);
  }

  /// Updates a commission's status, record approved details.
  Future<Commission> updateCommissionStatus(
    String commissionId,
    CommissionStatus status, {
    String? approvedBy,
  }) async {
    final Map<String, dynamic> data = {
      'status': status.value,
    };
    if (approvedBy != null) {
      data['approved_by'] = approvedBy;
      data['approved_at'] = DateTime.now().toIso8601String();
    }
    final response = await update('commissions', commissionId, data);
    return Commission.fromJson(response);
  }

  /// Fetches transaction logs with optional company and partner filtering.
  Future<List<Transaction>> getTransactions({String? companyId, String? partnerId}) async {
    var query = _client.from('transactions').select();
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    if (partnerId != null) {
      query = query.eq('partner_id', partnerId);
    }
    final response = await query;
    return List<Map<String, dynamic>>.from(response)
        .map((json) => Transaction.fromJson(json))
        .toList();
  }

  /// Updates a partner's bank details.
  Future<Profile> updateProfileBankDetails(
    String profileId, {
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final Map<String, dynamic> data = {
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
    };
    final response = await update('profiles', profileId, data);
    return Profile.fromJson(response);
  }

  /// Updates a transaction's status.
  Future<Transaction> updateTransactionStatus(
    String transactionId,
    TransactionStatus status,
  ) async {
    final Map<String, dynamic> data = {
      'status': status.value,
    };
    final response = await update('transactions', transactionId, data);
    return Transaction.fromJson(response);
  }

  /// Calls the public.get_partner_balance function via RPC.
  Future<double> getPartnerBalance(String partnerId) async {
    final response = await _client.rpc(
      'get_partner_balance',
      params: {'p_partner_id': partnerId},
    );
    return (response as num).toDouble();
  }
}
