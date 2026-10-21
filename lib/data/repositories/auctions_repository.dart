import '../../domain/repositories/i_auctions_repository.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';

/// Repositorio desacoplado para el módulo de subastas de recolección y asignaciones directas.
class AuctionsRepository implements IAuctionsRepository {
  final LivoraApi _api;

  AuctionsRepository(this._api);

  @override
  Future<List<CollectionRequest>> getCollectionRequests({int page = 1, int limit = 50}) {
    return _api.collectionRequests(page: page, limit: limit);
  }

  @override
  Future<List<AcopioPriceList>> getCenterPrices(String centerId) {
    return _api.fetchCenterPrices(centerId);
  }

  @override
  Future<void> updateMyPrices(List<Map<String, dynamic>> prices) {
    return _api.updateMyPrices(prices);
  }

  @override
  Future<void> claimAutomatic(String requestId) {
    return _api.claimAutomatic(requestId);
  }

  @override
  Future<void> submitBid(String requestId, {required Map<String, double> proposedRates}) {
    return _api.submitBid(requestId, proposedRates: proposedRates);
  }

  @override
  Future<void> withdrawBid(String requestId, String bidId) {
    return _api.withdrawBid(requestId, bidId);
  }
}
