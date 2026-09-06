double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

DateTime? _toDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Convierte el JSON libre de materiales ({"PET": 2.5, ...}) en un mapa tipado.
Map<String, double> parseMaterials(Object? raw) {
  if (raw is! Map) return {};
  final result = <String, double>{};
  raw.forEach((key, value) {
    result['$key'] = _toDouble(value);
  });
  return result;
}

/// Usuario autenticado en la app.
class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.walletAddress,
    this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.marketingAccepted = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        walletAddress: json['walletAddress'] as String?,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        latitude: json['latitude'] != null ? _toDouble(json['latitude']) : null,
        longitude: json['longitude'] != null ? _toDouble(json['longitude']) : null,
        marketingAccepted: json['marketingAccepted'] as bool? ?? false,
      );

  final String id;
  final String email;
  final String role;
  final String? walletAddress;
  final String? name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool marketingAccepted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'walletAddress': walletAddress,
        'name': name,
        'phone': phone,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'marketingAccepted': marketingAccepted,
      };
}

/// Lista de precios registrada por un Centro de Acopio.
class AcopioPriceList {
  AcopioPriceList({
    required this.id,
    required this.centerId,
    required this.materialType,
    required this.pricePerKg,
  });

  factory AcopioPriceList.fromJson(Map<String, dynamic> json) => AcopioPriceList(
        id: json['id'] as String? ?? '',
        centerId: json['centerId'] as String? ?? '',
        materialType: json['materialType'] as String? ?? '',
        pricePerKg: _toDouble(json['pricePerKg']),
      );

  final String id;
  final String centerId;
  final String materialType;
  final double pricePerKg;
}

/// Propuesta enviada por un Centro de Acopio a una subasta.
class AcopioBid {
  AcopioBid({
    required this.id,
    required this.requestId,
    required this.centerId,
    required this.proposedRates,
    required this.totalEstimatedPenn,
    required this.totalEstimatedEco,
    required this.status,
    this.centerName,
    this.centerEmail,
    this.centerAddress,
    this.createdAt,
  });

  factory AcopioBid.fromJson(Map<String, dynamic> json) {
    final center = json['center'];
    return AcopioBid(
      id: json['id'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      centerId: json['centerId'] as String? ?? '',
      proposedRates: parseMaterials(json['proposedRates']),
      totalEstimatedPenn: _toDouble(json['totalEstimatedPenn']),
      totalEstimatedEco: _toDouble(json['totalEstimatedEco']),
      status: json['status'] as String? ?? 'PENDING',
      centerName: center is Map ? center['name'] as String? : null,
      centerEmail: center is Map ? center['email'] as String? : null,
      centerAddress: center is Map ? center['address'] as String? : null,
      createdAt: _toDate(json['createdAt']),
    );
  }

  final String id;
  final String requestId;
  final String centerId;
  final Map<String, double> proposedRates;
  final double totalEstimatedPenn;
  final double totalEstimatedEco;
  final String status;
  final String? centerName;
  final String? centerEmail;
  final String? centerAddress;
  final DateTime? createdAt;
}

/// Solicitud de recolección creada por un hogar.
class CollectionRequest {
  CollectionRequest({
    required this.id,
    required this.status,
    required this.itemsEstimated,
    this.assignmentMode = 'AUTOMATIC',
    this.description,
    this.photoUrl,
    this.verificationPin,
    this.latitude = 0,
    this.longitude = 0,
    this.householdId,
    this.collectorId,
    this.assignedCenterId,
    this.assignedCenterName,
    this.assignedCenterEmail,
    this.agreedRates = const {},
    this.escrowLocked = 0,
    this.actualWeights,
    this.batchId,
    this.householdEmail,
    this.householdAddress,
    this.householdName,
    this.householdPhone,
    this.collectorEmail,
    this.distanceMeters,
    this.collectorName,
    this.txHash,
    this.bids = const [],
    this.rating,
    this.feedback,
    this.createdAt,
  });

