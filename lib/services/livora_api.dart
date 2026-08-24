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
    String? photoUrl,
  }) async {
    final raw = await client.post('/collection-requests', body: {
      'itemsEstimated': itemsEstimated,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  // -------------------------------------------------------------- Archivos

  /// Sube un archivo a `POST /uploads` y devuelve su URL pública.
  ///
  /// `purpose` decide bucket y tipos aceptados en el backend:
  /// `collection` (jpeg/png), `kyc` (jpeg/png/pdf) y `receipt`. Máximo 10 MB.
  Future<String> uploadFile({
    required String filePath,
    required String purpose,
  }) async {
    final raw = await client.uploadFile(
      '/uploads',
      filePath: filePath,
      fieldName: 'file',
      fields: {'purpose': purpose},
    );
    final url = (raw is Map<String, dynamic>) ? raw['url'] as String? : null;
    if (url == null || url.isEmpty) {
      throw ApiException('El servidor no devolvió la URL del archivo subido');
    }
    return url;
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

  Future<CollectionRequest> verifyCollectionRequest(
    String id,
    String pin,
  ) async {
    final raw = await client.post(
      '/collection-requests/$id/verify',
      body: {'pin': pin},
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

  /// Estado actual de la verificación KYC del recolector.
  Future<KycApplication> kycApplication() async {
    final raw = await client.get('/collectors/me/kyc-application');
    return KycApplication.fromJson(raw as Map<String, dynamic>);
  }

  /// Envía la solicitud de verificación KYC del recolector con la URL del
  /// documento ya subido a `/uploads` (`purpose: kyc`).
  Future<void> submitKycApplication(String documentUrl) async {
    await client.post(
      '/collectors/kyc-applications',
      body: {'documentUrl': documentUrl},
    );
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

  // ---------------------------------------------------------------- Tienda

  Future<Map<String, dynamic>> generateQrRedemption(double amount) async {
    final raw = await client.post('/stores/redemptions/qr', body: {
      'tokenAmount': amount,
    });
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<Map<String, dynamic>> redemptionDetails(String qrCodeRef) async {
    final raw = await client.get('/stores/redemptions/$qrCodeRef');
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<Map<String, dynamic>> confirmRedemption(String qrCodeRef) async {
    final raw = await client.post('/stores/redemptions/confirm/$qrCodeRef');
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<Map<String, dynamic>> requestSettlement(double amount) async {
    final raw = await client.post('/stores/settlements', body: {
      'tokenAmount': amount,
    });
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<List<dynamic>> storeRedemptions() async {
    final raw = await client.get('/stores/redemptions');
    return raw is List ? raw : [];
  }

  Future<List<dynamic>> storeSettlements() async {
    final raw = await client.get('/stores/settlements/history');
    return raw is List ? raw : [];
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

  Future<void> updateFcmToken(String fcmToken) async {
    await client.patch('/users/fcm-token', body: {'fcmToken': fcmToken});
  }

  Future<void> deleteAccount() async {
    await client.delete('/users/me');
  }
}
