import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkReachabilityState {
  online,
  offline,
  checking,
}

/// Servicio centralizado de conectividad y accesibilidad real a internet para producción.
/// Valida no solo la interfaz de radio (WiFi/Celular) sino también la resolución y alcance real de red.
class NetworkConnectivityService extends ChangeNotifier {
  NetworkConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlinePollingTimer;

  bool _isOnline = true;
  bool _hasHardwareConnection = true;
  bool _wasOffline = false;
  NetworkReachabilityState _state = NetworkReachabilityState.online;

  /// Indica si el dispositivo tiene acceso efectivo a internet (DNS y API alcanzables).
  bool get isOnline => _isOnline;

  /// Indica si hubo una transición de offline a online recientemente (para notificar éxito).
  bool get wasOffline => _wasOffline;

  /// Estado detallado de alcance de red.
  NetworkReachabilityState get state => _state;

  /// Indica si hay al menos una interfaz física activa (WiFi, datos móviles o ethernet).
  bool get hasHardwareConnection => _hasHardwareConnection;

  void _init() {
    _checkInitialConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChanged);
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _evaluateConnectivity(results);
    } catch (e) {
      debugPrint('[NetworkConnectivityService] Error al comprobar conectividad inicial: $e');
    }
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    _evaluateConnectivity(results);
  }

  Future<bool> _evaluateConnectivity(List<ConnectivityResult> results) async {
    final hasHardware = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _hasHardwareConnection = hasHardware;

    if (!hasHardware) {
      _setOfflineState();
      return false;
    }

    // Comprobación real de alcance de internet (DNS + host backend)
    final reachable = await _probeReachability();
    if (reachable) {
      _setOnlineState();
      return true;
    } else {
      _setOfflineState();
      return false;
    }
  }

  /// Prueba ligera de alcance por resolución DNS y socket TCP con timeout estricto.
  Future<bool> _probeReachability() async {
    try {
      final result = await InternetAddress.lookup('api.grupolivoralabs.com')
          .timeout(const Duration(milliseconds: 3000));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      // Fallback a servidor DNS público global en caso de fallo temporal de resolución específica
      try {
        final fallback = await InternetAddress.lookup('8.8.8.8')
            .timeout(const Duration(milliseconds: 2500));
        return fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _setOnlineState() {
    _offlinePollingTimer?.cancel();
    _offlinePollingTimer = null;

    final stateChanged = !_isOnline;
    if (stateChanged) {
      _wasOffline = true;
      _isOnline = true;
      _state = NetworkReachabilityState.online;
      debugPrint('[NetworkConnectivityService] Conexión a internet restablecida (ONLINE)');
      notifyListeners();

      // Desactivar bandera wasOffline tras unos segundos para que la UI no muestre banner verde indefinidamente
      Timer(const Duration(seconds: 3), () {
        _wasOffline = false;
        notifyListeners();
      });
    } else {
      _state = NetworkReachabilityState.online;
    }
  }

  void _setOfflineState() {
    final stateChanged = _isOnline;
    _isOnline = false;
    _state = NetworkReachabilityState.offline;

    if (stateChanged) {
      debugPrint('[NetworkConnectivityService] Conexión a internet perdida (OFFLINE)');
      notifyListeners();
    }

    // Iniciar polling periódico para auto-recuperación si estamos sin conexión
    _offlinePollingTimer ??= Timer.periodic(const Duration(seconds: 4), (_) async {
      final reachable = await _probeReachability();
      if (reachable) {
        _setOnlineState();
      }
    });
  }

  /// Forzar una verificación inmediata manual de alcance (ej. botón "Reintentar").
  Future<bool> checkReachabilityNow() async {
    _state = NetworkReachabilityState.checking;
    notifyListeners();

    final results = await _connectivity.checkConnectivity();
    return _evaluateConnectivity(results);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _offlinePollingTimer?.cancel();
    super.dispose();
  }
}
