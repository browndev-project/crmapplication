import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/calendar_event_model.dart';
import '../../core/services/calendar_service.dart';

class CalendarState {
  final bool isLoading;
  final List<CalendarEvent> events;
  final String? error;

  CalendarState({
    this.isLoading = false,
    this.events = const [],
    this.error,
  });

  CalendarState copyWith({
    bool? isLoading,
    List<CalendarEvent>? events,
    String? error,
  }) {
    return CalendarState(
      isLoading: isLoading ?? this.isLoading,
      events: events ?? this.events,
      error: error,
    );
  }
}

class CalendarNotifier extends StateNotifier<CalendarState> {
  final CalendarService _service;

  CalendarNotifier(this._service) : super(CalendarState());

  Future<void> fetchEvents(DateTime start, DateTime end) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final events = await _service.fetchEvents(start, end);
      state = state.copyWith(isLoading: false, events: events);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

final calendarProvider = StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final service = ref.watch(calendarServiceProvider);
  return CalendarNotifier(service);
});
