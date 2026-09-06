import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as ph;

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

  /// Geocodificación inversa con OpenStreetMap Nominatim.
  /// Obtiene nombre de vía, número y distrito estructurado de forma legible.
  static Future<String?> reverseGeocode(
    double lat,
    double lng, {
    dynamic client,
  }) async {
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
}
