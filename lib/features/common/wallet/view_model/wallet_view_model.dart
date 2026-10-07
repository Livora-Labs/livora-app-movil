import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livora_labs/data/repositories/wallet_repository.dart';
import 'package:livora_labs/domain/state/ui_state.dart';
import 'package:livora_labs/services/livora_realtime.dart';

/// ViewModel de arquitectura limpia para el módulo de Billetera Web3 / LIVOs.
/// Encapsula estado, reactividad en tiempo real (WebSocket), integración Izipay y Web3.
class WalletViewModel extends ChangeNotifier {
  final WalletRepository _repository;
  final LivoraRealtime? _realtime;

  UIState<String> _balanceState = const UIState.initial();
  UIState<String> get balanceState => _balanceState;

  bool _isSending = false;
  bool get isSending => _isSending;

  final List<StreamSubscription> _subscriptions = [];

  WalletViewModel({
    required WalletRepository repository,
    LivoraRealtime? realtime,
  })  : _repository = repository,
        _realtime = realtime {
    _initRealtime();
    loadBalance();
  }

  void _initRealtime() {
    if (_realtime == null) return;
    void onEvent(_) => loadBalance(forceRefresh: true);
    _subscriptions.add(_realtime.on(RealtimeEvents.collectionUpdated).listen(onEvent));
    _subscriptions.add(_realtime.on(RealtimeEvents.batchCompleted).listen(onEvent));
    _subscriptions.add(_realtime.on(RealtimeEvents.redemptionCompleted).listen(onEvent));
  }

  /// Carga el saldo con estrategia SWR (Stale-While-Revalidate).
  Future<void> loadBalance({bool forceRefresh = false}) async {
    final cached = _balanceState.dataOrNull;
    _balanceState = UIState.loading(cachedData: cached);
    notifyListeners();

    try {
      final balance = await _repository.getBalance(forceRefresh: forceRefresh);
      _balanceState = UIState.success(balance);
    } catch (e) {
      _balanceState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        cachedData: cached,
        isNetworkError: true,
      );
    } finally {
      notifyListeners();
    }
  }

  /// Envía transferencia de tokens de manera delegada.
  Future<Map<String, dynamic>> sendTokens({
    required String toAddress,
    required double amount,
  }) async {
    _isSending = true;
    notifyListeners();
    try {
      final res = await _repository.sendTokens(toAddress: toAddress, amount: amount);
      await loadBalance(forceRefresh: true);
      return res;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Consulta detalles de un QR de comercio antes del cobro.
  Future<Map<String, dynamic>> getRedemptionDetails(String scannedCode) {
    return _repository.getRedemptionDetails(scannedCode);
  }

  /// Confirma la redención de LIVOs en el comercio aliado.
  Future<Map<String, dynamic>> confirmRedemption(String scannedCode) async {
    _isSending = true;
    notifyListeners();
    try {
      final res = await _repository.confirmRedemption(scannedCode);
      await loadBalance(forceRefresh: true);
      return res;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Crea una orden de pago con la pasarela Izipay.
  Future<Map<String, dynamic>> createPaymentSession(double amount) {
    return _repository.createPaymentSession(amount);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
