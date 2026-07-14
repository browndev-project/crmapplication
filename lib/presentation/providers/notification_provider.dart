import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/notification_model.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  final response = await service.fetchNotifications();
  if (response.success) {
    return response.notifications;
  } else {
    throw response.message;
  }
});
