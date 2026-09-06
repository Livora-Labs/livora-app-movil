import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_theme.dart';

/// Capa unificada y optimizada de teselas de OpenStreetMap (100% gratuita)
/// con almacenamiento en caché persistente en disco (14 días TTL)
/// y widget discreto de atribución legal.
class LivoraMapTileLayer extends StatefulWidget {
  const LivoraMapTileLayer({super.key});

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
      return '${dir.path}/map_tiles_cache';
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

        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

/// Widget discreto de atribución legal requerida por la política de OpenStreetMap.
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
        '© OpenStreetMap',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: LivoraColors.ink,
        ),
      ),
    );
  }
}
