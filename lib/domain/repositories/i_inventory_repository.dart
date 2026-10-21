import '../../models/models.dart';

/// Contrato formal de dominio para kárdex, stock y movimientos B2B de centros de acopio.
/// Principio SOLID: Dependency Inversion Principle (DIP).
abstract class IInventoryRepository {
  /// Obtiene la lista de materiales en inventario para el centro de acopio.
  Future<List<InventoryItem>> getInventory(String centerId, {bool forceRefresh = false});

  /// Obtiene las transferencias B2B hacia transformadores o industrias.
  Future<List<B2bTransfer>> getB2bTransfers();

  /// Confirma y acepta una transferencia B2B entrante.
  Future<void> acceptTransfer(
    String transferId, {
    required Map<String, double> actualMaterials,
    String? notes,
  });

  /// Registra un movimiento de stock (salida, merma o ajuste).
  Future<void> createMovement({
    required String type,
    required String materialType,
    required double quantityKg,
  });

  /// Obtiene los movimientos históricos de inventario para un material específico.
  Future<List<InventoryMovement>> getMovements({
    required String materialType,
    int page = 1,
    int limit = 20,
  });
}
