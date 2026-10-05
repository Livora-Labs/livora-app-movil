import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/app_version_service.dart';
import '../../widgets/common.dart';

/// Pantalla bloqueante de actualización obligatoria (Hard Update).
/// Impide la navegación y el uso de la app si la versión instalada
/// no cumple con la versión mínima exigida por el backend.
class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({
    super.key,
    required this.checkResult,
    required this.onUpdateResolved,
  });

  final AppVersionCheckResult checkResult;
  final VoidCallback onUpdateResolved;

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  late AppVersionCheckResult _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _result = widget.checkResult;
  }

  Future<void> _openPlayStore() async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse(_result.playStoreUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showAppSnack(
          context,
          'No se pudo abrir la Play Store automáticamente. Por favor busca "Livora" en Google Play Store.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          'Error al abrir Google Play Store: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _recheckVersion() async {
    setState(() => _checking = true);
    HapticFeedback.lightImpact();

    try {
      final api = context.read<ApiClient>();
      final freshResult = await AppVersionService.checkVersion(api);

      if (!mounted) return;

      if (!freshResult.needsHardUpdate) {
        // La versión ya es válida o se actualizó correctamente
        showAppSnack(context, '¡Aplicación verificada con éxito!');
        widget.onUpdateResolved();
      } else {
        setState(() {
          _result = freshResult;
          _checking = false;
        });
        showAppSnack(
          context,
          'Aún no se detecta la versión actualizada. Descárgala desde Google Play Store.',
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checking = false);
        showAppSnack(
          context,
          'No se pudo conectar con el servidor para verificar. Revisa tu conexión a internet.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Bloqueo estricto del botón atrás del sistema
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icono hero con animación de gradiente
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LivoraColors.forest.withValues(alpha: 0.1),
                          border: Border.all(
                            color: LivoraColors.forest.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.system_update_rounded,
                            size: 52,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Badge de estado crítico
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.new_releases_rounded,
                              size: 16,
                              color: Colors.amber.shade900,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ACTUALIZACIÓN OBLIGATORIA',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber.shade900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Título principal
                    const Text(
                      'Nueva Versión Requerida',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: LivoraColors.deep,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Mensaje descriptivo
                    Text(
                      _result.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: LivoraColors.slate,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tarjeta comparativa de versiones
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LivoraColors.paper,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LivoraColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Versión instalada:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: LivoraColors.slate,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${_result.currentVersion} (${_result.currentBuild})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: LivoraColors.deep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Versión mínima requerida:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: LivoraColors.slate,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: LivoraColors.mint.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${_result.minVersionName} (${_result.minBuild})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: LivoraColors.forest,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón primario: Google Play Store
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: LivoraColors.forest,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _openPlayStore,
                      icon: const Icon(Icons.shop_rounded, size: 22),
                      label: const Text(
                        'Actualizar en Google Play Store',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Botón secundario: Reintentar verificación
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LivoraColors.forest,
                        side: const BorderSide(color: LivoraColors.forest),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _checking ? null : _recheckVersion,
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: LivoraColors.forest,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        _checking ? 'Verificando...' : 'Ya actualicé, reintentar',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nota de seguridad y soporte
                    const Center(
                      child: Text(
                        'La actualización garantiza la seguridad de tus transacciones\nblockchain y la trazabilidad de reciclaje en Stellar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: LivoraColors.slate,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