  factory CollectionRequest.fromJson(Map<String, dynamic> json) {
    final household = json['household'];
    final collector = json['collector'];
    final center = json['assignedCenter'];
    final batch = json['batch'];
    final rawBids = json['bids'];

    Map<String, double>? resolvedWeights;
    if (json['actualWeights'] != null) {
      resolvedWeights = parseMaterials(json['actualWeights']);
    } else if (batch is Map && batch['materialsActual'] != null) {
      resolvedWeights = parseMaterials(batch['materialsActual']);
    }

    final txHash = json['txHash'] as String? ??
        (batch is Map ? batch['txHash'] as String? : null);

    return CollectionRequest(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      assignmentMode: json['assignmentMode'] as String? ?? 'AUTOMATIC',
      itemsEstimated: parseMaterials(json['itemsEstimated']),
      description: json['description'] as String?,
      photoUrl: json['photoUrl'] as String?,
      verificationPin: json['verificationPin'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      householdId: json['householdId'] as String?,
      collectorId: json['collectorId'] as String?,
      collectorName: collector is Map ? collector['name'] as String? : null,
      assignedCenterId: json['assignedCenterId'] as String?,
      assignedCenterName: center is Map ? center['name'] as String? : null,
      assignedCenterEmail: center is Map ? center['email'] as String? : null,
      agreedRates: parseMaterials(json['agreedRates']),
      escrowLocked: _toDouble(json['escrowLocked']),
      actualWeights: resolvedWeights,
      batchId: json['batchId'] as String? ?? (batch is Map ? batch['id'] as String? : null),
      householdEmail:
          household is Map ? household['email'] as String? : null,
      householdAddress: household is Map
          ? household['address'] as String?
          : (json['address'] as String?),
      householdName: household is Map
          ? household['name'] as String?
          : (json['householdName'] as String?),
      householdPhone: household is Map
          ? household['phone'] as String?
          : (json['householdPhone'] as String? ?? json['phone'] as String?),
      collectorEmail:
          collector is Map ? collector['email'] as String? : null,
      distanceMeters: json['distance'] == null
          ? null
          : _toDouble(json['distance']),
      txHash: txHash,
      bids: rawBids is List
          ? rawBids
              .whereType<Map<String, dynamic>>()
              .map(AcopioBid.fromJson)
              .toList()
          : const [],
      rating: json['rating'] as int?,
      feedback: json['feedback'] as String?,
      createdAt: _toDate(json['createdAt']),
    );
  }

  final String id;
  String status;
  final String assignmentMode;
  final Map<String, double> itemsEstimated;
  final String? description;
  final String? photoUrl;
  final String? verificationPin;
  final double latitude;
  final double longitude;
  final String? householdId;
  final String? collectorId;
  final String? collectorName;
  final String? assignedCenterId;
  final String? assignedCenterName;
  final String? assignedCenterEmail;
  final Map<String, double> agreedRates;
  final double escrowLocked;
  final Map<String, double>? actualWeights;
  final String? batchId;
  final String? householdEmail;
  final String? householdAddress;
  final String? householdName;
  final String? householdPhone;
  final String? collectorEmail;
  final double? distanceMeters;
  final String? txHash;
  final List<AcopioBid> bids;
  final int? rating;
  final String? feedback;
  final DateTime? createdAt;

  double get totalEstimatedKg =>
      itemsEstimated.values.fold(0, (sum, kg) => sum + kg);

  double get totalActualKg =>
      (actualWeights ?? const {}).values.fold(0, (sum, kg) => sum + kg);

  String get shortId => id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;

  /// Valor total estimado del material según las tarifas acordadas
  double get totalEstimatedValuePEN {
    double total = 0;
    itemsEstimated.forEach((mat, weight) {
      final rate = agreedRates[mat] ?? agreedRates[mat.toUpperCase()] ?? 1.0;
      total += weight * rate;
    });
    return total;
  }

  /// Ganancia estimada para el Hogar: 40% del valor total
  double get hogarEstimatedEarningsPEN => totalEstimatedValuePEN * 0.40;

  /// Comisión Livora: 10% del valor total
  double get livoraFeePEN => totalEstimatedValuePEN * 0.10;

  /// Margen del Recolector: 50% del valor total
  double get collectorMarginPEN => totalEstimatedValuePEN * 0.50;

  /// Calcula la garantía requerida en EcoTokens: 50% del valor estimado total
  double get requiredEscrow {
    if (escrowLocked > 0) return escrowLocked;
    return totalEstimatedValuePEN * 0.50;
  }

  /// Tarifa promedio por kg ofertada por el Centro de Acopio asignado
  double get averageRatePerKg {
    if (agreedRates.isEmpty) return 1.0;
    if (totalEstimatedKg > 0) {
      return totalEstimatedValuePEN / totalEstimatedKg;
    }
    final sum = agreedRates.values.fold<double>(0.0, (s, r) => s + r);
    return sum / agreedRates.length;
  }
}

/// Lote de un recolector.
class Batch {
  Batch({
    required this.id,
    required this.status,
    this.materialsActual,
    this.collectorId,
    this.destinationCenterId,
    this.destinationCenterName,
    this.destinationCenterAddress,
    this.consolidatedBatchId,
    this.collectorEmail,
    this.collectorName,
    this.destinationCenterEmail,
    this.requests = const [],
    this.txHash,
    this.hasDiscrepancy = false,
    this.discrepancyNote,
    this.fiatSettled = false,
    this.fiatSettledAt,
    this.disputeReason,
    this.disputedAt,
    this.createdAt,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    final collector = json['collector'];
    final center = json['destinationCenter'];
    final rawRequests = json['requests'];
    return Batch(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      materialsActual: json['materialsActual'] == null
          ? null
          : parseMaterials(json['materialsActual']),
      collectorId: json['collectorId'] as String?,
      destinationCenterId: json['destinationCenterId'] as String?,
      destinationCenterName:
          center is Map ? center['name'] as String? : (json['centerName'] as String?),
      destinationCenterAddress:
          center is Map ? center['address'] as String? : null,
      consolidatedBatchId: json['consolidatedBatchId'] as String?,
      collectorEmail: collector is Map ? collector['email'] as String? : null,
      collectorName: collector is Map ? collector['name'] as String? : null,
      destinationCenterEmail:
          center is Map ? center['email'] as String? : null,
      requests: rawRequests is List
          ? rawRequests
              .whereType<Map<String, dynamic>>()
              .map(CollectionRequest.fromJson)
              .toList()
          : const [],
      txHash: json['txHash'] as String?,
      hasDiscrepancy: json['hasDiscrepancy'] as bool? ?? false,
      discrepancyNote: json['discrepancyNote'] as String?,
      fiatSettled: json['fiatSettled'] as bool? ?? false,
      fiatSettledAt: _toDate(json['fiatSettledAt']),
      disputeReason: json['disputeReason'] as String?,
      disputedAt: _toDate(json['disputedAt']),
      createdAt: _toDate(json['createdAt']),
    );
  }

  final String id;
  final String status;
  final Map<String, double>? materialsActual;
  final String? collectorId;
  final String? destinationCenterId;
  final String? destinationCenterName;
  final String? destinationCenterAddress;
  final String? consolidatedBatchId;
  final String? collectorEmail;
  final String? collectorName;
  final String? destinationCenterEmail;
  final List<CollectionRequest> requests;
  final String? txHash;
  final bool hasDiscrepancy;
  final String? discrepancyNote;
  final bool fiatSettled;
  final DateTime? fiatSettledAt;
  final String? disputeReason;
  final DateTime? disputedAt;
  final DateTime? createdAt;

  String get shortId => id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;

  double get totalActualKg =>
      (materialsActual ?? const {}).values.fold(0, (sum, kg) => sum + kg);

  /// Suma de peso estimado de todas las solicitudes vinculadas al lote.
  double get totalEstimatedKg =>
      requests.fold<double>(0.0, (sum, r) => sum + r.totalEstimatedKg);

  /// Suma de materiales estimados de todas las solicitudes del lote.
  Map<String, double> get estimatedMaterials {
    final totals = <String, double>{};
    for (final request in requests) {
      request.itemsEstimated.forEach(
        (material, kg) => totals[material] = (totals[material] ?? 0) + kg,
      );
    }
    return totals;
  }
}

/// Notificación del usuario.
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: json['type'] as String? ?? 'INFO',
        isRead: json['isRead'] as bool? ?? false,
        createdAt: _toDate(json['createdAt']),
      );

  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
}

/// Existencia de material en inventario (centro de acopio / tienda).
class InventoryItem {
  InventoryItem({
    required this.id,
    required this.materialType,
    required this.quantityKg,
    this.updatedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String? ?? '',
        materialType: json['materialType'] as String? ?? '',
        quantityKg: _toDouble(json['quantityKg']),
        updatedAt: _toDate(json['updatedAt']),
      );

  final String id;
  final String materialType;
  final double quantityKg;
  final DateTime? updatedAt;
}

/// Movimiento de inventario (IN báscula / OUT venta o merma).
class InventoryMovement {
  InventoryMovement({
    required this.id,
    required this.type,
    required this.quantityKg,
    required this.materialType,
    required this.centerId,
    this.createdAt,
  });

