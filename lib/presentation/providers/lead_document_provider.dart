import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/lead_document_service.dart';
import '../../data/models/lead_document_model.dart';

final leadDocumentServiceProvider = Provider((ref) => LeadDocumentService());

// --- Lead Documents Notifier (Specific Lead) ---
class LeadDocumentsNotifier extends StateNotifier<AsyncValue<List<LeadDocument>>> {
  final LeadDocumentService _service;
  final String leadId;

  LeadDocumentsNotifier(this._service, this.leadId) : super(const AsyncValue.loading()) {
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    state = const AsyncValue.loading();
    try {
      final docs = await _service.fetchLeadDocuments(leadId);
      state = AsyncValue.data(docs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> deleteDocument(String id) async {
    final success = await _service.deleteDocument(id);
    if (success) {
      fetchDocuments();
    }
    return success;
  }

  Future<bool> toggleLock(String id) async {
    final success = await _service.toggleLock(id);
    if (success) {
      fetchDocuments();
    }
    return success;
  }
}

final leadDocumentsProvider = StateNotifierProvider.family<LeadDocumentsNotifier, AsyncValue<List<LeadDocument>>, String>((ref, leadId) {
  return LeadDocumentsNotifier(ref.read(leadDocumentServiceProvider), leadId);
});

// --- Global Documents Notifier ---
class GlobalDocumentsState {
  final List<LeadDocument> documents;
  final bool isLoading;
  final String? error;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final String search;
  final String? fileType;
  final String? uploadedBy;
  
  GlobalDocumentsState({
    required this.documents,
    this.isLoading = false,
    this.error,
    this.totalCount = 0,
    this.totalPages = 1,
    this.currentPage = 1,
    this.search = '',
    this.fileType,
    this.uploadedBy,
  });

  GlobalDocumentsState copyWith({
    List<LeadDocument>? documents,
    bool? isLoading,
    String? error,
    int? totalCount,
    int? totalPages,
    int? currentPage,
    String? search,
    String? fileType,
    String? uploadedBy,
    bool clearFileType = false,
    bool clearUploadedBy = false,
  }) {
    return GlobalDocumentsState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      search: search ?? this.search,
      fileType: clearFileType ? null : (fileType ?? this.fileType),
      uploadedBy: clearUploadedBy ? null : (uploadedBy ?? this.uploadedBy),
    );
  }
}

class GlobalDocumentsNotifier extends StateNotifier<GlobalDocumentsState> {
  final LeadDocumentService _service;

  GlobalDocumentsNotifier(this._service) : super(GlobalDocumentsState(documents: [])) {
    fetchDocuments();
  }

  Future<void> fetchDocuments({
    int page = 1, 
    String? search, 
    String? fileType, 
    String? uploadedBy,
    bool clearFileType = false,
    bool clearUploadedBy = false,
  }) async {
    state = state.copyWith(
      isLoading: true, 
      error: null, 
      currentPage: page, 
      search: search,
      fileType: fileType,
      uploadedBy: uploadedBy,
      clearFileType: clearFileType,
      clearUploadedBy: clearUploadedBy,
    );
    try {
      final result = await _service.fetchAllDocuments(
        page: page,
        search: state.search,
        fileType: state.fileType,
        uploadedBy: state.uploadedBy,
      );
      final newDocs = result['documents'] as List<LeadDocument>;
      state = state.copyWith(
        documents: page == 1 ? newDocs : [...state.documents, ...newDocs],
        totalCount: result['totalCount'],
        totalPages: result['totalPages'],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.currentPage >= state.totalPages) return;
    await fetchDocuments(page: state.currentPage + 1);
  }

  Future<bool> deleteDocument(String id) async {
    try {
      final success = await _service.deleteDocument(id);
      if (success) {
        fetchDocuments(page: 1);
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}

final globalDocumentsProvider = StateNotifierProvider<GlobalDocumentsNotifier, GlobalDocumentsState>((ref) {
  return GlobalDocumentsNotifier(ref.read(leadDocumentServiceProvider));
});

// --- Document Forms Notifier ---
class DocumentFormsNotifier extends StateNotifier<AsyncValue<List<DocumentForm>>> {
  final LeadDocumentService _service;

  DocumentFormsNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchForms();
  }

  Future<void> fetchForms() async {
    state = const AsyncValue.loading();
    try {
      final forms = await _service.fetchForms();
      state = AsyncValue.data(forms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> createForm(String name, List<DocumentFormField> fields) async {
    final success = await _service.createForm(name, fields);
    if (success) fetchForms();
    return success;
  }

  Future<bool> updateForm(String id, String name, List<DocumentFormField> fields) async {
    final success = await _service.updateForm(id, name, fields);
    if (success) fetchForms();
    return success;
  }

  Future<bool> deleteForm(String id) async {
    final success = await _service.deleteForm(id);
    if (success) fetchForms();
    return success;
  }
}

final documentFormsProvider = StateNotifierProvider<DocumentFormsNotifier, AsyncValue<List<DocumentForm>>>((ref) {
  return DocumentFormsNotifier(ref.read(leadDocumentServiceProvider));
});
