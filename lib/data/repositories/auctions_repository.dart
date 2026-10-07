import '../../models/models.dart';
import '../../services/livora_api.dart';

/// Repositorio desacoplado para el módulo de subastas de recolección y asignaciones directas.
class AuctionsRepository {
  final LivoraApi _api;

  AuctionsRepository(this._api);

  /// Obtiene todas las solicitudes de recolección del ecosistema.
  Future<List<CollectionRequest>> getCollectionRequests({int page = 1, int limit = 50}) {
    return _api.collectionRequests(page: page, limit: limit);
  }

  /// Obtiene los precios configurados para el centro de acopio.
  Future<List<AcopioPriceList>> getCenterPrices(String centerId) {
    return _api.fetchCenterPrices(centerId);
  }

  /// Asigna automáticamente una solicitud de recolección al centro de acopio.
  Future<void> claimAutomatic(String requestId) {
    return _api.claimAutomatic(requestId);
  }

  /// Envía una puja formal de subasta con tarifas propuestas.
  Future<void> submitBid(String requestId, {required Map<String, double> proposedRates}) {
    return _api.submitBid(requestId, proposedRates: proposedRates);
  }

  /// Retira una puja activa del centro de acopio.
  Future<void> withdrawBid(String requestId, String bidId) {
    return _api.withdrawBid(requestId, bidId);
  }
}
