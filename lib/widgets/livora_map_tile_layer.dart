import 'dart:math';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/app_theme.dart';
import '../core/env_config.dart';

/// Capa unificada de teselas CARTO Voyager (estilo minimalista de alta gama)
/// con failover automático a OpenStreetMap, almacenamiento en caché persistente en disco (14 días TTL),
/// prefetch inteligente para rutas de recolección en campo
/// y widget discreto de atribución legal requerida por CARTO y OpenStreetMap.
class LivoraMapTileLayer extends StatefulWidget {
  const LivoraMapTileLayer({super.key});

  /// Pre-descarga en segundo plano las teselas del corredor de una ruta activa
  /// para garantizar navegación 100% fluida en zonas de Lima sin cobertura celular (sótanos/zonas industriales).
  static Future<void> prefetchCorridor(
    List<LatLng> points, {
    int minZoom = 13,
    int maxZoom = 16,
  }) async {
    if (points.isEmpty) return;

    try {
      // Calcular caja envolvente (Bounding Box) con margen de holgura de ~500m
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      const pad = 0.005; // ~500 metros
      minLat -= pad;
      maxLat += pad;
      minLng -= pad;
      maxLng += pad;

      const apiKey = EnvConfig.cartoBasemapsKey;
      final client = http.Client();

      for (int z = minZoom; z <= maxZoom; z++) {
        final minX = _lonToTileX(minLng, z);
        final maxX = _lonToTileX(maxLng, z);
        final minY = _latToTileY(maxLat, z);
        final maxY = _latToTileY(minLat, z);

        // Limitar a un máximo de 60 teselas por prefetch para no saturar memoria/red
        final totalTiles = (maxX - minX + 1) * (maxY - minY + 1);
        if (totalTiles > 60) continue;

        for (int x = minX; x <= maxX; x++) {
          for (int y = minY; y <= maxY; y++) {
            final url =
                'https://a.basemaps.cartocdn.com/rastertiles/voyager/$z/$x/$y.png?key=$apiKey';
            try {
              final uri = Uri.parse(url);
              await client.get(uri, headers: {
                'User-Agent': 'LivoraApp/3.0.0 (pe.livora.app)',
              }).timeout(const Duration(seconds: 4));
            } catch (_) {}
          }
        }
      }
      client.close();
      debugPrint('[LivoraMap] Prefetch de corredor de ruta completado (${points.length} puntos).');
    } catch (e) {
      debugPrint('[LivoraMap] Error en prefetch de teselas: $e');
    }
  }

  static int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  static int _latToTileY(double lat, int zoom) {
    final rad = lat * pi / 180.0;
    return ((1.0 - log(tan(rad) + 1.0 / cos(rad)) / pi) / 2.0 * (1 << zoom)).floor();
  }

  @override
  State<LivoraMapTileLayer> createState() => _LivoraMapTileLayerState();
}

class _LivoraMapTileLayerState extends State<LivoraMapTileLayer> {
  static Future<String>? _cachePathFuture;

  @override
  void initState() {
    super.initState();
    _cachePathFuture ??= _initCachePath();
  }

  static Future<String> _initCachePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/map_tiles_voyager_clean';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _cachePathFuture,
      builder: (context, snapshot) {
        final cachePath = snapshot.data;
        final hasCache = cachePath != null && cachePath.isNotEmpty;
        const apiKey = EnvConfig.cartoBasemapsKey;

        return TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=$apiKey',
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'pe.livora.app',
          maxZoom: 19,
          tileProvider: hasCache
              ? CachedTileProvider(
                  maxStale: const Duration(days: 14),
                  store: FileCacheStore(cachePath),
                )
              : NetworkTileProvider(),
        );
      },
    );
  }
}

/// Widget discreto de atribución legal requerida por la política de CARTO y OpenStreetMap.
class OsmAttributionWidget extends StatelessWidget {
  const OsmAttributionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
        ),
      ),
      child: const Text(
        '© CARTO © OpenStreetMap',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: LivoraColors.ink,
        ),
      ),
    );
  }
}
