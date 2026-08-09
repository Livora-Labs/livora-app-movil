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
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        walletAddress: json['walletAddress'] as String?,
      );

  final String id;
  final String email;
  final String role;
  final String? walletAddress;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'walletAddress': walletAddress,
      };
}

/// Solicitud de recolección creada por un hogar.
class CollectionRequest {
  CollectionRequest({
    required this.id,
    required this.status,
    required this.itemsEstimated,
    this.description,
    this.verificationPin,
    this.latitude = 0,
    this.longitude = 0,
    this.householdId,
    this.collectorId,
    this.batchId,
    this.householdEmail,
    this.collectorEmail,
    this.distanceMeters,
    this.createdAt,
  });

  factory CollectionRequest.fromJson(Map<String, dynamic> json) {
    final household = json['household'];
    final collector = json['collector'];
    return CollectionRequest(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      itemsEstimated: parseMaterials(json['itemsEstimated']),
      description: json['description'] as String?,
      verificationPin: json['verificationPin'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      householdId: json['householdId'] as String?,
      collectorId: json['collectorId'] as String?,
      batchId: json['batchId'] as String?,
      householdEmail:
          household is Map ? household['email'] as String? : null,
      collectorEmail:
          collector is Map ? collector['email'] as String? : null,
      distanceMeters: json['distance'] == null
          ? null
          : _toDouble(json['distance']),
      createdAt: _toDate(json['createdAt']),
    );
  }

  final String id;
  final String status;
  final Map<String, double> itemsEstimated;
  final String? description;
  final String? verificationPin;
  final double latitude;
  final double longitude;
  final String? householdId;
  final String? collectorId;
  final String? batchId;
  final String? householdEmail;
  final String? collectorEmail;
  final double? distanceMeters;
  final DateTime? createdAt;

  double get totalEstimatedKg =>
      itemsEstimated.values.fold(0, (sum, kg) => sum + kg);
}

/// Lote de un recolector.
class Batch {
  Batch({
    required this.id,
    required this.status,
    this.materialsActual,
    this.collectorId,
    this.destinationCenterId,
    this.consolidatedBatchId,
    this.collectorEmail,
    this.destinationCenterEmail,
    this.requests = const [],
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
      consolidatedBatchId: json['consolidatedBatchId'] as String?,
      collectorEmail: collector is Map ? collector['email'] as String? : null,
      destinationCenterEmail:
          center is Map ? center['email'] as String? : null,
      requests: rawRequests is List
          ? rawRequests
              .whereType<Map<String, dynamic>>()
              .map(CollectionRequest.fromJson)
              .toList()
          : const [],
      createdAt: _toDate(json['createdAt']),
    );
  }

  final String id;
  final String status;
  final Map<String, double>? materialsActual;
  final String? collectorId;
  final String? destinationCenterId;
  final String? consolidatedBatchId;
  final String? collectorEmail;
  final String? destinationCenterEmail;
  final List<CollectionRequest> requests;
  final DateTime? createdAt;

  String get shortId => id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;

  double get totalActualKg =>
      (materialsActual ?? const {}).values.fold(0, (sum, kg) => sum + kg);

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
