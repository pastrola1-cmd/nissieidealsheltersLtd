import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';

class DocumentState {
  final List<DocumentRecord> documents;
  final bool isLoading;
  final String? errorMessage;

  const DocumentState({
    this.documents = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DocumentState copyWith({
    List<DocumentRecord>? documents,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DocumentNotifier extends Notifier<DocumentState> {
  late SupabaseService _supabaseService;
  String? _loadedCompanyId;

  @override
  DocumentState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    final authState = ref.watch(authProvider);
    final companyId = authState.profile?.companyId;

    if (companyId != null) {
      if (_loadedCompanyId != companyId) {
        _loadedCompanyId = companyId;
        Future.microtask(() => loadDocuments());
        return const DocumentState(isLoading: true);
      }
      return state;
    } else {
      _loadedCompanyId = null;
      return const DocumentState();
    }
  }

  /// Loads all documents generated for the company
  Future<void> loadDocuments() async {
    final authState = ref.read(authProvider);
    final companyId = authState.profile?.companyId;
    if (companyId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final list = await _supabaseService.getDocuments(companyId: companyId);
      state = DocumentState(documents: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Generates, uploads PDF bytes to storage, and registers the document in the DB
  Future<DocumentRecord?> uploadAndCreateDocument({
    required String leadId,
    required DocumentType type,
    required String title,
    required Map<String, dynamic> variables,
    required Uint8List pdfBytes,
  }) async {
    final authState = ref.read(authProvider);
    final profile = authState.profile;
    if (profile == null || profile.companyId == null) {
      state = state.copyWith(errorMessage: 'Authentication error: Company ID not found.');
      return null;
    }

    state = state.copyWith(isLoading: true);
    try {
      // 1. Upload compiled PDF to company-assets bucket
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'documents/lead_$leadId/${type.value}_$timestamp.pdf';
      
      final publicUrl = await _supabaseService.uploadFile(
        'company-assets',
        storagePath,
        pdfBytes,
        mimeType: 'application/pdf',
      );

      // 2. Create the document record in database
      final Map<String, dynamic> recordData = {
        'company_id': profile.companyId,
        'lead_id': leadId,
        'created_by': profile.id,
        'type': type.value,
        'title': title,
        'file_url': publicUrl,
        'variables': variables,
      };

      final newRecord = await _supabaseService.createDocument(recordData);

      // 3. Update local state
      state = DocumentState(
        documents: [newRecord, ...state.documents],
        isLoading: false,
      );
      
      return newRecord;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  /// Deletes a document record from database
  Future<bool> deleteDocument(String documentId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _supabaseService.deleteDocument(documentId);
      final updatedList = state.documents.where((d) => d.id != documentId).toList();
      state = DocumentState(documents: updatedList, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final documentProvider = NotifierProvider<DocumentNotifier, DocumentState>(() {
  return DocumentNotifier();
});
