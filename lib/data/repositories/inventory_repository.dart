import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../local/app_local_cache.dart';

/// Repositorio desacoplado para el Kárdex, stock y despachos B2B de Centros de Acopio.
/// Soporta persistencia Hive Cache-First para operación continua sin cobertura.
class InventoryRepository {
  final LivoraApi _api;

  InventoryRepository(this._api);

  /// Obtiene los ítems del inventario actual con cache SWR.
  Future<List<InventoryItem>> getInventory(String centerId, {bool forceRefresh = false}) async {
    final cached = AppLocalCache.getInventory(centerId);
    if (cached != null && !forceRefresh) {
      _api.inventory().then((fresh) {
        AppLocalCache.putInventory(centerId, fresh.map((e) => e.toJson()).toList());
      }).catchError((_) {});
      return cached.map((e) => InventoryItem.fromJson(e)).toList();
    }

    try {
      final items = await _api.inventory();
      await AppLocalCache.putInventory(centerId, items.map((e) => e.toJson()).toList());
      return items;
    } catch (e) {
      if (cached != null) {
        return cached.map((e) => InventoryItem.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  /// Obtiene las transferencias B2B hacia transformadores o industrias.
  Future<List<B2bTransfer>> getB2bTransfers() {
    return _api.fetchB2bTransfers();
  }

  /// Confirma y acepta una transferencia B2B entrante.
  Future<void> acceptTransfer(String transferId, {
    required Map<String, double> actualMaterials,
    String? notes,
  }) {
    final list = actualMaterials.entries
        .map((e) => {'materialType': e.key, 'quantityKg': e.value})
        .toList();
    return _api.acceptB2bTransfer(
      id: transferId,
      actualMaterials: list,
      notes: notes,
    );
  }

  /// Registra un movimiento de salida o merma en el inventario.
  Future<void> createMovement({
    required String type,
    required String materialType,
    required double quantityKg,
  }) {
    return _api.createInventoryMovement(
      type: type,
      materialType: materialType,
      quantityKg: quantityKg,
    );
  }

  /// Obtiene los movimientos paginados de inventario.
  Future<List<InventoryMovement>> getMovements({
    required String materialType,
    int page = 1,
    int limit = 20,
  }) {
    return _api.fetchInventoryMovements(
      materialType: materialType,
      page: page,
      limit: limit,
    );
  }
}