  factory InventoryMovement.fromJson(Map<String, dynamic> json) =>
      InventoryMovement(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'IN',
        quantityKg: _toDouble(json['quantityKg']),
        materialType: json['materialType'] as String? ?? '',
        centerId: json['centerId'] as String? ?? '',
        createdAt: _toDate(json['createdAt']),
      );

  final String id;
  final String type;
  final double quantityKg;
  final String materialType;
  final String centerId;
  final DateTime? createdAt;
}

/// Empresa B2B registrada y verificada en el ecosistema Livora.
class B2bCompany {
  B2bCompany({
    required this.id,
    required this.email,
    this.name,
    this.walletAddress,
  });

  factory B2bCompany.fromJson(Map<String, dynamic> json) => B2bCompany(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        name: json['name'] as String?,
        walletAddress: json['walletAddress'] as String?,
      );

  final String id;
  final String email;
  final String? name;
  final String? walletAddress;

  String get displayName => (name != null && name!.trim().isNotEmpty)
      ? name!.trim()
      : email.split('@').first;
}

/// Estados tipados del proceso de verificación de identidad KYC.
enum KycStatus {
  unverified,
  pending,
  approved,
  rejected;

  static KycStatus fromString(String? raw) {
    if (raw == null) return KycStatus.unverified;
    switch (raw.toUpperCase()) {
      case 'APPROVED':
        return KycStatus.approved;
      case 'PENDING':
        return KycStatus.pending;
      case 'REJECTED':
        return KycStatus.rejected;
      case 'NOT_SUBMITTED':
      default:
        return KycStatus.unverified;
    }
  }

