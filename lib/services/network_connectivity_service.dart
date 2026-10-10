import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/env_config.dart';

enum NetworkReachabilityState {
  online,
  offline,
  checking,
}

/// Comprueba si `host:port` es alcanzable dentro de `timeout`.
typedef ReachabilityProbe = Future<bool> Function(
  String host,
  int port,
  Duration timeout,
);

/// Sonda real por defecto: completa un handshake TCP.
Future<bool> _tcpProbe(String host, int port, Duration timeout) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    return true;
  } catch (_) {
    return false;
  } finally {
    // Siempre cerrar: un socket colgado filtra descriptores de archivo.
    socket?.destroy();
  }
}

/// Servicio centralizado de conectividad y accesibilidad real a internet para producción.
/// Valida no solo la interfaz de radio (WiFi/Celular) sino también la resolución y alcance real de red.
class NetworkConnectivityService extends ChangeNotifier {
  NetworkConnectivityService({
    Connectivity? connectivity,
    ReachabilityProbe? reachabilityProbe,
  })  : _connectivity = connectivity ?? Connectivity(),
        _reachabilityProbe = reachabilityProbe ?? _tcpProbe {
    _init();
  }

  final Connectivity _connectivity;

  /// Sonda de alcance real. Se inyecta en los tests para ejercitar la máquina
  /// de estados sin depender de la red.
  final ReachabilityProbe _reachabilityProbe;
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

  /// Prueba de alcance real: abre un socket TCP contra el backend.
  ///
  /// No sirve resolver una IP literal como `8.8.8.8`: `InternetAddress.lookup`
  /// la devuelve sin tocar la red (incluso en modo avión), así que daría
  /// "online" siempre. Tampoco basta el DNS del dominio, porque puede venir
  /// de la caché. Lo único concluyente es completar un handshake TCP.
  ///
  /// El fallback contra el DNS público de Google cubre el caso de que el
  /// backend esté caído pero el dispositivo sí tenga internet.
  Future<bool> _probeReachability() async {
    final host = Uri.parse(EnvConfig.apiBaseUrl).host;
    if (await _reachabilityProbe(host, 443, const Duration(seconds: 3))) {
      return true;
    }
    // 8.8.8.8:53 — aquí sí se conecta de verdad al puerto, no se resuelve.
    return _reachabilityProbe('8.8.8.8', 53, const Duration(milliseconds: 2500));
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
