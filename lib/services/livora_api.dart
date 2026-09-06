import 'dart:io';

import '../core/api_client.dart';
import '../core/media_compressor.dart';
import '../models/models.dart';

/// Métodos tipados para cada endpoint del backend Livora.
class LivoraApi {
  LivoraApi(this.client);

  final ApiClient client;

  List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      final list = raw['data'] as List;
      return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
    }
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  // ---------------------------------------------------------------- Hogar

  Future<CollectionRequest> createCollectionRequest({
    required Map<String, double> itemsEstimated,
    required double latitude,
    required double longitude,
    String assignmentMode = 'AUTOMATIC',
    String? description,
    String? photoUrl,
  }) async {
    final raw = await client.post('/collection-requests', body: {
      'itemsEstimated': itemsEstimated,
      'latitude': latitude,
      'longitude': longitude,
      'assignmentMode': assignmentMode,
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
    // Comprimir automáticamente imágenes antes de enviarlas a la API
    final originalFile = File(filePath);
    final processedFile = await MediaCompressor.compressImage(originalFile);

    final raw = await client.uploadFile(
      '/uploads',
      filePath: processedFile.path,
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
    String? status,
    int page = 1,
    int limit = 15,
  }) async {
    final raw = await client.get('/collection-requests', query: {
      'page': page,
      'limit': limit,
      if (status != null && status.isNotEmpty && status != 'TODAS')
        'status': status,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (radiusKm != null) 'radius': radiusKm,
    });
    return _list(raw, CollectionRequest.fromJson);
  }

  /// RECOLECTOR: Búsqueda radar GPS de solicitudes PENDING con filtros avanzados por acopio y lotes activos.
  Future<List<CollectionRequest>> availableCollectionRequests({
    required double lat,
    required double lng,
    double? radiusKm,
    String? centerId,
    bool? onlyActiveBatches,
  }) async {
    final raw = await client.get('/collection-requests/available', query: {
      'lat': lat,
      'lng': lng,
      if (radiusKm != null) 'radiusKm': radiusKm,
      if (centerId != null && centerId.isNotEmpty) 'centerId': centerId,
      if (onlyActiveBatches != null) 'onlyActiveBatches': onlyActiveBatches,
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

  Future<CollectionRequest> abandonCollectionRequest(
    String id, {
    String? reason,
  }) async {
    final raw = await client.post(
      '/collection-requests/$id/abandon',
      body: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  Future<CollectionRequest> verifyCollectionRequest(
    String id,
    String pin, {
    Map<String, double>? actualWeights,
  }) async {
    final raw = await client.post(
      '/collection-requests/$id/verify',
      body: {
        'pin': pin,
        if (actualWeights != null) 'actualWeights': actualWeights,
      },
    );
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  // --- Subastas y Tarifas Dinámicas ---

  Future<Map<String, dynamic>> submitBid(
    String requestId, {
    Map<String, double>? proposedRates,
  }) async {
    final raw = await client.post(
      '/collection-requests/$requestId/bids',
      body: {
        if (proposedRates != null) 'proposedRates': proposedRates,
      },
    );
    return raw as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> withdrawBid(String requestId, [String? bidId]) async {
    final path = bidId != null
        ? '/collection-requests/$requestId/bids/$bidId'
        : '/collection-requests/$requestId/bids';
    final raw = await client.delete(path);
    return raw as Map<String, dynamic>;
  }

  Future<CollectionRequest> selectBid(String requestId, String bidId) async {
    final raw = await client.post(
      '/collection-requests/$requestId/select-bid',
      body: {'bidId': bidId},
    );
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  Future<CollectionRequest> claimAutomatic(String requestId) async {
    final raw = await client.post('/collection-requests/$requestId/claim-automatic');
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  Future<List<AcopioPriceList>> fetchCenterPrices(String centerId) async {
    final raw = await client.get('/centers/$centerId/prices');
    if (raw is Map && raw['prices'] is List) {
      return _list(raw['prices'], AcopioPriceList.fromJson);
    }
    return [];
  }

  Future<List<AcopioPriceList>> updateMyPrices(List<Map<String, dynamic>> prices) async {
    final raw = await client.post('/centers/me/prices', body: {'prices': prices});
    if (raw is Map && raw['prices'] is List) {
      return _list(raw['prices'], AcopioPriceList.fromJson);
    }
    return [];
  }



  Future<HouseholdMetrics> householdMetrics() async {
    final raw = await client.get('/households/me/metrics');
    return HouseholdMetrics.fromJson(raw as Map<String, dynamic>);
  }

  // ----------------------------------------------------------- Recolector

  /// Devuelve los lotes OPEN del recolector (segmentados por Centro de Acopio).
  Future<List<Batch>> openBatches({String? centerId}) async {
    final raw = await client.get('/batches/open', query: {
      if (centerId != null && centerId.isNotEmpty) 'centerId': centerId,
    });
    if (raw is List) {
      return _list(raw, Batch.fromJson);
    } else if (raw is Map<String, dynamic>) {
      return [Batch.fromJson(raw)];
    }
    return [];
  }

  /// Retrocompatibilidad: Retorna el primer lote OPEN o uno vacío
  Future<Batch> openBatch({String? centerId}) async {
    final list = await openBatches(centerId: centerId);
    if (list.isNotEmpty) return list.first;
    return Batch(id: '', status: 'OPEN');
  }

  Future<List<Batch>> batches({String? status, int page = 1, int limit = 50}) async {
    final raw = await client.get('/batches', query: {
      'page': page,
      'limit': limit,
      'status': status,
    });
    return _list(raw, Batch.fromJson);
  }

  Future<Batch> batchDetail(String id) async {
    final raw = await client.get('/batches/$id');
    return Batch.fromJson(raw as Map<String, dynamic>);
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
  /// el procesamiento blockchain o FLAGGED_FOR_REVIEW si hay discrepancia.
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

  /// Autoriza y destraba un lote retenido en FLAGGED_FOR_REVIEW por discrepancia de peso.
  Future<Map<String, dynamic>> overrideBatchDiscrepancy(
    String batchId,
    String discrepancyNote,
  ) async {
    final raw = await client.post(
      '/batches/$batchId/override-discrepancy',
      body: {'discrepancyNote': discrepancyNote},
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

  /// Registra una venta B2B de un material con su peso, monto y empresa compradora.
  Future<Map<String, dynamic>> createSale({
    required String materialType,
    required double weightKg,
    required double totalAmount,
    required String buyerId,
    String? consolidatedBatchId,
  }) async {
    final raw = await client.post('/sales', body: {
      'materialType': materialType,
      'weightKg': weightKg,
      'totalAmount': totalAmount,
      'buyerId': buyerId,
      if (consolidatedBatchId != null && consolidatedBatchId.isNotEmpty)
        'consolidatedBatchId': consolidatedBatchId,
    });
    return raw is Map<String, dynamic> ? raw : {};
  }

  /// Obtiene la lista de empresas B2B verificadas.
  Future<List<B2bCompany>> fetchB2bCompanies() async {
    final raw = await client.get('/b2b-transfers/companies');
    return _list(raw, B2bCompany.fromJson);
  }

  // -------------------------------------------------- Inventario (tienda / acopio)

  Future<List<InventoryItem>> inventory() async {
    final raw = await client.get('/inventory');
    return _list(raw, InventoryItem.fromJson);
  }

  /// Obtiene el historial cronológico de movimientos de inventario.
  Future<List<InventoryMovement>> fetchInventoryMovements({
    String? materialType,
    int page = 1,
    int limit = 15,
  }) async {
    final raw = await client.get('/inventory/movements', query: {
      'page': page,
      'limit': limit,
      if (materialType != null && materialType.isNotEmpty)
        'materialType': materialType,
    });
    return _list(raw, InventoryMovement.fromJson);
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

  Future<List<WalletTransaction>> walletTransactions({
    int page = 1,
    int limit = 15,
    String? direction,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (direction != null && direction != 'TODAS') {
      query['direction'] = direction;
    }
    final raw = await client.get('/wallets/transactions/history', query: query);
    return _list(raw, WalletTransaction.fromJson);
  }

  Future<List<Map<String, dynamic>>> fetchAlliedStores() async {
    final raw = await client.get('/stores/allied');
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return [];
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

  Future<Map<String, dynamic>> confirmRedemption(
    String qrCodeRef, {
    bool termsAccepted = true,
  }) async {
    final raw = await client.post('/stores/redemptions/confirm/$qrCodeRef', body: {
      'termsAccepted': termsAccepted,
    });
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<Map<String, dynamic>> requestSettlement(double amount) async {
    final raw = await client.post('/stores/settlements', body: {
      'tokenAmount': amount,
    });
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<List<dynamic>> storeRedemptions({
    int page = 1,
    int limit = 15,
  }) async {
    final raw = await client.get('/stores/redemptions', query: {
      'page': page,
      'limit': limit,
    });
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      return raw['data'] as List;
    }
    return raw is List ? raw : [];
  }

  Future<List<dynamic>> storeSettlements({
    int page = 1,
    int limit = 15,
  }) async {
    final raw = await client.get('/stores/settlements/history', query: {
      'page': page,
      'limit': limit,
    });
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      return raw['data'] as List;
    }
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

  Future<Map<String, dynamic>> getDashboard() async {
    final raw = await client.get('/users/me/dashboard');
    return raw as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    bool? marketingAccepted,
  }) async {
    final raw = await client.patch('/users/me', body: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (marketingAccepted != null) 'marketingAccepted': marketingAccepted,
    });
    return raw as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changePassword(String newPassword) async {
    final raw = await client.patch('/users/me/password', body: {
      'newPassword': newPassword,
    });
    return raw as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getStoreProfile() async {
    try {
      final raw = await client.get('/stores/profile');
      return raw as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateStoreProfile({
    required String businessName,
    required String ruc,
    required String address,
    required String bankAccount,
  }) async {
    final raw = await client.patch('/stores/profile', body: {
      'businessName': businessName,
      'ruc': ruc,
      'address': address,
      'bankAccount': bankAccount,
    });
    return raw as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------- Niubiz Payments

  /// Crea una sesión de recarga Niubiz para rol HOGAR o RECOLECTOR.
  Future<Map<String, dynamic>> createPaymentSession({
    required double amount,
  }) async {
    final raw = await client.post('/payments/niubiz/session', body: {
      'amount': amount,
    });
    return raw as Map<String, dynamic>;
  }

  /// Confirma el pago enviando el transactionToken emitido por Niubiz.
  Future<Map<String, dynamic>> confirmPayment({
    required String purchaseNumber,
    required String transactionToken,
  }) async {
    final raw = await client.post('/payments/niubiz/confirm', body: {
      'purchaseNumber': purchaseNumber,
      'transactionToken': transactionToken,
    });
    return raw as Map<String, dynamic>;
  }

  /// Obtiene el historial de recargas fiduciarias del usuario móvil.
  Future<List<Map<String, dynamic>>> getPaymentTransactions() async {
    final raw = await client.get('/payments/me/transactions');
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  // ------------------------------------------------ Nuevas APIs Operativas

  /// Calificar un servicio de recolección completado (Hogar -> Recolector).
  Future<Map<String, dynamic>> rateCollectionRequest(
    String id, {
    required int rating,
    String? feedback,
  }) async {
    final raw = await client.post('/collection-requests/$id/rate', body: {
      'rating': rating,
      if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
    });
    return raw as Map<String, dynamic>;
  }

  /// Edición parcial de materiales y descripción de una solicitud en estado PENDING.
  /// Si ya fue aceptada, arroja ApiException con status 409.
  Future<CollectionRequest> editCollectionRequest(
    String id, {
    Map<String, dynamic>? itemsEstimated,
    String? description,
  }) async {
    final raw = await client.patch('/collection-requests/$id', body: {
      if (itemsEstimated != null) 'itemsEstimated': itemsEstimated,
      if (description != null) 'description': description,
    });
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  /// Anular canje en tienda dentro de las 24 horas y restituir EcoTokens al hogar.
  Future<Map<String, dynamic>> refundRedemption(String id) async {
    final raw = await client.post('/stores/redemptions/$id/refund');
    return raw as Map<String, dynamic>;
  }

  /// Registrar cierre de pago fiduciario en efectivo por el lote físico (Acopio -> Recolector).
  Future<Map<String, dynamic>> settleBatchFiat(String batchId) async {
    final raw = await client.post('/batches/$batchId/fiat-settlement');
    return raw as Map<String, dynamic>;
  }

  /// Impugnar pesaje de lote con discrepancia (Recolector -> Acopio / Admin).
  Future<Batch> disputeBatch(String batchId, String reason) async {
    final raw = await client.post('/batches/$batchId/dispute', body: {
      'reason': reason,
    });
    return Batch.fromJson(raw as Map<String, dynamic>);
  }

  /// Registrar DeviceToken de FCM en el backend para notificaciones push asíncronas.
  Future<Map<String, dynamic>> registerDeviceToken(
    String token, {
    String platform = 'ANDROID',
  }) async {
    final raw = await client.post('/users/me/device-tokens', body: {
      'token': token,
      'platform': platform,
    });
    return raw as Map<String, dynamic>;
  }
}
