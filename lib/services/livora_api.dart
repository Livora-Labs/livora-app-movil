import 'dart:io';

import 'package:flutter/foundation.dart';

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

  // ---------------------------------------------------------------- Usuario

  /// Obtiene los datos actualizados del perfil de usuario autenticado.
  Future<AuthUser> getMe() async {
    final raw = await client.get('/users/me');
    return AuthUser.fromJson(raw as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------- Hogar

  Future<CollectionRequest> createCollectionRequest({
    required Map<String, double> itemsEstimated,
    required double latitude,
    required double longitude,
    String assignmentMode = 'AUTOMATIC',
    String? address,
    String? description,
    String? photoUrl,
    bool isDonation = false,
  }) async {
    final raw = await client.post('/collection-requests', body: {
      'itemsEstimated': itemsEstimated,
      'latitude': latitude,
      'longitude': longitude,
      'assignmentMode': assignmentMode,
      'isDonation': isDonation,
      if (address != null && address.isNotEmpty) 'address': address,
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

  Future<CollectionRequest> startRoute(String id) async {
    final raw = await client.post('/collection-requests/$id/start-route');
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  Future<CollectionRequest> reachDestination(String id) async {
    final raw = await client.post('/collection-requests/$id/reach-destination');
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  /// Confirmar llegada al domicilio (alias oficial PATCH /arrival)
  Future<CollectionRequest> confirmArrival(String id) async {
    final raw = await client.patch('/collection-requests/$id/arrival');
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  /// Despacha telemetría GPS periódica hacia PATCH /collection-requests/:id/location
  Future<Map<String, dynamic>> updateCollectorLocation(
    String id, {
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
    int? timestamp,
    double? distanceRemainingMeters,
    double? etaMinutes,
    String? transportType,
  }) async {
    final raw = await client.patch(
      '/collection-requests/$id/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        if (accuracy != null) 'accuracy': accuracy,
        if (timestamp != null) 'timestamp': timestamp,
        if (distanceRemainingMeters != null)
          'distanceRemainingMeters': distanceRemainingMeters,
        if (etaMinutes != null) 'etaMinutes': etaMinutes,
        if (transportType != null) 'transportType': transportType,
      },
    );
    return raw as Map<String, dynamic>;
  }

  /// Consulta al proxy OSRM backend para trazar ruta A->B y obtener ETA
  Future<Map<String, dynamic>> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String profile = 'driving',
  }) async {
    final raw = await client.post(
      '/routing/route',
      body: {
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destLat,
        'destLng': destLng,
        'profile': profile,
      },
    );
    return raw as Map<String, dynamic>;
  }

  /// Búsqueda predictiva de direcciones (Forward Geocoding) a través del backend seguro
  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    final raw = await client.get(
      '/routing/geocode/search',
      query: {'q': query},
    );
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Geocodificación inversa (LatLng -> Dirección) a través del backend seguro
  Future<String?> reverseGeocode(double lat, double lng) async {
    final raw = await client.get(
      '/routing/geocode/reverse',
      query: {
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
    );
    if (raw is Map && raw['address'] != null) {
      return raw['address'].toString();
    }
    return null;
  }

  /// Optimización de ruta multi-parada (VRP / TSP) para ordenar un lote de solicitudes
  Future<Map<String, dynamic>> optimizeTrip({
    required double collectorLat,
    required double collectorLng,
    required List<Map<String, dynamic>> waypoints,
    String profile = 'driving',
  }) async {
    final raw = await client.post(
      '/routing/optimize-trip',
      body: {
        'collectorLat': collectorLat,
        'collectorLng': collectorLng,
        'waypoints': waypoints,
        'profile': profile,
      },
    );
    return raw as Map<String, dynamic>;
  }

  Future<CollectionRequest> reportNoShow(String id) async {
    final raw = await client.post('/collection-requests/$id/no-show');
    return CollectionRequest.fromJson(raw as Map<String, dynamic>);
  }

  Future<CollectionRequest> rejectOnSite(
    String id,
    String reason, [
    List<String>? photoUrls,
  ]) async {
    final raw = await client.post(
      '/collection-requests/$id/reject-on-site',
      body: {
        'reason': reason,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
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

  Future<Batch> rerouteBatch(
    String batchId,
    String newCenterId, {
    String? reason,
    String? proofPhotoUrl,
  }) async {
    final raw = await client.post(
      '/batches/$batchId/reroute',
      body: {
        'newCenterId': newCenterId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (proofPhotoUrl != null && proofPhotoUrl.isNotEmpty)
          'proofPhotoUrl': proofPhotoUrl,
      },
    );
    return Batch.fromJson(raw as Map<String, dynamic>);
  }

  /// Envía la solicitud de verificación KYC del recolector con la URL del
  /// documento y la selfie/foto de perfil obligatoria.
  Future<void> submitKycApplication(
    String documentUrl, {
    String? selfieUrl,
    String? documentUrlBack,
    String? documentNumber,
    String? transportType,
    String? vehiclePlate,
  }) async {
    await client.post(
      '/collectors/kyc-applications',
      body: {
        'documentUrl': documentUrl,
        if (selfieUrl != null && selfieUrl.isNotEmpty) 'selfieUrl': selfieUrl,
        if (documentUrlBack != null && documentUrlBack.isNotEmpty)
          'documentUrlBack': documentUrlBack,
        if (documentNumber != null && documentNumber.isNotEmpty)
          'documentNumber': documentNumber,
        if (transportType != null && transportType.isNotEmpty)
          'transportType': transportType,
        if (vehiclePlate != null && vehiclePlate.isNotEmpty)
          'vehiclePlate': vehiclePlate,
      },
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

  /// Obtiene el historial de transferencias/despachos B2B a industrias.
  Future<List<B2bTransfer>> fetchB2bTransfers({String? status, int page = 1, int limit = 50}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) query['status'] = status;
    final raw = await client.get('/b2b-transfers', query: query);
    if (raw is Map<String, dynamic> && raw['transfers'] is List) {
      return (raw['transfers'] as List)
          .map((x) => B2bTransfer.fromJson(x as Map<String, dynamic>))
          .toList();
    }
    return _list(raw, B2bTransfer.fromJson);
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
    try {
      final raw = await client.get('/stores/redemptions', query: {
        'page': page,
        'limit': limit,
      });
      if (raw is Map<String, dynamic> && raw['data'] is List) {
        return raw['data'] as List;
      }
      return raw is List ? raw : [];
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<List<dynamic>> storeSettlements({
    int page = 1,
    int limit = 15,
  }) async {
    try {
      final raw = await client.get('/stores/settlements/history', query: {
        'page': page,
        'limit': limit,
      });
      if (raw is Map<String, dynamic> && raw['data'] is List) {
        return raw['data'] as List;
      }
      return raw is List ? raw : [];
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
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

  Future<void> unregisterDeviceToken([String? token]) async {
    try {
      await client.delete('/users/me/device-tokens', query: {
        if (token != null && token.isNotEmpty) 'token': token,
      });
    } catch (_) {
      // Best effort on logout
    }
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

  Future<Map<String, dynamic>> changePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    final raw = await client.patch('/users/me/password', body: {
      'newPassword': newPassword,
      if (currentPassword != null && currentPassword.isNotEmpty)
        'currentPassword': currentPassword,
    });
    return raw as Map<String, dynamic>;
  }

  /// Solicita un correo de recuperación de contraseña con enlace web para el usuario.
  Future<void> forgotPassword(String email) async {
    await client.post('/auth/forgot-password', body: {'email': email});
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
    String? logoUrl,
  }) async {
    final sanitizedBank = bankAccount.trim().isNotEmpty
        ? bankAccount.trim()
        : 'PENDIENTE_REGISTRO';

    final raw = await client.patch('/stores/profile', body: {
      'businessName': businessName,
      'ruc': ruc,
      'address': address,
      'bankAccount': sanitizedBank,
      if (logoUrl != null) 'logoUrl': logoUrl,
    });
    return raw as Map<String, dynamic>;
  }

  /// Envía la solicitud de afiliación comercial y verificación KYC para la Tienda.
  Future<void> submitStoreKycApplication({
    required String businessName,
    required String ruc,
    required String address,
    required String documentUrl,
    String? bankCci,
    double? latitude,
    double? longitude,
    String? phone,
  }) async {
    // 1. Persistir perfil comercial (RUC, razón social, dirección, logo/fachada, cuenta bancaria)
    await updateStoreProfile(
      businessName: businessName,
      ruc: ruc,
      address: address,
      bankAccount: (bankCci != null && bankCci.trim().isNotEmpty) ? bankCci.trim() : '',
      logoUrl: documentUrl,
    );

    // 2. Sincronizar datos de usuario (contacto y georreferenciación)
    if (phone != null || latitude != null || longitude != null) {
      await updateProfile(
        name: businessName,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
      ).catchError((_) => <String, dynamic>{});
    }

    // 3. Registrar expediente formal de KYC para revisión del Administrador
    try {
      await client.post(
        '/collectors/kyc-applications',
        body: {
          'documentUrl': documentUrl,
          'taxIdRuc': ruc,
          'businessName': businessName,
          if (bankCci != null && bankCci.isNotEmpty) 'bankCci': bankCci,
          'documentNumber': ruc,
        },
      );
    } catch (e) {
      // El perfil comercial y las coordenadas ya quedaron debidamente persistidos en los pasos 1 y 2.
      debugPrint('[LivoraApi] Aviso en registro KYC directo: $e');
    }
  }

  // ---------------------------------------------------------------- Izipay Payments

  /// Crea una sesión de recarga Izipay (Krypton V4) para rol RECOLECTOR o TIENDA.
  Future<Map<String, dynamic>> createPaymentSession({
    required double amount,
  }) async {
    final raw = await client.post('/payments/izipay/session', body: {
      'amount': amount,
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

  /// Envía una reclamación al Libro de Reclamaciones Virtual (Ley 29571 / Ley 32495).
  Future<Map<String, dynamic>> createComplaint({
    required String documentType,
    required String documentNumber,
    required String fullName,
    required String address,
    required String phone,
    required String email,
    bool isMinor = false,
    String? representativeName,
    String? representativeDoc,
    required String goodType,
    required String goodDescription,
    double? amount,
    required String claimType,
    required String claimDetail,
    required String consumerRequest,
  }) async {
    final raw = await client.post('/complaints', body: {
      'documentType': documentType,
      'documentNumber': documentNumber,
      'fullName': fullName,
      'address': address,
      'phone': phone,
      'email': email,
      'isMinor': isMinor,
      if (representativeName != null && representativeName.isNotEmpty)
        'representativeName': representativeName,
      if (representativeDoc != null && representativeDoc.isNotEmpty)
        'representativeDoc': representativeDoc,
      'goodType': goodType,
      'goodDescription': goodDescription,
      if (amount != null) 'amount': amount,
      'claimType': claimType,
      'claimDetail': claimDetail,
      'consumerRequest': consumerRequest,
    });
    return raw as Map<String, dynamic>;
  }
}
