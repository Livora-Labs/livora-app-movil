import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import 'livora_empty_state.dart';
import 'livora_shimmer.dart';

/// Widget unificado de 4 Estados Canónicos para vistas móviles de Livora:
/// 1. Carga (Skeleton/Shimmer)
/// 2. Éxito con datos (Child o Builder)
/// 3. Error con reintento (1-tap retry)
/// 4. Estado vacío contextual (Empty State con CTA)
class ViewStateScaffold extends StatelessWidget {
  const ViewStateScaffold({
    super.key,
    required this.isLoading,
    this.hasError = false,
    this.errorMessage,
    this.isEmpty = false,
    this.onRetry,
    this.onRefresh,
    this.skeleton,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Sin elementos',
    this.emptyMessage = 'No hay registros disponibles en este momento.',
    this.emptyActionLabel,
    this.onEmptyAction,
    required this.child,
  });

  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final bool isEmpty;
  final VoidCallback? onRetry;
  final RefreshCallback? onRefresh;
  final Widget? skeleton;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return skeleton ?? const LivoraShimmerList();
    }

    if (hasError) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: LivoraColors.coral.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 38,
                  color: LivoraColors.coral,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No se pudo conectar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ??
                    'Ocurrió un error al obtener la información. Revisa tu conexión a internet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: LivoraColors.ink,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onRetry!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Reintentar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: LivoraColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      final emptyWidget = LivoraEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );

      if (onRefresh != null) {
        return RefreshIndicator(
          onRefresh: onRefresh!,
          color: LivoraColors.forest,
          child: emptyWidget,
        );
      }
      return emptyWidget;
    }

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: LivoraColors.forest,
        child: child,
      );
    }

    return child;
  }
}
