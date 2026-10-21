import '../../domain/repositories/i_notification_repository.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';

/// Repositorio desacoplado para notificaciones y trazabilidad de eventos.
/// Implementa [INotificationRepository].
class NotificationRepository implements INotificationRepository {
  NotificationRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  @override
  Future<List<AppNotification>> getNotifications() {
    return _api.notifications();
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _api.markNotification(notificationId, isRead: true);
  }

  @override
  Future<void> markAllAsRead() {
    return _api.markAllNotificationsRead();
  }
}
