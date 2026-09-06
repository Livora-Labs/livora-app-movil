import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/api_client.dart';
import 'livora_api.dart';

/// Motor de sincronización offline para confirmaciones de recolección en campo.
/// Implementa un patrón Store & Forward reactivo, resiliente y atómico.
class OfflineQueueManager {
  OfflineQueueManager._();

  static const _boxName = 'offline_verifications';
  static late Box _box;
  static LivoraApi? _api;
  static bool _processing = false;

  /// Notificador reactivo en tiempo real con el conteo de elementos pendientes en la cola.
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  /// Getter público para escuchar el conteo de elementos pendientes en widgets.
  static ValueListenable<int> get pendingListenable => pendingCountNotifier;

  /// Retorna si hay peticiones pendientes en la cola.
  static bool get hasPendingRequests => Hive.isBoxOpen(_boxName) && _box.isNotEmpty;

  /// Retorna la cantidad de peticiones pendientes en la cola.
  static int get pendingCount => Hive.isBoxOpen(_boxName) ? _box.length : 0;

  /// Actualiza el estado del ValueNotifier con el conteo actual de Hive.
  static void _updatePendingCount() {
    if (Hive.isBoxOpen(_boxName)) {
      pendingCountNotifier.value = _box.length;
    } else {
      pendingCountNotifier.value = 0;
    }
  }

