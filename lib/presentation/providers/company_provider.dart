

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/company_model.dart';
import '../../core/services/company_service.dart';

class CompanyState {
  final bool isLoading;
  final Company? company;
  final String? error;

  const CompanyState({
    this.isLoading = false,
    this.company,
    this.error,
  });

  CompanyState copyWith({
    bool? isLoading,
    Company? company,
    String? error,
  }) {
    return CompanyState(
      isLoading: isLoading ?? this.isLoading,
      company: company ?? this.company,
      error: error,
    );
  }
}

class CompanyNotifier extends StateNotifier<CompanyState> {
  final CompanyService _companyService;

  CompanyNotifier(this._companyService) : super(const CompanyState());

  Future<void> fetchCompanyDetails() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final company = await _companyService.fetchCompanyDetails();
      state = state.copyWith(isLoading: false, company: company);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
      await fetchCompanyDetails();
  }
}

final companyServiceProvider = Provider<CompanyService>((ref) => CompanyService());

final companyProvider = StateNotifierProvider<CompanyNotifier, CompanyState>((ref) {
  final companyService = ref.watch(companyServiceProvider);
  return CompanyNotifier(companyService);
});
