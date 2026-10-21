import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../domain/repositories/i_batch_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_realtime.dart';

/// ViewModel desacoplado para la gestión de lotes en ruta del Recolector ("Mi Lote en Ruta").
/// Implementa SRP y Cache-First con SWR.
class MyBatchViewModel extends ChangeNotifier {
  MyBatchViewModel({
    required IBatchRepository repository,
    LivoraRealtime? realtime,
  })  : _repository = repository,
        _realtime = realtime {
    _subscribeRealtime();
  }

  final IBatchRepository _repository;
  final LivoraRealtime? _realtime;

  UIState<List<Batch>> _openBatchesState = const UIState.initial();
  UIState<List<Batch>> _historyBatchesState = const UIState.initial();

  UIState<List<Batch>> get openBatchesState => _openBatchesState;
  UIState<List<Batch>> get historyBatchesState => _historyBatchesState;

  bool _loadInProgress = false;
  final List<StreamSubscription> _subscriptions = [];

  void _subscribeRealtime() {
    if (_realtime == null) return;
    void onEvent(_) {
      if (!_loadInProgress) loadBatches();
    }

    _subscriptions.add(_realtime.on(RealtimeEvents.collectionUpdated).listen(onEvent));
    _subscriptions.add(_realtime.on(RealtimeEvents.batchCompleted).listen(onEvent));
    _subscriptions.add(_realtime.on(RealtimeEvents.batchDispatched).listen(onEvent));
    _subscriptions.add(_realtime.on(RealtimeEvents.batchUpdated).listen(onEvent));
  }

  /// Carga los lotes abiertos y el historial con soporte de caché local.
  Future<void> loadBatches() async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    final cachedOpen = _openBatchesState.dataOrNull;
    _openBatchesState = UIState.loading(cachedData: cachedOpen);
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getOpenBatches(),
        _repository.getBatches(),
      ]);

      final openBatches = results[0].where((b) => b.status == 'OPEN').toList();
      final historyBatches = results[1].where((b) => b.status != 'OPEN').toList();

      if (openBatches.isEmpty) {
        _openBatchesState = const UIState.empty();
      } else {
        _openBatchesState = UIState.success(openBatches);
      }

      _historyBatchesState = UIState.success(historyBatches);
    } catch (e) {
      _openBatchesState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        cachedData: cachedOpen,
        isNetworkError: true,
      );
    } finally {
      _loadInProgress = false;
      notifyListeners();
    }
  }

  /// Despacha un sub-lote hacia el centro de acopio destino.
  Future<Batch> dispatchBatch(String batchId, String centerId) async {
    final updated = await _repository.dispatchBatch(batchId, centerId);
    await loadBatches();
    return updated;
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
