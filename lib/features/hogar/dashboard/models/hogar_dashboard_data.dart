import '../../../../models/models.dart';

/// Modelo de dominio inmutable para los datos consolidados del Dashboard del Hogar.
class HogarDashboardData {
  const HogarDashboardData({
    required this.metrics,
    required this.requests,
    this.activeRequest,
  });

  final Map<String, dynamic> metrics;
  final List<CollectionRequest> requests;
  final CollectionRequest? activeRequest;

  int get totalCollections =>
      (metrics['esgMetrics']?['totalCollections'] as num?)?.toInt() ?? 0;

  bool get isNewHogar => totalCollections == 0;

  double get livoBalance =>
      (metrics['balances']?['LIVO'] as num?)?.toDouble() ?? 0.0;

  double get recycledKg =>
      (metrics['esgMetrics']?['totalKgRecycled'] as num?)?.toDouble() ?? 0.0;

  double get co2Saved =>
      (metrics['esgMetrics']?['co2SavedKg'] as num?)?.toDouble() ?? 0.0;
}
