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

  /// Bulk inserts multiple records into [table] and returns the newly inserted rows.
  Future<List<Map<String, dynamic>>> bulkInsert(
    String table,
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return [];
    final response = await _client.from(table).insert(records).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Bulk updates rows matching the list of [ids] in [table] with the provided [data].
  /// Returns the updated rows.
  Future<List<Map<String, dynamic>>> bulkUpdate(
    String table,
    List<String> ids,
    Map<String, dynamic> data,
  ) async {
    if (ids.isEmpty) return [];
    final response = await _client.from(table).update(data).inFilter('id', ids).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Bulk deletes rows matching the list of [ids] from [table].
  Future<void> bulkDelete(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from(table).delete().inFilter('id', ids);
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

  /// Fetches a single company by ID.
  Future<Company?> getCompany(String id) async {
    final data = await getById('companies', id);
    return data != null ? Company.fromJson(data) : null;
  }

  /// Fetches all registered companies sorted by name.
  /// If [excludeHidden] is true, only returns companies where is_hidden is false.
  Future<List<Company>> getCompanies({bool excludeHidden = false}) async {
    var query = _client.from('companies').select();
    if (excludeHidden) {
      query = query.eq('is_hidden', false);
    }
    final response = await query.order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response)
        .map((json) => Company.fromJson(json))
        .toList();
  }

  /// Updates a company's subscription tier, status, and expiration.
  Future<Company> updateCompanySubscription(
    String companyId, {
    required String tier,
    required String status,
    required DateTime expiresAt,
    int? customLeadLimit,
  }) async {
    final response = await update('companies', companyId, {
      'subscription_tier': tier,
      'subscription_status': status,
      'subscription_expires_at': expiresAt.toIso8601String(),
      'custom_lead_limit': customLeadLimit,
    });
    return Company.fromJson(response);
  }

  /// Fetches the monthly lead count for a company using the database RPC.
  Future<int> getMonthlyLeadCount(String companyId) async {
    final response = await _client.rpc(
      'get_monthly_lead_count',
      params: {'p_company_id': companyId},
    );
    return response as int;
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

  /// Fetches campaign logs with company filtering.
  Future<List<Campaign>> getCampaigns(String companyId) async {
    final response = await _client
        .from('campaigns')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response)
        .map((json) => Campaign.fromJson(json))
        .toList();
  }

  /// Logs a campaign share event to database
  Future<void> logCampaignShare(String campaignId, String platform) async {
    await _client.from('campaign_shares').insert({
      'campaign_id': campaignId,
      'platform': platform,
    });
  }

  /// Retrieves a daily report for a specific company and date.
  Future<DailyReport?> getDailyReport(String companyId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    final response = await _client
        .from('daily_reports')
        .select()
        .eq('company_id', companyId)
        .eq('report_date', dateStr)
        .maybeSingle();
    if (response == null) return null;
    return DailyReport.fromJson(response);
  }

  /// Triggers the database generator function to aggregate data for a specific date.
  Future<void> triggerReportCompilation(String companyId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    await _client.rpc('generate_daily_report_for_company', params: {
      'p_company_id': companyId,
      'p_date': dateStr,
    });
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

  /// Exposed client for real-time subscription
  SupabaseClient get client => _client;

  /// Fetches recent notifications for a user, sorted by created_at desc.
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response)
        .map((json) => NotificationModel.fromJson(json))
        .toList();
  }

  /// Marks a specific notification as read.
  Future<NotificationModel> markNotificationRead(String id) async {
    final response = await update('notifications', id, {'read': true});
    return NotificationModel.fromJson(response);
  }

  /// Marks all notifications for a user as read.
  Future<void> markAllNotificationsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId);
  }

  /// Updates the FCM token for a user profile.
  Future<Profile> updateFcmToken(String userId, String token) async {
    final response = await update('profiles', userId, {'fcm_token': token});
    return Profile.fromJson(response);
  }

  /// Fetches goals with optional company filter.
  Future<List<Goal>> getGoals({String? companyId}) async {
    final list = await getAll('goals', companyId: companyId);
    return list.map((json) => Goal.fromJson(json)).toList();
  }

  /// Inserts a new goal and returns it.
  Future<Goal> createGoal(Map<String, dynamic> data) async {
    final response = await insert('goals', data);
    return Goal.fromJson(response);
  }

  /// Invokes the database RPC function to create a new staff member with a
  /// temporary password. Returns a record containing the user ID and the
  /// plaintext temporary password so the admin can share it with the staff.

  Future<({String userId, String tempPassword})> inviteStaff({
    required String email,
    required String phone,
    required String fullName,
    required UserRole role,
    required String companyId,
  }) async {
    // Generate a readable temporary password (8 chars)
    final tempPassword = _generateTempPassword();

    // Invoke the postgres RPC function with the temp password
    final response = await _client.rpc(
      'invite_staff_member',
      params: {
        'p_email': email,
        'p_phone': phone,
        'p_name': fullName,
        'p_role': role.value,
        'p_company_id': companyId,
        'p_password': tempPassword,
      },
    );
    final userId = response as String;

    return (userId: userId, tempPassword: tempPassword);
  }

  /// Generates a human-readable temporary password like "Staff7294"
  String _generateTempPassword() {
    const prefix = 'Staff';
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return '$prefix$random';
  }

  // ─── Document Engine Helpers ───

  /// Fetches documents with optional company and lead filters.
  Future<List<DocumentRecord>> getDocuments({String? companyId, String? leadId}) async {
    var query = _client.from('documents').select();
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    if (leadId != null) {
      query = query.eq('lead_id', leadId);
    }
    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response)
        .map((json) => DocumentRecord.fromJson(json))
        .toList();
  }

  /// Inserts a new document record.
  Future<DocumentRecord> createDocument(Map<String, dynamic> data) async {
    final response = await insert('documents', data);
    return DocumentRecord.fromJson(response);
  }

  /// Deletes a document record.
  Future<void> deleteDocument(String id) async {
    await delete('documents', id);
  }

  // ─── Landing Page Helpers ───

  /// Fetches a landing page config by property ID.
  Future<Map<String, dynamic>?> getLandingPageByPropertyId(String propertyId) async {
    final response = await _client
        .from('landing_pages')
        .select()
        .eq('property_id', propertyId)
        .maybeSingle();
    return response;
  }

  /// Fetches a landing page config by slug.
  Future<Map<String, dynamic>?> getLandingPageBySlug(String companyId, String slug) async {
    final response = await _client
        .from('landing_pages')
        .select()
        .eq('company_id', companyId)
        .eq('slug', slug)
        .maybeSingle();
    return response;
  }

  /// Fetches a company by its custom domain.
  Future<Company?> getCompanyByDomain(String domain) async {
    final response = await _client
        .from('companies')
        .select()
        .eq('custom_domain', domain)
        .maybeSingle();
    return response != null ? Company.fromJson(response) : null;
  }

  /// Fetches a landing page config by slug globally across any company.
  Future<Map<String, dynamic>?> getLandingPageBySlugGlobally(String slug) async {
    final response = await _client
        .from('landing_pages')
        .select()
        .eq('slug', slug)
        .limit(1)
        .maybeSingle();
    return response;
  }

  /// Fetches a property by company ID and landing page slug.
  Future<Property?> getPropertyByLpSlug(String companyId, String slug) async {
    final lp = await getLandingPageBySlug(companyId, slug);
    if (lp == null) return null;
    final propertyId = lp['property_id'] as String;
    return getProperty(propertyId);
  }

  /// Submits a lead captured from a landing page using the secure postgres RPC.
  Future<String> submitPublicLead({
    required String companyId,
    required String propertyId,
    required String buyerName,
    required String buyerPhone,
    String? buyerEmail,
    String? notes,
    required String consentText,
    String? ipAddress,
    String? userAgent,
    String? sourceLandingPageId,
  }) async {
    final response = await _client.rpc(
      'create_public_lead',
      params: {
        'p_company_id': companyId,
        'p_property_id': propertyId,
        'p_buyer_name': buyerName,
        'p_buyer_phone': buyerPhone,
        'p_buyer_email': buyerEmail,
        'p_notes': notes,
        'p_consent_text': consentText,
        'p_ip_address': ipAddress,
        'p_user_agent': userAgent,
        'p_source_landing_page_id': sourceLandingPageId,
      },
    );
    return response as String;
  }

  /// Increments the view count of a landing page.
  Future<void> incrementLandingPageView(String landingPageId) async {
    await _client.rpc(
      'increment_landing_page_view',
      params: {'p_landing_page_id': landingPageId},
    );
  }

  /// Fetches active variants for a landing page.
  Future<List<LandingPageVariant>> getLandingPageVariants(String landingPageId) async {
    final response = await _client
        .from('landing_page_variants')
        .select()
        .eq('landing_page_id', landingPageId)
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response)
        .map((json) => LandingPageVariant.fromJson(json))
        .toList();
  }

  /// Records variant engagement securely via the database RPC.
  Future<void> recordVariantEngagement({
    required String variantId,
    required bool isLead,
  }) async {
    await _client.rpc(
      'record_variant_engagement',
      params: {
        'p_variant_id': variantId,
        'p_is_lead': isLead,
      },
    );
  }

  /// Logs an engagement signal for a lead and recalculates its intent score.
  Future<void> logLeadEngagement({
    required String leadId,
    required String signalType,
    required String signalValue,
  }) async {
    try {
      await _client.rpc(
        'log_lead_engagement',
        params: {
          'p_lead_id': leadId,
          'p_signal_type': signalType,
          'p_signal_value': signalValue,
        },
      );
    } catch (e) {
      // Ignore or log error to prevent breaking user flow
      print('Error logging lead engagement: $e');
    }
  }

  /// Fetches SLA metrics for a company using the database RPC.
  Future<Map<String, dynamic>> getCompanySlaStats(String companyId) async {
    try {
      final response = await _client.rpc(
        'get_company_sla_stats',
        params: {'p_company_id': companyId},
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      print('Error getting company SLA stats: $e');
      return {
        'total_leads': 0,
        'compliant_leads': 0,
        'compliance_rate': 100.0,
        'avg_response_time_seconds': 0.0,
        'overdue_leads': [],
        'agent_breakdown': [],
      };
    }
  }

  /// Bulk generates landing pages for a company. Returns the count of generated pages.
  Future<int> bulkGenerateLandingPages(String companyId) async {
    final response = await _client.rpc(
      'generate_landing_pages_for_company',
      params: {'p_company_id': companyId},
    );
    return response as int;
  }
}



