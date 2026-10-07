import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../data/repositories/batch_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/livora_realtime.dart';

/// ViewModel desacoplado para la gestión de lotes en el Centro de Acopio.
/// Implementa Cache-First con SWR para carga instantánea y resiliencia offline en galpones.
class CenterBatchesViewModel extends ChangeNotifier {
  CenterBatchesViewModel({
    required BatchRepository repository,
    required LivoraRealtime realtime,
    required LivoraApi api,
  })  : _repository = repository,
        _realtime = realtime,
        _api = api,
        _state = const UIState.initial() {
    _init();
  }

  final BatchRepository _repository;
  final LivoraRealtime _realtime;
  final LivoraApi _api;

  UIState<List<Batch>> _state;
  String? _selectedFilter;
  final Set<String> _selectedBatchIds = {};
  bool _isConsolidating = false;
  bool _disposed = false;

  StreamSubscription? _batchDispatchedSub;
  StreamSubscription? _batchUpdatedSub;
  StreamSubscription? _batchCompletedSub;

  UIState<List<Batch>> get state => _state;
  String? get selectedFilter => _selectedFilter;
  Set<String> get selectedBatchIds => Set.unmodifiable(_selectedBatchIds);
  bool get isConsolidating => _isConsolidating;

  List<Batch> get filteredBatches {
    final list = _state.dataOrNull ?? [];
    if (_selectedFilter == null) return list;
    return list.where((b) => b.status == _selectedFilter).toList();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _init() async {
    await loadBatches();
    _subscribeRealtime();
  }

  void setFilter(String? filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      _safeNotify();
    }
  }

  void toggleSelection(String id) {
    if (_selectedBatchIds.contains(id)) {
      _selectedBatchIds.remove(id);
    } else {
      _selectedBatchIds.add(id);
    }
    _safeNotify();
  }

  void clearSelection() {
    _selectedBatchIds.clear();
    _safeNotify();
  }

  Future<void> loadBatches({bool forceRefresh = false}) async {
    _state = UIState.loading(cachedData: _state.dataOrNull);
    _safeNotify();

    try {
      final batches = await _repository.getBatches(forceRefresh: forceRefresh);
      if (batches.isEmpty) {
        _state = const UIState.empty();
      } else {
        _state = UIState.success(batches);
      }
    } catch (e) {
      _state = UIState.error(
        'No se pudieron cargar los lotes',
        cachedData: _state.dataOrNull,
      );
    }
    _safeNotify();
  }

  void _subscribeRealtime() {
    _batchDispatchedSub = _realtime.on(RealtimeEvents.batchDispatched).listen((_) {
      loadBatches(forceRefresh: true);
    });

    _batchUpdatedSub = _realtime.on(RealtimeEvents.batchUpdated).listen((_) {
      loadBatches(forceRefresh: true);
    });

    _batchCompletedSub = _realtime.on(RealtimeEvents.batchCompleted).listen((_) {
      loadBatches(forceRefresh: true);
    });
  }

  Future<bool> consolidateSelected() async {
    if (_selectedBatchIds.isEmpty) return false;
    _isConsolidating = true;
    _safeNotify();

    try {
      await _api.consolidateBatches(_selectedBatchIds.toList());
      _selectedBatchIds.clear();
      await loadBatches(forceRefresh: true);
      _isConsolidating = false;
      _safeNotify();
      return true;
    } catch (_) {
      _isConsolidating = false;
      _safeNotify();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _batchDispatchedSub?.cancel();
    _batchUpdatedSub?.cancel();
    _batchCompletedSub?.cancel();
    super.dispose();
  }
}
