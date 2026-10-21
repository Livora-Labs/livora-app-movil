import 'dart:async';
import '../../domain/repositories/i_collector_repository.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../local/app_local_cache.dart';

/// Repositorio desacoplado para operaciones del recolector (Radar GPS, lotes en vehículo y asignaciones).
/// Implementa [ICollectorRepository] con estrategia Cache-First / SWR.
class CollectorRepository implements ICollectorRepository {
  CollectorRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  @override
  Future<List<CollectionRequest>> getAvailableRequests({
    double? lat,
    double? lng,
    double radiusKm = 5.0,
    String? centerId,
    bool onlyActiveBatches = false,
  }) async {
    if (lat != null && lng != null) {
      return _api.availableCollectionRequests(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        centerId: centerId,
        onlyActiveBatches: onlyActiveBatches,
      );
    }
    return _api.collectionRequests(lat: lat, lng: lng, radiusKm: radiusKm);
  }

  @override
  Future<List<Batch>> getOpenBatches() async {
    return _api.openBatches();
  }

  @override
  Future<void> acceptRequest(String requestId) async {
    await _api.updateCollectionStatus(requestId, 'ACCEPTED');
    final cached = AppLocalCache.getRequest(requestId);
    if (cached != null) {
      cached['status'] = 'ACCEPTED';
      await AppLocalCache.putRequest(requestId, cached);
    }
  }

  @override
  Future<CollectionRequest> rejectOnSite(
    String requestId,
    String reason, [
    String? photoUrl,
  ]) {
    return _api.rejectOnSite(
      requestId,
      reason,
      photoUrl != null ? [photoUrl] : null,
    );
  }

  @override
  Future<CollectorReputation> getReputation() async {
    return _api.collectorReputation();
  }
}
