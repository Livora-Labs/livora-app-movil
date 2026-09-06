import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/api_client.dart';

/// Eventos que emite el gateway de Socket.IO del backend.
///
/// El servidor mete al socket en sus salas automáticamente según el rol que
/// lee de PostgreSQL: `user:<id>` para todos, más `collectors:active` para
/// RECOLECTOR, `center:<id>` para CENTRO_ACOPIO y `store:<id>` para
/// TIENDA. El cliente no emite ningún `join`.
class RealtimeEvents {
  const RealtimeEvents._();

  /// Ack de autenticación: `{userId, role}`.
  static const connected = 'connected';

  /// Un hogar creó una solicitud. Llega a la sala `collectors:active`.
  static const collectionCreated = 'collection:created';

  /// Un lote terminó de procesarse. Llega a la sala `center:<id>`.
  static const batchCompleted = 'batch:completed';

  /// Un canje POS fue completado por un usuario. Llega a la sala `store:<id>`.
  static const redemptionCompleted = 'redemption:completed';
}

/// Conexión en tiempo real con el backend (Socket.IO sobre el mismo host de
/// la API). Sustituye al polling: el recolector ve las solicitudes aparecer
/// solas y el centro se entera de los lotes sin refrescar.
class LivoraRealtime extends ChangeNotifier {
  LivoraRealtime(this._api);

  final ApiClient _api;

  io.Socket? _socket;
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  bool _connected = false;
  String? _role;
  String? _userId;

  bool get isConnected => _connected;

  /// Rol confirmado por el servidor en el ack `connected`. Es la fuente de
  /// verdad de a qué salas quedó suscrito este dispositivo.
  String? get role => _role;

  String? get userId => _userId;

  /// Escucha un evento del servidor. El stream es broadcast: varias pantallas
  /// pueden suscribirse al mismo evento sin pisarse.
  Stream<Map<String, dynamic>> on(String event) => _controllers
      .putIfAbsent(
        event,
        () => StreamController<Map<String, dynamic>>.broadcast(),
      )
      .stream;

  /// Abre la conexión con el token de sesión actual. Es idempotente: si ya
  /// hay un socket vivo no hace nada.
  void connect() {
    if (_socket != null) return;
    final token = _api.authToken;
    if (token == null) return;

    final socket = io.io(
      _api.baseUrl,
      io.OptionBuilder()
          // Sin polling: el proxy HTTPS del backend soporta el upgrade directo
          // a WebSocket y así evitamos el handshake doble.
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _connected = true;
      notifyListeners();
    });

    // El servidor confirma la autenticación y el rol con el que asignó salas.
    socket.on(RealtimeEvents.connected, (data) {
      if (data is Map) {
        _userId = data['userId'] as String?;
        _role = data['role'] as String?;
        notifyListeners();
      }
      _emit(RealtimeEvents.connected, data);
    });

    socket.on(RealtimeEvents.collectionCreated,
        (data) => _emit(RealtimeEvents.collectionCreated, data));
    socket.on(RealtimeEvents.batchCompleted,
        (data) => _emit(RealtimeEvents.batchCompleted, data));
    socket.on(RealtimeEvents.redemptionCompleted,
        (data) => _emit(RealtimeEvents.redemptionCompleted, data));

    // El token vive 1 h; al reconectar hay que mandar el vigente, no el que
    // se usó en el primer handshake, o el servidor rechazaría la reconexión.
    socket.onReconnectAttempt((_) {
      final current = _api.authToken;
      if (current != null) socket.auth = {'token': current};
    });

    socket.onDisconnect((_) {
      _connected = false;
      notifyListeners();
    });

    socket.connect();
  }

  void _emit(String event, dynamic data) {
    if (data is! Map) return;
    _controllers[event]?.add(Map<String, dynamic>.from(data));
  }

  /// Cierra la conexión (logout o salida de la zona autenticada).
  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _role = null;
    _userId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _socket = null;
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    super.dispose();
  }
}
