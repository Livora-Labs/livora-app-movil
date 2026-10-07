import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../local/app_local_cache.dart';

/// Repositorio desacoplado para lotes (Batches) de recolectores y centros de acopio.
/// Implementa una estrategia Cache-First con SWR (Stale-While-Revalidate) para soporte offline.
class BatchRepository {
  BatchRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  /// Obtiene los lotes del usuario/centro actual con Cache-First + SWR.
  Future<List<Batch>> getBatches({bool forceRefresh = false, String? status}) async {
    final cacheKey = 'batches_${status ?? 'all'}';

    if (!forceRefresh) {
      final cachedList = AppLocalCache.getBatchList(cacheKey);
      if (cachedList != null && cachedList.isNotEmpty) {
        try {
          return cachedList.map(Batch.fromJson).toList();
        } catch (e) {
          debugPrint('[BatchRepository] Error parseando lotes cacheados: $e');
        }
      }
    }

    final remote = await _api.batches(status: status);
    try {
      await AppLocalCache.putBatchList(cacheKey, remote.map((b) => b.toJson()).toList());
    } catch (e) {
      debugPrint('[BatchRepository] Error guardando lotes en caché: $e');
    }
    return remote;
  }

  /// Obtiene un lote específico por ID.
  Future<Batch> getBatchDetail(String id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = AppLocalCache.getBatch(id);
      if (cached != null) {
        try {
          return Batch.fromJson(cached);
        } catch (_) {}
      }
    }

    final remote = await _api.batchDetail(id);
    try {
      await AppLocalCache.putBatch(id, remote.toJson());
    } catch (_) {}
    return remote;
  }

  /// Despacha un lote hacia un centro de acopio.
  Future<Batch> dispatchBatch(String batchId, String centerId) async {
    final updated = await _api.sendBatchToCenter(batchId, centerId);
    await AppLocalCache.putBatch(batchId, updated.toJson());
    return updated;
  }

  /// Recibe y valida un lote en el centro de acopio con pesaje real verificado.
  Future<Batch> receiveBatch({
    required String batchId,
    required Map<String, double> weights,
    String? note,
  }) async {
    await _api.receiveBatch(batchId, weights);
    final updated = await _api.batchDetail(batchId);
    await AppLocalCache.putBatch(batchId, updated.toJson());
    return updated;
  }
}
