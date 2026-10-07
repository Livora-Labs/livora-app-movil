import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Gestor de persistencia y caché local basado en Hive.
/// Implementa almacenamiento no-volátil de alto rendimiento (<10ms de lectura)
/// con soporte para TTL (Time-To-Live) y estrategia Cache-First con SWR.
class AppLocalCache {
  AppLocalCache._();

  static const String _requestsBoxName = 'cache_requests_v1';
  static const String _walletBoxName = 'cache_wallet_v1';
  static const String _metadataBoxName = 'cache_metadata_v1';
  static const String _batchesBoxName = 'cache_batches_v1';
  static const String _inventoryBoxName = 'cache_inventory_v1';
  static const String _auctionsBoxName = 'cache_auctions_v1';

  static Box? _requestsBox;
  static Box? _walletBox;
  static Box? _metadataBox;
  static Box? _batchesBox;
  static Box? _inventoryBox;
  static Box? _auctionsBox;

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Inicializa las cajas Hive si no están abiertas.
  static Future<void> init({
    Box? requestsBox,
    Box? walletBox,
    Box? metadataBox,
    Box? batchesBox,
    Box? inventoryBox,
    Box? auctionsBox,
  }) async {
    if (_isInitialized && requestsBox == null) return;

    try {
      _requestsBox = requestsBox ?? await Hive.openBox(_requestsBoxName);
      _walletBox = walletBox ?? await Hive.openBox(_walletBoxName);
      _metadataBox = metadataBox ?? await Hive.openBox(_metadataBoxName);
      _batchesBox = batchesBox ?? await Hive.openBox(_batchesBoxName);
      _inventoryBox = inventoryBox ?? await Hive.openBox(_inventoryBoxName);
      _auctionsBox = auctionsBox ?? await Hive.openBox(_auctionsBoxName);

      _isInitialized = true;
    } catch (e) {
      debugPrint('[AppLocalCache] Error inicializando Hive boxes: $e');
    }
  }

  // ------------------------------------------------------------- Solicitudes
  /// Guarda una solicitud de recolección en formato JSON crudo o serializado.
  static Future<void> putRequest(String id, Map<String, dynamic> rawJson) async {
    final box = _requestsBox;
    if (box == null || !box.isOpen) return;
    try {
      final entry = {
        'cachedAt': DateTime.now().toIso8601String(),
        'data': jsonEncode(rawJson),
      };
      await box.put(id, entry);
    } catch (e) {
      debugPrint('[AppLocalCache] Error guardando request $id: $e');
    }
  }

