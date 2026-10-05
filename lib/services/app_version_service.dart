import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

/// Modelo de datos con la respuesta de verificación de versión de la app
class AppVersionCheckResult {
  const AppVersionCheckResult({
    required this.needsHardUpdate,
    required this.currentBuild,
    required this.currentVersion,
    required this.minBuild,
    required this.latestBuild,
    required this.minVersionName,
    required this.latestVersionName,
    required this.playStoreUrl,
    required this.message,
    required this.isServerReachable,
  });

  final bool needsHardUpdate;
  final int currentBuild;
  final String currentVersion;
  final int minBuild;
  final int latestBuild;
  final String minVersionName;
  final String latestVersionName;
  final String playStoreUrl;
  final String message;
  final bool isServerReachable;

  factory AppVersionCheckResult.upToDate({
    required int currentBuild,
    required String currentVersion,
  }) {
    return AppVersionCheckResult(
      needsHardUpdate: false,
      currentBuild: currentBuild,
      currentVersion: currentVersion,
      minBuild: currentBuild,
      latestBuild: currentBuild,
      minVersionName: currentVersion,
      latestVersionName: currentVersion,
      playStoreUrl: AppVersionService.defaultPlayStoreUrl,
      message: 'La aplicación se encuentra en la versión óptima.',
      isServerReachable: true,
    );
  }

  factory AppVersionCheckResult.unreachable({
    required int currentBuild,
    required String currentVersion,
  }) {
    return AppVersionCheckResult(
      needsHardUpdate: false,
      currentBuild: currentBuild,
      currentVersion: currentVersion,
      minBuild: currentBuild,
      latestBuild: currentBuild,
      minVersionName: currentVersion,
      latestVersionName: currentVersion,
      playStoreUrl: AppVersionService.defaultPlayStoreUrl,
      message: 'No fue posible contactar el servidor de versiones.',
      isServerReachable: false,
    );
  }
}

/// Servicio que verifica la versión mínima soportada contra el backend
class AppVersionService {
  /// Versión actual declarada en pubspec.yaml (1.0.13+14)
  static const String currentVersionName = '1.0.13';
  static const int currentBuildNumber = 14;

  /// URL canónica en Google Play Store para Livora Labs
  static const String defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.grupolivoralabs.livora';

  /// Consulta el backend para validar si la compilación instalada requiere Hard Update obligatorio
  static Future<AppVersionCheckResult> checkVersion(ApiClient api) async {
    try {
      final dynamic res = await api
          .get('/app/version')
          .timeout(const Duration(seconds: 5));

      if (res is Map<String, dynamic>) {
        final minBuild = (res['minBuild'] as num?)?.toInt() ?? currentBuildNumber;
        final latestBuild =
            (res['latestBuild'] as num?)?.toInt() ?? currentBuildNumber;
        final minVersionName = (res['minVersionName'] as String?) ?? currentVersionName;
        final latestVersionName =
            (res['latestVersionName'] as String?) ?? currentVersionName;
        final forceUpdate = (res['forceUpdate'] as bool?) ?? false;
        final playStoreUrl = (res['playStoreUrl'] as String?)?.isNotEmpty == true
            ? (res['playStoreUrl'] as String)
            : defaultPlayStoreUrl;
        final message = (res['updateMessage'] as String?)?.isNotEmpty == true
            ? (res['updateMessage'] as String)
            : 'Hay una nueva versión disponible en Google Play Store requerida para operar.';

        // Lógica de Hard Update:
        // 1. Si la versión instalada es estrictamente menor a la compilación mínima requerida (minBuild > currentBuild).
        // 2. Si el servidor activó la bandera forceUpdate global y latestBuild > currentBuild.
        final needsHardUpdate =
            (minBuild > currentBuildNumber) || (forceUpdate && latestBuild > currentBuildNumber);

        debugPrint(
          '[AppVersionService] Verificación: local=$currentBuildNumber, min=$minBuild, latest=$latestBuild, force=$forceUpdate -> needsUpdate=$needsHardUpdate',
        );

        return AppVersionCheckResult(
          needsHardUpdate: needsHardUpdate,
          currentBuild: currentBuildNumber,
          currentVersion: currentVersionName,
          minBuild: minBuild,
          latestBuild: latestBuild,
          minVersionName: minVersionName,
          latestVersionName: latestVersionName,
          playStoreUrl: playStoreUrl,
          message: message,
          isServerReachable: true,
        );
      }

      return AppVersionCheckResult.upToDate(
        currentBuild: currentBuildNumber,
        currentVersion: currentVersionName,
      );
    } catch (e) {
      debugPrint('[AppVersionService] Aviso: no se pudo verificar versión remota: $e');
      // En modo sin conexión o timeout permitimos continuar para no bloquear offline
      return AppVersionCheckResult.unreachable(
        currentBuild: currentBuildNumber,
        currentVersion: currentVersionName,
      );
    }
  }
}
