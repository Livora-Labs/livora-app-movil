import '../../models/models.dart';

/// Contrato formal de dominio para la gestión del ciclo de vida de solicitudes de recolección.
/// Principio SOLID: Dependency Inversion Principle (DIP).
abstract class ICollectionRepository {
  /// Obtiene el detalle de una solicitud por su ID.
  Future<CollectionRequest> getRequest(String id, {bool forceRefresh = false});

  /// Flujo reactivo de datos con estrategia Cache-First / SWR.
  Stream<CollectionRequest> watchRequest(String id);

  /// Cancela una solicitud de recolección pendiente.
  Future<void> cancelRequest(String id, {String? reason});

  /// Modifica los materiales o notas de una solicitud activa.
  Future<void> editRequest(
    String id, {
    Map<String, double>? itemsEstimated,
    String? description,
  });

  /// Selecciona una oferta de subasta para adjudicar la recolección.
  Future<void> selectBid(String requestId, String bidId);

  /// Emite una calificación ciudadana y retroalimentación del servicio.
  Future<void> rateRequest(String id, {required int rating, String? feedback});

  /// Confirma el arribo del recolector al domicilio del hogar (EN_ROUTE -> ARRIVED).
  Future<CollectionRequest> confirmArrival(String id);

  /// Calcula ruta vehicular o pedestre mediante motor geodésico / OSRM.
  Future<Map<String, dynamic>> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String profile = 'driving',
  });
}