  /// Recupera una solicitud de recolección cacheada por su ID.
  static Map<String, dynamic>? getRequest(String id, {Duration maxAge = const Duration(days: 7)}) {
    final box = _requestsBox;
    if (box == null || !box.isOpen) return null;
    try {
      final raw = box.get(id);
      if (raw is! Map) return null;

      final cachedAtStr = raw['cachedAt'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          box.delete(id);
          return null;
        }
      }

      final dataStr = raw['data'] as String?;
      if (dataStr == null) return null;
      return jsonDecode(dataStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AppLocalCache] Error leyendo request $id: $e');
      return null;
    }
  }

  /// Guarda una lista de solicitudes (ej. dashboard o historial).
  static Future<void> putRequestList(String cacheKey, List<Map<String, dynamic>> list) async {
    final box = _requestsBox;
    if (box == null || !box.isOpen) return;
    try {
      final entry = {
        'cachedAt': DateTime.now().toIso8601String(),
        'items': jsonEncode(list),
      };
      await box.put('list_$cacheKey', entry);
    } catch (e) {
      debugPrint('[AppLocalCache] Error guardando lista $cacheKey: $e');
    }
  }

  /// Recupera una lista de solicitudes cacheadas.
  static List<Map<String, dynamic>>? getRequestList(String cacheKey, {Duration maxAge = const Duration(hours: 24)}) {
    final box = _requestsBox;
    if (box == null || !box.isOpen) return null;
    try {
      final raw = box.get('list_$cacheKey');
      if (raw is! Map) return null;

      final cachedAtStr = raw['cachedAt'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          return null;
        }
      }

      final itemsStr = raw['items'] as String?;
      if (itemsStr == null) return null;
      final decoded = jsonDecode(itemsStr);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[AppLocalCache] Error leyendo lista $cacheKey: $e');
      return null;
    }
  }

  // ------------------------------------------------------------- Billetera
  static Future<void> putWalletBalance(String role, String balance) async {
    final box = _walletBox;
    if (box == null || !box.isOpen) return;
    await box.put('bal_$role', {
      'cachedAt': DateTime.now().toIso8601String(),
      'value': balance,
    });
  }

  static String? getWalletBalance(String role) {
    final box = _walletBox;
    if (box == null || !box.isOpen) return null;
    final raw = box.get('bal_$role');
    if (raw is Map) {
      return raw['value'] as String?;
    }
    return null;
  }

  // ------------------------------------------------------------- Metadata / Genérico
  static Future<void> putString(String key, String value) async {
    final box = _metadataBox;
    if (box != null && box.isOpen) {
      await box.put(key, value);
    }
  }

  static String? getString(String key) {
    final box = _metadataBox;
    if (box != null && box.isOpen) {
      return box.get(key) as String?;
    }
    return null;
  }

  // ------------------------------------------------------------- Lotes (Batches)
  static Future<void> putBatch(String id, Map<String, dynamic> rawJson) async {
    final box = _batchesBox;
    if (box == null || !box.isOpen) return;
    try {
      await box.put(id, {
        'cachedAt': DateTime.now().toIso8601String(),
        'data': jsonEncode(rawJson),
      });
    } catch (e) {
      debugPrint('[AppLocalCache] Error guardando batch $id: $e');
    }
  }

  static Map<String, dynamic>? getBatch(String id, {Duration maxAge = const Duration(days: 7)}) {
    final box = _batchesBox;
    if (box == null || !box.isOpen) return null;
    try {
      final raw = box.get(id);
      if (raw is! Map) return null;
      final cachedAtStr = raw['cachedAt'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          box.delete(id);
          return null;
        }
      }
      final dataStr = raw['data'] as String?;
      if (dataStr == null) return null;
      return jsonDecode(dataStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> putBatchList(String key, List<Map<String, dynamic>> list) async {
    final box = _batchesBox;
    if (box == null || !box.isOpen) return;
    try {
      await box.put('list_$key', {
        'cachedAt': DateTime.now().toIso8601String(),
        'items': jsonEncode(list),
      });
    } catch (e) {
      debugPrint('[AppLocalCache] Error guardando batch list $key: $e');
    }
  }

  static List<Map<String, dynamic>>? getBatchList(String key, {Duration maxAge = const Duration(hours: 12)}) {
    final box = _batchesBox;
    if (box == null || !box.isOpen) return null;
    try {
      final raw = box.get('list_$key');
      if (raw is! Map) return null;
      final cachedAtStr = raw['cachedAt'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          return null;
        }
      }
      final itemsStr = raw['items'] as String?;
      if (itemsStr == null) return null;
      final decoded = jsonDecode(itemsStr);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- Inventario (Centro)
  static Future<void> putInventory(String centerId, List<Map<String, dynamic>> items) async {
    final box = _inventoryBox;
    if (box == null || !box.isOpen) return;
    try {
      await box.put('inv_$centerId', {
        'cachedAt': DateTime.now().toIso8601String(),
        'items': jsonEncode(items),
      });
    } catch (_) {}
  }

  static List<Map<String, dynamic>>? getInventory(String centerId, {Duration maxAge = const Duration(hours: 6)}) {
    final box = _inventoryBox;
    if (box == null || !box.isOpen) return null;
    try {
      final raw = box.get('inv_$centerId');
      if (raw is! Map) return null;
      final cachedAtStr = raw['cachedAt'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          return null;
        }
      }
      final itemsStr = raw['items'] as String?;
      if (itemsStr == null) return null;
      final decoded = jsonDecode(itemsStr);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- Subastas (Auctions)
  static Future<void> putAuctionBids(String requestId, List<Map<String, dynamic>> bids) async {
    final box = _auctionsBox;
    if (box == null || !box.isOpen) return;
    try {
      await box.put('bids_$requestId', {
        'cachedAt': DateTime.now().toIso8601String(),
        'items': jsonEncode(bids),
      });
    } catch (_) {}
  }

  static List<Map<String, dynamic>>? getAuctionBids(String requestId, {Duration maxAge = const Duration(minutes: 30)}) {
    final box = _auctionsBox;
    if (box == null || !box.isOpen) return null;
    try {
      final raw = box.get('bids_$requestId');
      if (raw is! Map) return null;
      final cachedAtStr = raw['cachedAt'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          return null;
        }
      }
      final itemsStr = raw['items'] as String?;
      if (itemsStr == null) return null;
      final decoded = jsonDecode(itemsStr);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return null;
    }
  }

  /// Purgar toda la caché local (por ejemplo en logout o cambio de usuario).
  static Future<void> clearAll() async {
    try {
      if (_requestsBox?.isOpen ?? false) await _requestsBox?.clear();
      if (_walletBox?.isOpen ?? false) await _walletBox?.clear();
      if (_metadataBox?.isOpen ?? false) await _metadataBox?.clear();
      if (_batchesBox?.isOpen ?? false) await _batchesBox?.clear();
      if (_inventoryBox?.isOpen ?? false) await _inventoryBox?.clear();
      if (_auctionsBox?.isOpen ?? false) await _auctionsBox?.clear();
    } catch (e) {
      debugPrint('[AppLocalCache] Error limpiando caché: $e');
    }
  }
}