  String toBackendString() => switch (this) {
        KycStatus.unverified => 'NOT_SUBMITTED',
        KycStatus.pending => 'PENDING',
        KycStatus.approved => 'APPROVED',
        KycStatus.rejected => 'REJECTED',
      };

  String get label => switch (this) {
        KycStatus.unverified => 'Sin verificar',
        KycStatus.pending => 'En revisión',
        KycStatus.approved => 'Verificado',
        KycStatus.rejected => 'Rechazado',
      };
}

/// Estado de la verificación KYC de un recolector.
///
/// `GET /collectors/me/kyc-application` devuelve `NOT_SUBMITTED` cuando el
/// recolector todavía no envió ningún documento.
class KycApplication {
  KycApplication({
    required this.status,
    this.documentUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory KycApplication.fromJson(Map<String, dynamic> json) => KycApplication(
        status: json['status'] as String? ?? 'NOT_SUBMITTED',
        documentUrl: json['documentUrl'] as String?,
        createdAt: _toDate(json['createdAt']),
        updatedAt: _toDate(json['updatedAt']),
      );

  final String status;
  final String? documentUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  KycStatus get kycStatus => KycStatus.fromString(status);
  bool get isSubmitted => status != 'NOT_SUBMITTED';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  /// Solo se puede (re)enviar si nunca se envió o si fue rechazada.
  bool get canSubmit => !isSubmitted || isRejected;
}

/// Métricas del hogar.
class HouseholdMetrics {
  HouseholdMetrics({
    required this.totalRequests,
    required this.completedRequests,
    required this.totalRecycledKg,
    required this.ecoTokensEarned,
  });

  factory HouseholdMetrics.fromJson(Map<String, dynamic> json) =>
      HouseholdMetrics(
        totalRequests: (json['totalRequests'] as num?)?.toInt() ?? 0,
        completedRequests: (json['completedRequests'] as num?)?.toInt() ?? 0,
        totalRecycledKg: _toDouble(json['totalRecycledKg']),
        ecoTokensEarned: _toDouble(json['ecoTokensEarned']),
      );

  final int totalRequests;
  final int completedRequests;
  final double totalRecycledKg;
  final double ecoTokensEarned;
}

/// Reputación del recolector.
class CollectorReputation {
  CollectorReputation({
    required this.score,
    required this.totalPickups,
    required this.ratingCount,
    required this.badge,
  });

  factory CollectorReputation.fromJson(Map<String, dynamic> json) =>
      CollectorReputation(
        score: _toDouble(json['score']),
        totalPickups: (json['totalPickups'] as num?)?.toInt() ?? 0,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        badge: json['badge'] as String? ?? '',
      );

  final double score;
  final int totalPickups;
  final int ratingCount;
  final String badge;
}

/// Transacción de Billetera (Recompensas por reciclaje, canjes en tiendas, recargas Niubiz).
class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.direction,
    required this.recipientName,
    required this.recipientWallet,
    this.txHash,
    this.ipfsCid,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'TRANSACCION',
        amount: _toDouble(json['amount']),
        direction: json['direction'] as String? ?? 'IN',
        recipientName: json['recipientName'] as String? ?? 'Sistema Livora',
        recipientWallet: json['recipientWallet'] as String? ?? '',
        txHash: json['txHash'] as String?,
        ipfsCid: json['ipfsCid'] as String?,
        createdAt: _toDate(json['createdAt']),
      );

  final String id;
  final String type;
  final double amount;
  final String direction; // 'IN' | 'OUT'
  final String recipientName;
  final String recipientWallet;
  final String? txHash;
  final String? ipfsCid;
  final DateTime? createdAt;

  bool get isIncoming => direction == 'IN';
  double get amountPen => amount; // 1 ECO = 1 PEN
}

