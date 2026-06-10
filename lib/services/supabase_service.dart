import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ppn/config/supabase_config.dart';
import 'package:ppn/models/models.dart';

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
}
