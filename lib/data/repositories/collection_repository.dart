import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../local/app_local_cache.dart';

/// Repositorio desacoplado para solicitudes de recolección de residuos.
/// Implementa una estrategia de datos Cache-First con SWR (Stale-While-Revalidate).
class CollectionRepository {
  CollectionRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  /// Obtiene una solicitud por su ID.
  /// Si está en caché local de Hive, la retorna de inmediato sin latencia de red.
  /// En segundo plano (o si no está en caché o [forceRefresh] es true), consulta la API remota.
  Future<CollectionRequest> getRequest(
    String id, {
    bool forceRefresh = false,
  }) async {
    // 1. Revisar caché local si no se fuerza recarga
    if (!forceRefresh) {
      final cachedJson = AppLocalCache.getRequest(id);
      if (cachedJson != null) {
        try {
          return CollectionRequest.fromJson(cachedJson);
        } catch (e) {
          debugPrint('[CollectionRepository] Error parseando request de caché: $e');
        }
      }
    }

    // 2. Consulta remota con la API
    final remoteRequest = await _api.collectionRequestDetail(id);

    // 3. Actualizar la caché local de Hive
    try {
      await AppLocalCache.putRequest(id, remoteRequest.toJson());
    } catch (e) {
      debugPrint('[CollectionRepository] Error guardando request en caché: $e');
    }

    return remoteRequest;
  }

  /// Flujo reactivo SWR: emite primero la versión cacheada (si existe) y luego la versión fresca de red.
  Stream<CollectionRequest> watchRequest(String id) async* {
    final cachedJson = AppLocalCache.getRequest(id);
    if (cachedJson != null) {
      try {
        yield CollectionRequest.fromJson(cachedJson);
      } catch (_) {}
    }

    try {
      final fresh = await _api.collectionRequestDetail(id);
      await AppLocalCache.putRequest(id, fresh.toJson());
      yield fresh;
    } catch (e) {
      // Si falla la red pero ya emitimos la versión cacheada, no bloqueamos la UI
      if (cachedJson == null) {
        rethrow;
      }
    }
  }

  /// Cancela una solicitud de recolección y actualiza la caché local.
  Future<void> cancelRequest(String id, {String? reason}) async {
    await _api.updateCollectionStatus(id, 'CANCELLED');
    final cached = AppLocalCache.getRequest(id);
    if (cached != null) {
      cached['status'] = 'CANCELLED';
      await AppLocalCache.putRequest(id, cached);
    }
  }

  /// Edita los materiales estimados o notas de una solicitud pendiente o en subasta abierta.
  Future<void> editRequest(
    String id, {
    Map<String, double>? itemsEstimated,
    String? description,
  }) async {
    await _api.editCollectionRequest(
      id,
      itemsEstimated: itemsEstimated,
      description: description,
    );
    final fresh = await _api.collectionRequestDetail(id);
    await AppLocalCache.putRequest(id, fresh.toJson());
  }

  /// Selecciona una propuesta de subasta (bid) y sincroniza la orden.
  Future<void> selectBid(String requestId, String bidId) async {
    await _api.selectBid(requestId, bidId);
    // Invalidar caché para forzar recarga fresca del nuevo centro asignado
    final fresh = await _api.collectionRequestDetail(requestId);
    await AppLocalCache.putRequest(requestId, fresh.toJson());
  }

  /// Califica el servicio de recolección y actualiza la caché local.
  Future<void> rateRequest(String id, {required int rating, String? feedback}) async {
    await _api.rateCollectionRequest(id, rating: rating, feedback: feedback);
    final cached = AppLocalCache.getRequest(id);
    if (cached != null) {
      cached['rating'] = rating;
      if (feedback != null) cached['feedback'] = feedback;
      await AppLocalCache.putRequest(id, cached);
    }
  }

  /// Calcula la ruta vehicular/pedestre entre dos coordenadas a través del proxy backend OSRM.
  Future<Map<String, dynamic>> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String profile = 'driving',
  }) {
    return _api.calculateRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      profile: profile,
    );
  }
}
