import '../../models/models.dart';

/// Contrato formal de dominio para lotes industriales (Batches) y transferencias logísticas.
/// Principio SOLID: Dependency Inversion Principle (DIP).
abstract class IBatchRepository {
  /// Obtiene los lotes del usuario/centro con filtrado por estado.
  Future<List<Batch>> getBatches({bool forceRefresh = false, String? status});

  /// Obtiene los lotes abiertos activos en tránsito o vehículo.
  Future<List<Batch>> getOpenBatches({String? centerId});

  /// Obtiene el detalle completo de un lote por su identificador.
  Future<Batch> getBatchDetail(String id, {bool forceRefresh = false});

  /// Despacha un lote hacia un centro de acopio específico.
  Future<Batch> dispatchBatch(String batchId, String centerId);

  /// Recibe un lote en centro de acopio con verificación de pesos reales y calibración.
  Future<Map<String, dynamic>> receiveBatch(
    String batchId,
    Map<String, double> materialsActual,
  );

  /// Consolida múltiples sub-lotes en un único lote maestro consolidado.
  Future<Map<String, dynamic>> consolidateBatches(List<String> batchIds);
}
