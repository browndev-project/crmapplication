import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/marketing_service.dart';
import '../../data/models/marketing_template_model.dart';

class TemplateState {
  final bool isLoading;
  final List<MarketingTemplate> templates;
  final String? error;

  const TemplateState({
    this.isLoading = false,
    this.templates = const [],
    this.error,
  });

  TemplateState copyWith({
    bool? isLoading,
    List<MarketingTemplate>? templates,
    String? error,
  }) {
    return TemplateState(
      isLoading: isLoading ?? this.isLoading,
      templates: templates ?? this.templates,
      error: error,
    );
  }
}

class TemplateNotifier extends StateNotifier<TemplateState> {
  final MarketingService _service;

  TemplateNotifier(this._service) : super(const TemplateState());

  Future<void> fetchTemplates() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final templates = await _service.fetchTemplates();
      state = state.copyWith(isLoading: false, templates: templates);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createTemplate({
    required String name,
    required String subject,
    required String body,
  }) async {
    try {
      final success = await _service.createTemplate(
        name: name,
        subject: subject,
        body: body,
      );
      if (success) {
        await fetchTemplates(); // Refresh the list
      }
      return success;
    } catch (e) {
      debugPrint('Error creating template: $e');
      return false;
    }
  }

  Future<bool> deleteTemplate(String id) async {
    try {
      final success = await _service.deleteTemplate(id);
      if (success) {
        state = state.copyWith(
          templates: state.templates.where((t) => t.id != id).toList(),
        );
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting template: $e');
      return false;
    }
  }
}

final marketingServiceProvider = Provider((ref) => MarketingService());

final templateProvider = StateNotifierProvider<TemplateNotifier, TemplateState>((ref) {
  final service = ref.watch(marketingServiceProvider);
  return TemplateNotifier(service);
});