  /// Inicializa Hive, abre la caja y configura la escucha reactiva de red.
  static Future<void> init(LivoraApi api, {Box? box}) async {
    _api = api;
    if (box != null) {
      _box = box;
    } else {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
    }

    _updatePendingCount();

    // Iniciar escucha de cambios en la conectividad del dispositivo
    Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = _hasNetworkConnection(results);
      if (hasNetwork) {
        processQueue();
      }
    });

    // Intentar sincronizar elementos pendientes acumulados al inicio
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

  /// Agrega una verificación de PIN a la cola offline con timestamp de creación y pesos reales opcionales.
  static Future<void> enqueueVerification(
    String requestId,
    String pin, {
    Map<String, double>? actualWeights,
  }) async {
    final now = DateTime.now();
    final entry = {
      'requestId': requestId,
      'pin': pin,
      if (actualWeights != null && actualWeights.isNotEmpty)
        'actualWeights': actualWeights,
      'createdAt': now.toIso8601String(),
    };

    await _box.put(requestId, jsonEncode(entry));
    _updatePendingCount();
    debugPrint('[OfflineQueue] Encolada verificación para la petición $requestId (Total pendientes: ${_box.length})');

    // Intentar sincronización inmediata
    await processQueue();
  }

  /// Purga completa de la cola offline (usado en logout y cumplimiento ARCO).
  static Future<void> clearQueue() async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        await box.clear();
      }
    } catch (e) {
      debugPrint('[OfflineQueue] Error al limpiar base de datos local Hive: $e');
    } finally {
      pendingCountNotifier.value = 0;
    }
  }

  /// Procesa las peticiones encoladas secuencialmente (FIFO) con Mutex atómico y TTL.
  static Future<void> processQueue() async {
    // Candado atómico (Mutex): si ya se está ejecutando o no hay elementos, salir
    if (_processing || _api == null || !Hive.isBoxOpen(_boxName)) {
      return;
    }
    _processing = true;

    try {
      // Verificar si hay conexión activa antes de realizar peticiones de red
      final connectivity = await Connectivity().checkConnectivity();
      if (!_hasNetworkConnection(connectivity)) {
        debugPrint('[OfflineQueue] Sin conexión de red. Sincronización aplazada.');
        return;
      }

      debugPrint('[OfflineQueue] Iniciando sincronización de cola offline (${_box.length} elementos)...');

      // Leer y estructurar entradas para garantizar orden secuencial FIFO
      final entries = <Map<String, dynamic>>[];
      for (final key in _box.keys) {
        final rawData = _box.get(key);
        if (rawData == null) continue;

        try {
          final data = jsonDecode(rawData as String) as Map<String, dynamic>;
          data['_hiveKey'] = key;
          entries.add(data);
        } catch (_) {
          // Si el registro está corrupto, eliminar de inmediato
          if (Hive.isBoxOpen(_boxName) && _box.isOpen) {
            await _box.delete(key);
          }
        }
      }

      // Ordenar cronológicamente por createdAt / timestamp ascendente (FIFO estricto)
      entries.sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt'] ?? a['timestamp'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['createdAt'] ?? b['timestamp'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

      final now = DateTime.now();
      const ttl = Duration(hours: 24);

      for (final entry in entries) {
        final key = entry['_hiveKey'];
        final requestId = entry['requestId'] as String?;
        final pin = entry['pin'] as String?;
        final rawWeights = entry['actualWeights'];
        final createdAtStr = entry['createdAt'] ?? entry['timestamp'];
        final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr as String) : null;

        if (requestId == null || pin == null) {
          if (key != null && Hive.isBoxOpen(_boxName) && _box.isOpen) {
            await _box.delete(key);
          }
          _updatePendingCount();
          continue;
        }

        // Validación de Expiración TTL (24 horas)
        if (createdAt != null && now.difference(createdAt) > ttl) {
          debugPrint('[OfflineQueue] [WARN] Registro $requestId superó el TTL (>24h). Descartando de Hive...');
          if (key != null && Hive.isBoxOpen(_boxName) && _box.isOpen) {
            await _box.delete(key);
          }
          _updatePendingCount();
          await Sentry.captureMessage(
            'Verificación offline expirada (>24h TTL) para la solicitud $requestId',
            level: SentryLevel.warning,
          );
          continue; // Procesar el siguiente elemento sin detener la cola
        }

        Map<String, double>? actualWeights;
        if (rawWeights is Map) {
          actualWeights = {};
          rawWeights.forEach((k, v) {
            final parsed = (v is num) ? v.toDouble() : double.tryParse('$v');
            if (parsed != null && parsed > 0) {
              actualWeights!['$k'] = parsed;
            }
          });
        }

        try {
          debugPrint('[OfflineQueue] Sincronizando petición $requestId...');
          await _api!.verifyCollectionRequest(
            requestId,
            pin,
            actualWeights: actualWeights != null && actualWeights.isNotEmpty
                ? actualWeights
                : null,
          );

          // Éxito: eliminar de la cola y actualizar contador
          if (key != null && Hive.isBoxOpen(_boxName) && _box.isOpen) {
            await _box.delete(key);
          }
          _updatePendingCount();
          debugPrint('[OfflineQueue] [OK] Sincronización exitosa para $requestId');
        } on ApiException catch (apiError) {
          final statusCode = apiError.statusCode;
          debugPrint('[OfflineQueue] Error API ($statusCode) en $requestId: ${apiError.message}');

          // Errores lógicos de cliente / negocio (HTTP 4xx excepto 429 rate limit)
          if (statusCode != null && statusCode >= 400 && statusCode < 500 && !apiError.isRateLimited) {
            debugPrint('[OfflineQueue] [ERROR] Error de negocio ($statusCode). Descartando de la cola para evitar bloqueo...');
            if (key != null && Hive.isBoxOpen(_boxName) && _box.isOpen) {
              await _box.delete(key);
            }
            _updatePendingCount();
            await Sentry.captureMessage(
              'Error de negocio en verificación offline ($statusCode): ${apiError.message} para solicitud $requestId',
              level: SentryLevel.error,
            );
          } else {
            // Error de servidor (HTTP 5xx), rate limit o conectividad
            debugPrint('[OfflineQueue] [PAUSE] Error de red o servidor ($statusCode). Pausando cola.');
            break; // Pausar cola para el siguiente ciclo
          }
        } catch (genericError) {
          debugPrint('[OfflineQueue] [ERROR] Excepción no controlada en $requestId: $genericError');
          final errStr = genericError.toString().toLowerCase();
          if (errStr.contains('connect') ||
              errStr.contains('socket') ||
              errStr.contains('timeout') ||
              errStr.contains('servidor no respondió') ||
              errStr.contains('network')) {
            debugPrint('[OfflineQueue] [PAUSE] Error de transporte detectado. Pausando cola temporalmente.');
            break;
          } else {
            // Error irrecuperable: purgar registro y capturar excepción en Sentry
            if (key != null && Hive.isBoxOpen(_boxName) && _box.isOpen) {
              await _box.delete(key);
            }
            _updatePendingCount();
            await Sentry.captureException(genericError);
          }
        }
      }
    } finally {
      _processing = false;
      _updatePendingCount();
    }
  }
}
