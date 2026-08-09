import '../core/api_client.dart';
import '../models/models.dart';

/// Métodos tipados para cada endpoint del backend Livora.
class LivoraApi {
  LivoraApi(this.client);

  final ApiClient client;

  List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  // ---------------------------------------------------------------- Hogar

  Future<CollectionRequest> createCollectionRequest({
    required Map<String, double> itemsEstimated,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    final raw = await client.post('/collection-requests', body: {
      'itemsEstimated': itemsEstimated,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  /// HOGAR: sus propias solicitudes. RECOLECTOR: solicitudes PENDING
  /// (opcionalmente filtradas por cercanía con lat/lng/radius en km).
  Future<List<CollectionRequest>> collectionRequests({
    double? lat,
    double? lng,
    double? radiusKm,
    int page = 1,
    int limit = 50,
  }) async {
    final raw = await client.get('/collection-requests', query: {
      'page': page,
      'limit': limit,
      'lat': lat,
      'lng': lng,
      'radius': radiusKm,
    });
    return _list(raw, CollectionRequest.fromJson);
  }

  Future<CollectionRequest> collectionRequestDetail(String id) async {
    final raw = await client.get('/collection-requests/$id');
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  Future<CollectionRequest> updateCollectionStatus(
    String id,
    String status,
  ) async {
    final raw = await client.patch(
      '/collection-requests/$id',
      body: {'status': status},
    );
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  Future<HouseholdMetrics> householdMetrics() async {
    final raw = await client.get('/households/me/metrics');
    return HouseholdMetrics.fromJson(raw as Map<String, dynamic>);
  }

  // ----------------------------------------------------------- Recolector

  Future<Batch> openBatch() async {
    final raw = await client.get('/batches/open');
    return Batch.fromJson(raw as Map<String, dynamic>);
  }

  Future<List<Batch>> batches({String? status, int page = 1, int limit = 50}) async {
    final raw = await client.get('/batches', query: {
      'page': page,
      'limit': limit,
      'status': status,
    });
    return _list(raw, Batch.fromJson);
  }

  Future<Batch> sendBatchToCenter(String batchId, String centerId) async {
    final raw = await client.patch(
      '/batches/$batchId',
      body: {'destinationCenterId': centerId},
    );
    return Batch.fromJson(raw as Map<String, dynamic>);
  }

  Future<CollectorReputation> collectorReputation() async {
    final raw = await client.get('/collectors/me/reputation');
    return CollectorReputation.fromJson(raw as Map<String, dynamic>);
  }

  // ------------------------------------------------------ Centro de acopio

  /// Recepción con pesaje industrial. El backend responde HTTP 202 y encola
  /// el procesamiento blockchain.
  Future<Map<String, dynamic>> receiveBatch(
    String batchId,
    Map<String, double> materialsActual,
  ) async {
    final raw = await client.post(
      '/batches/$batchId/receive',
      body: {'materialsActual': materialsActual},
    );
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<Map<String, dynamic>> consolidateBatches(List<String> batchIds) async {
    final raw = await client.post(
      '/consolidated-batches',
      body: {'batchIds': batchIds},
    );
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<String> receptionPin() async {
    final raw = await client.get('/centers/me/reception-pin');
    return (raw as Map<String, dynamic>)['receptionPin'] as String? ?? '----';
  }

  Future<String> refreshReceptionPin() async {
    final raw = await client.post('/centers/me/reception-pin/refresh');
    return (raw as Map<String, dynamic>)['receptionPin'] as String? ?? '----';
  }

  Future<Map<String, dynamic>> createSale({
    required double weightKg,
    required double totalAmount,
    required String buyerId,
  }) async {
    final raw = await client.post('/sales', body: {
      'weightKg': weightKg,
      'totalAmount': totalAmount,
      'buyerId': buyerId,
    });
    return raw is Map<String, dynamic> ? raw : {};
  }

  // -------------------------------------------------- Inventario (tienda)

  Future<List<InventoryItem>> inventory() async {
    final raw = await client.get('/inventory');
    return _list(raw, InventoryItem.fromJson);
  }

  Future<void> createInventoryMovement({
    required String type,
    required String materialType,
    required double quantityKg,
  }) async {
    await client.post('/inventory/movements', body: {
      'type': type,
      'materialType': materialType,
      'quantityKg': quantityKg,
    });
  }

  // -------------------------------------------------------------- Wallet

  Future<String> walletBalance() async {
    final raw = await client.get('/wallets/me/balance');
    return (raw as Map<String, dynamic>)['balance']?.toString() ?? '0';
  }

  Future<Map<String, dynamic>> sendTokens({
    required String toAddress,
    required double amount,
  }) async {
    final raw = await client.post('/wallets/transactions', body: {
      'toAddress': toAddress,
      'amount': amount,
    });
    return raw is Map<String, dynamic> ? raw : {};
  }

  // ------------------------------------------------------- Notificaciones

  Future<List<AppNotification>> notifications({int page = 1, int limit = 50}) async {
    final raw = await client.get('/notifications', query: {
      'page': page,
      'limit': limit,
    });
    return _list(raw, AppNotification.fromJson);
  }

  Future<void> markNotification(String id, {required bool isRead}) async {
    await client.patch('/notifications/$id', body: {'isRead': isRead});
  }
}
