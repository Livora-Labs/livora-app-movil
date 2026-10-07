import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'livora_api.dart';
import 'location_service.dart';

/// Servicio de Telemetría Vehicular y Pedestre con Throttling Adaptativo.
/// Optimiza el uso de CPU, antena GPS y batería en recorridos en campo del recolector.
class TelemetryService {
  TelemetryService({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastBroadcastPosition;
  DateTime? _lastBroadcastTime;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Inicia el rastreo con filtro de distancia y control de energía.
  void startTracking({
    required String requestId,
    required String transportType,
    required void Function(LatLng position, double heading) onPositionUpdated,
  }) {
    if (_isTracking) return;
    _isTracking = true;

    // Configuración defensiva de GPS: precisión alta pero con filtro de distancia de 5 metros
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((position) {
      final now = DateTime.now();
      final lastPos = _lastBroadcastPosition;
      final lastTime = _lastBroadcastTime;

      bool shouldBroadcast = false;

      if (lastPos == null || lastTime == null) {
        shouldBroadcast = true;
      } else {
        final elapsedSeconds = now.difference(lastTime).inSeconds;
        final distanceMeters = LocationService.distanceBetween(
          lastPos.latitude,
          lastPos.longitude,
          position.latitude,
          position.longitude,
        );

        // Emitir si han pasado más de 10 segundos y se movió al menos 15 metros,
        // o si han pasado más de 25 segundos independientemente del movimiento (keep-alive)
        if ((elapsedSeconds >= 10 && distanceMeters >= 15) || elapsedSeconds >= 25) {
          shouldBroadcast = true;
        }
      }

      onPositionUpdated(
        LatLng(position.latitude, position.longitude),
        position.heading,
      );

      if (shouldBroadcast) {
        _lastBroadcastPosition = position;
        _lastBroadcastTime = now;

        _api.updateCollectorLocation(
          requestId,
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          speed: position.speed,
        ).catchError((_) => <String, dynamic>{});
      }
    }, onError: (err) {
      debugPrint('[TelemetryService] Error en stream GPS: $err');
    });
  }

  /// Detiene el rastreo y libera los recursos del hardware GPS.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastBroadcastPosition = null;
    _lastBroadcastTime = null;
    _isTracking = false;
  }
}
