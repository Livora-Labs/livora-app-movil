import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/i_batch_repository.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../local/app_local_cache.dart';

/// Repositorio desacoplado para lotes (Batches) de recolectores y centros de acopio.
/// Implementa una estrategia Cache-First con SWR (Stale-While-Revalidate) para soporte offline.
class BatchRepository implements IBatchRepository {
  BatchRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  @override
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

  @override
  Future<List<Batch>> getOpenBatches({String? centerId}) async {
    return _api.openBatches(centerId: centerId);
  }

  @override
  Future<Batch> getBatchDetail(String id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = AppLocalCache.getBatch(id);
      if (cached != null) {
        try {
          return Batch.fromJson(cached);
        } catch (e) {
          debugPrint('[BatchRepository] Error parseando detalle de lote cacheado: $e');
        }
      }
    }

    final remote = await _api.batchDetail(id);
    await AppLocalCache.putBatch(id, remote.toJson());
    return remote;
  }

  @override
  Future<Batch> dispatchBatch(String batchId, String centerId) async {
    final updated = await _api.sendBatchToCenter(batchId, centerId);
    await AppLocalCache.putBatch(batchId, updated.toJson());
    return updated;
  }

  @override
  Future<Map<String, dynamic>> receiveBatch(
    String batchId,
    Map<String, double> materialsActual,
  ) async {
    return _api.receiveBatch(batchId, materialsActual);
  }

  @override
  Future<Map<String, dynamic>> consolidateBatches(List<String> batchIds) async {
    return _api.consolidateBatches(batchIds);
  }
}
