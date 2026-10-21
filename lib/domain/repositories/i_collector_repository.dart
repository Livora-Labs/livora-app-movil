import '../../models/models.dart';

/// Contrato formal de dominio para operaciones de campo del Recolector.
/// Principio SOLID: Dependency Inversion Principle (DIP) e Interface Segregation (ISP).
abstract class ICollectorRepository {
  /// Obtiene las solicitudes de recolección disponibles en el radar GPS.
  Future<List<CollectionRequest>> getAvailableRequests({
    double? lat,
    double? lng,
    double radiusKm = 5.0,
    String? centerId,
    bool onlyActiveBatches = false,
  });

  /// Obtiene los sub-lotes abiertos en el vehículo del recolector.
  Future<List<Batch>> getOpenBatches();

  /// Acepta una solicitud de recolección en el vehículo.
  Future<void> acceptRequest(String requestId);

  /// Rechaza in-situ una solicitud con motivo y evidencia fotográfica opcional.
  Future<CollectionRequest> rejectOnSite(
    String requestId,
    String reason, [
    String? photoUrl,
  ]);

  /// Obtiene las estadísticas de reputación operativa del recolector.
  Future<CollectorReputation> getReputation();
}
