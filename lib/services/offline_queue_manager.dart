import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'livora_api.dart';

class OfflineQueueManager {
  OfflineQueueManager._();

  static const _boxName = 'offline_verifications';
  static late Box _box;
  static LivoraApi? _api;
  static bool _processing = false;

  /// Inicializa Hive y abre la caja de cola offline.
  static Future<void> init(LivoraApi api) async {
    _api = api;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);

    // Iniciar escucha de cambios en la red
    Connectivity().onConnectivityChanged.listen((results) {
      // Soporta firmas antiguas y nuevas de connectivity_plus (List vs Single)
      final hasNetwork = _hasNetworkConnection(results);
      if (hasNetwork) {
        processQueue();
      }
    });

    // Intentar procesar cualquier cola pendiente al iniciar
    processQueue();
  }

  static bool _hasNetworkConnection(dynamic results) {
    if (results is List<ConnectivityResult>) {
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      return results != ConnectivityResult.none;
    }
    return false;
  }

  /// Agrega una verificación de PIN a la cola offline.
  static Future<void> enqueueVerification(String requestId, String pin) async {
    final entry = {
      'requestId': requestId,
      'pin': pin,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _box.put(requestId, jsonEncode(entry));
    debugPrint('[OfflineQueue] Encolada verificación para la petición $requestId');
    
    // Intentar sincronizar de inmediato
    processQueue();
  }

  /// Retorna si hay peticiones pendientes en la cola.
  static bool get hasPendingRequests => _box.isNotEmpty;

  /// Retorna la cantidad de peticiones pendientes en la cola.
  static int get pendingCount => _box.length;

  /// Procesa las peticiones encoladas en background.
  static Future<void> processQueue() async {
    if (_processing || _api == null || _box.isEmpty) return;
    _processing = true;

    // Verificar si hay conexión activa antes de iniciar
    final connectivity = await Connectivity().checkConnectivity();
    if (!_hasNetworkConnection(connectivity)) {
      _processing = false;
      return;
    }

    debugPrint('[OfflineQueue] Iniciando sincronización de cola offline (${_box.length} elementos)...');

    final keys = List.from(_box.keys);
    for (final key in keys) {
      final rawData = _box.get(key);
      if (rawData == null) continue;

      try {
        final data = jsonDecode(rawData as String) as Map<String, dynamic>;
        final requestId = data['requestId'] as String;
        final pin = data['pin'] as String;

        debugPrint('[OfflineQueue] Sincronizando petición $requestId...');
        await _api!.verifyCollectionRequest(requestId, pin);
        
        // Si tiene éxito, eliminar de la cola
        await _box.delete(key);
        debugPrint('[OfflineQueue] ✅ Sincronización exitosa para $requestId');
      } catch (error) {
        debugPrint('[OfflineQueue] ❌ Error sincronizando elemento $key: $error');
        // Si es un error de conexión, pausamos y reintentamos en el siguiente cambio de red.
        // Si es un error lógico (PIN incorrecto, etc.), se puede optar por descartar o dejarlo en la cola.
        // Para este MVP, si es error de red pausamos, si es lógico descartamos para no bloquear la cola.
        final errStr = error.toString().toLowerCase();
        if (errStr.contains('connect') || errStr.contains('socket') || errStr.contains('servidor no respondió')) {
          break; // Pausar cola temporalmente
        } else {
          await _box.delete(key); // Descartar error lógico
        }
      }
    }

    _processing = false;
  }
}
