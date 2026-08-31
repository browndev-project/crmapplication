import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/constants_service.dart';
import '../../data/models/constants_model.dart';

class ConstantsNotifier extends StateNotifier<AsyncValue<AppConstantsData>> {
  final ConstantsService _service;

  ConstantsNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchConstants();
  }

  Future<void> fetchConstants({bool forceRefresh = false}) async {
    try {
      final constants = await _service.fetchConstants(forceRefresh: forceRefresh);
      state = AsyncValue.data(constants);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final constantsProvider =
    StateNotifierProvider<ConstantsNotifier, AsyncValue<AppConstantsData>>((ref) {
  return ConstantsNotifier(ConstantsService());
});
