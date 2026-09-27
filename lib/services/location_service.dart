import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'livora_api.dart';

/// Servicio defensivo de geolocalización y gestión de permisos GPS.
class LocationService {
  LocationService._();

  /// Comprueba si el hardware GPS está encendido.
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Comprueba el estado actual de los permisos de ubicación.
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Solicita permisos de ubicación y obtiene la posición GPS actual.
  /// Si falla o se deniega, retorna null de forma segura sin arrojar excepciones no controladas.
  static Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Servicio GPS desactivado por el usuario.');
        return null;
      }

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Permiso de ubicación denegado.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Permiso de ubicación denegado permanentemente.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Error obteniendo GPS actual ($e). Intentando última posición conocida...');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Abre la pantalla de ajustes de la aplicación en el sistema operativo.
  static Future<bool> openAppSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla de configuración de ubicación del sistema operativo.
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Stream que notifica cambios en el estado del hardware GPS (activado / desactivado).
  static Stream<ServiceStatus> getServiceStatusStream() {
    return Geolocator.getServiceStatusStream();
  }

  /// Obtiene la última posición conocida en caché del sistema operativo.
  static Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Calcula la distancia en metros entre dos puntos de coordenadas.
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Geocodificación inversa (LatLng -> Dirección) utilizando el proxy backend seguro con caché Redis
  /// y fallback a Nominatim directo.
  static Future<String?> reverseGeocode(
    double lat,
    double lng, {
    dynamic client,
    LivoraApi? api,
  }) async {
    if (api != null) {
      try {
        final address = await api.reverseGeocode(lat, lng);
        if (address != null && address.trim().isNotEmpty) {
          return address;
        }
      } catch (e) {
        debugPrint('[LocationService] Proxy backend geocoding falló ($e). Usando fallback.');
      }
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = client != null
          ? await client.get(
              uri,
              headers: {
                'User-Agent': 'LivoraApp/3.0.0 (pe.livora.app)',
                'Accept': 'application/json',
              },
            )
          : await _defaultHttpGet(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body as String) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road = address['road'] ?? address['pedestrian'] ?? address['street'] ?? address['path'];
          final houseNumber = address['house_number'];
          final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['city_district'] ?? address['district'];
          final city = address['city'] ?? address['town'] ?? address['village'];

          final parts = <String>[];
          if (road != null && road.toString().trim().isNotEmpty) {
            if (houseNumber != null && houseNumber.toString().trim().isNotEmpty) {
              parts.add('$road $houseNumber');
            } else {
              parts.add(road.toString());
            }
          }
          if (suburb != null && suburb.toString().trim().isNotEmpty) {
            parts.add(suburb.toString());
          } else if (city != null && city.toString().trim().isNotEmpty) {
            parts.add(city.toString());
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          final segments = displayName.split(',');
          if (segments.length >= 2) {
            return '${segments[0].trim()}, ${segments[1].trim()}';
          }
          return displayName;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LocationService] Error en geocodificación inversa: $e');
      return null;
    }
  }

  static Future<dynamic> _defaultHttpGet(Uri uri) async {
    final client = http.Client();
    try {
      return await client.get(
        uri,
        headers: {
          'User-Agent': 'LivoraApp/3.0.0 (pe.livora.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
    } finally {
      client.close();
    }
  }

  /// Solicita explícitamente permisos de ubicación al usuario.
  static Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Búsqueda predictiva de direcciones (Forward Geocoding) utilizando el proxy backend seguro con caché Redis
  /// y fallback a Nominatim directo.
  static Future<List<Map<String, dynamic>>> searchAddress(
    String query, {
    dynamic client,
    LivoraApi? api,
  }) async {
    final clean = query.trim();
    if (clean.length < 3) return [];

    if (api != null) {
      try {
        final results = await api.searchAddress(clean);
        if (results.isNotEmpty) {
          return results;
        }
      } catch (e) {
        debugPrint('[LocationService] Proxy backend search falló ($e). Usando fallback.');
      }
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&limit=5&countrycodes=pe&addressdetails=1',
      );
      final response = client != null
          ? await client.get(
              uri,
              headers: {
                'User-Agent': 'LivoraApp/3.0.0 (pe.livora.app)',
                'Accept': 'application/json',
              },
            )
          : await _defaultHttpGet(uri);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body as String) as List<dynamic>;
        return list.map((item) {
          final map = item as Map<String, dynamic>;
          final lat = double.tryParse(map['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(map['lon']?.toString() ?? '') ?? 0.0;
          final displayName = map['display_name']?.toString() ?? '';
          return {
            'address': displayName,
            'latitude': lat,
            'longitude': lon,
          };
        }).where((e) => (e['latitude'] as double) != 0.0).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[LocationService] Error en búsqueda de dirección: $e');
      return [];
    }
  }

  // ===========================================================================
  // Ciclo de Vida del Sensor GPS para Recolector en Ruta (EN_ROUTE -> ARRIVED)
  // ===========================================================================

  static dynamic _positionSubscription;
  static Timer? _heartbeatTimer;
  static bool _isCollectorTracking = false;
  static final List<Map<String, dynamic>> _offlineBuffer = [];
  static DateTime? _lastPingTime;

  static bool get isCollectorTracking => _isCollectorTracking;

  /// Inicia el muestreo de GPS con Foreground Service persistente para evitar
  /// que Android congele el sensor cuando la pantalla se apague o bloquee.
  /// Incluye cooldown de 4s para eficiencia de batería y ancho de banda.
  static void startCollectorTracking({
    required String requestId,
    required dynamic api, // LivoraApi
    void Function(Position position)? onPositionUpdate,
    Map<String, dynamic> Function()? getRouteTelemetry,
  }) {
    if (_isCollectorTracking) return;
    _isCollectorTracking = true;
    _lastPingTime = null;

    debugPrint('[LocationService] Iniciando tracking de recolector para solicitud #$requestId');

    Future<void> sendPing(Position position, {bool force = false}) async {
      final now = DateTime.now();
      if (!force && _lastPingTime != null) {
        final elapsed = now.difference(_lastPingTime!).inMilliseconds;
        if (elapsed < 4000) {
          // Debounce / Cooldown de 4 segundos
          return;
        }
      }
      _lastPingTime = now;
      onPositionUpdate?.call(position);

      final telemetry = getRouteTelemetry?.call();
      final distanceRemainingMeters = telemetry?['distanceRemainingMeters'] as double?;
      final etaMinutes = telemetry?['etaMinutes'] as double?;
      final transportType = telemetry?['transportType'] as String?;

      final payload = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed * 3.6, // m/s a km/h
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
        if (distanceRemainingMeters != null) 'distanceRemainingMeters': distanceRemainingMeters,
        if (etaMinutes != null) 'etaMinutes': etaMinutes,
        if (transportType != null) 'transportType': transportType,
      };

      try {
        await api.updateCollectorLocation(
          requestId,
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          speed: position.speed * 3.6,
          accuracy: position.accuracy,
          timestamp: position.timestamp.millisecondsSinceEpoch,
          distanceRemainingMeters: distanceRemainingMeters,
          etaMinutes: etaMinutes,
          transportType: transportType,
        );

        if (_offlineBuffer.isNotEmpty) {
          _offlineBuffer.clear();
        }
      } catch (e) {
        debugPrint('[LocationService] Error enviando telemetría al backend ($e). Encolando en buffer offline...');
        _offlineBuffer.add(payload);
        if (_offlineBuffer.length > 50) {
          _offlineBuffer.removeAt(0);
        }
      }
    }

    // Ping inmediato (t=0) para que el Hogar vea la posición al instante
    getCurrentPosition().then((pos) {
      if (pos != null && _isCollectorTracking) {
        sendPing(pos, force: true);
      }
    });

    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Livora - En ruta a recolección',
          notificationText: 'Transmitiendo ubicación en vivo de la recolección en curso',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      sendPing(position);
    }, onError: (e) {
      debugPrint('[LocationService] Error en stream de geolocalización: $e');
    });

    // Heartbeat periódico cada 12 segundos para no perder presencia si el recolector se detiene en un semáforo
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!_isCollectorTracking) return;
      final pos = await getCurrentPosition();
      if (pos != null && _isCollectorTracking) {
        sendPing(pos);
      }
    });
  }

  /// Apaga inmediatamente el sensor GPS y Foreground Service para preservar la batería
  /// y salvaguardar la privacidad del recolector tras pulsar "Llegué al Domicilio".
  static void stopCollectorTracking() {
    if (!_isCollectorTracking) return;
    _isCollectorTracking = false;
    _lastPingTime = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _offlineBuffer.clear();
    debugPrint('[LocationService] Sensor GPS y Foreground Service detenidos exitosamente.');
  }
}

