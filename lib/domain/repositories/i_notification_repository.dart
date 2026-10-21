import '../../models/models.dart';

/// Contrato formal de dominio para la bandeja de notificaciones y alertas en tiempo real.
/// Principio SOLID: Dependency Inversion Principle (DIP).
abstract class INotificationRepository {
  /// Obtiene la lista de notificaciones históricas del usuario.
  Future<List<AppNotification>> getNotifications();

  /// Marca una notificación específica como leída.
  Future<void> markAsRead(String notificationId);

  /// Marca todas las notificaciones como leídas.
  Future<void> markAllAsRead();
}
