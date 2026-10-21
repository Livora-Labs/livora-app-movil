import '../../models/models.dart';

/// Contrato formal de dominio para el mercado de subastas y asignaciones directas de recolección.
/// Principio SOLID: Dependency Inversion Principle (DIP).
abstract class IAuctionsRepository {
  /// Obtiene las solicitudes de recolección disponibles para subasta o asignación.
  Future<List<CollectionRequest>> getCollectionRequests({int page = 1, int limit = 50});

  /// Obtiene el tarifario oficial de precios del centro de acopio.
  Future<List<AcopioPriceList>> getCenterPrices(String centerId);

  /// Actualiza el tarifario de compra por kg del centro de acopio.
  Future<void> updateMyPrices(List<Map<String, dynamic>> prices);

  /// Asigna automáticamente una solicitud de recolección según proximidad.
  Future<void> claimAutomatic(String requestId);

  /// Envía una puja formal de subasta con tarifas propuestas por kilogramo.
  Future<void> submitBid(String requestId, {required Map<String, double> proposedRates});

  /// Retira una puja activa realizada por el centro.
  Future<void> withdrawBid(String requestId, String bidId);
}
