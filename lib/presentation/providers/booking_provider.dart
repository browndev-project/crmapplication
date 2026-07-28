import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/booking_model.dart';
import '../../core/services/booking_service.dart';
import '../../core/constants/permission_constants.dart';
import 'permissions_provider.dart';
import 'login_provider.dart';

class BookingsState {
  final bool isLoading;
  final String? error;
  final List<Booking> bookings;
  final BookingStats? stats;
  final Map<String, dynamic> filters;

  const BookingsState({
    this.isLoading = false,
    this.error,
    this.bookings = const [],
    this.stats,
    this.filters = const {'status': 'all', 'searchQuery': ''},
  });

  BookingsState copyWith({
    bool? isLoading,
    String? error,
    List<Booking>? bookings,
    BookingStats? stats,
    Map<String, dynamic>? filters,
  }) {
    return BookingsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      bookings: bookings ?? this.bookings,
      stats: stats ?? this.stats,
      filters: filters ?? this.filters,
    );
  }
}

class BookingsNotifier extends Notifier<BookingsState> {
  @override
  BookingsState build() {
    return const BookingsState();
  }

  BookingService get _service => ref.read(bookingServiceProvider);

  Future<void> fetchBookings({bool isRefresh = false}) async {
    if (state.isLoading && !isRefresh) return;

    state = state.copyWith(isLoading: true, error: null);

    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    // View check: View Bookings
    if (!permissions.can(
      PermissionModules.BOOKING,
      permission: PermissionModules.BOOKING_VIEW,
      userRole: userRole,
    )) {
      state = state.copyWith(
        isLoading: false,
        error: 'Permission Denied: You do not have permission to view bookings.',
      );
      return;
    }

    try {
      final response = await _service.fetchBookings(
        searchQuery: state.filters['searchQuery'],
        status: state.filters['status'],
        leadId: state.filters['lead'],
      );

      state = state.copyWith(
        isLoading: false,
        bookings: response.data?.bookings ?? [],
        stats: response.data?.stats ?? state.stats,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchStats() async {
    try {
      final response = await _service.fetchBookingStats();
      if (response.data?.stats != null) {
        state = state.copyWith(stats: response.data!.stats);
      }
    } catch (e) {
      debugPrint('Error fetching booking stats: $e');
    }
  }

  Future<void> applyFilters(Map<String, dynamic> newFilters) async {
    final mergedFilters = Map<String, dynamic>.from(state.filters)..addAll(newFilters);
    state = state.copyWith(filters: mergedFilters);
    await fetchBookings(isRefresh: true);
  }

  Future<void> clearFilters() async {
    state = state.copyWith(filters: const {'status': 'all', 'searchQuery': ''});
    await fetchBookings(isRefresh: true);
  }

  Future<Booking> createBooking(Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    // Create check
    if (!permissions.can(
      PermissionModules.BOOKING,
      permission: PermissionModules.BOOKING_CREATE,
      userRole: userRole,
    )) {
      throw 'Permission Denied: You do not have permission to create bookings.';
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final newBooking = await _service.createBooking(data);
      state = state.copyWith(isLoading: false);
      // Re-fetch bookings list after successful creation
      await fetchBookings(isRefresh: true);
      return newBooking;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateBooking(String id, Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    // Update check
    if (!permissions.can(
      PermissionModules.BOOKING,
      permission: PermissionModules.BOOKING_UPDATE,
      userRole: userRole,
    )) {
      throw 'Permission Denied: You do not have permission to edit bookings.';
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _service.updateBooking(id, data);
      state = state.copyWith(isLoading: false);
      if (success) {
        await fetchBookings(isRefresh: true);
      } else {
        throw 'Failed to update booking';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteBooking(String id) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    // Delete check
    if (!permissions.can(
      PermissionModules.BOOKING,
      permission: PermissionModules.BOOKING_DELETE,
      userRole: userRole,
    )) {
      throw 'Permission Denied: You do not have permission to delete bookings.';
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _service.deleteBooking(id);
      state = state.copyWith(isLoading: false);
      if (success) {
        await fetchBookings(isRefresh: true);
      } else {
        throw 'Failed to delete booking';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final bookingServiceProvider = Provider<BookingService>((ref) => BookingService());

final bookingsProvider = NotifierProvider.autoDispose<BookingsNotifier, BookingsState>(() {
  return BookingsNotifier();
});
