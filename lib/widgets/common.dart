import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';

/// Chip pequeño de estado con color semántico.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tarjeta de métrica para dashboards.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.subtitle,
    this.color = LivoraColors.forest,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: LivoraColors.ink.withValues(alpha: 0.4),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Expanded + FittedBox: el valor se encoge si la celda es baja,
          // así la tarjeta nunca desborda la cuadrícula.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        unit!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: LivoraColors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: LivoraColors.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: LivoraColors.ink.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      );
    }

    return Card(child: content);
  }
}

/// Título de sección con acción opcional.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: LivoraColors.deep,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Estado vacío ilustrado con soporte para acciones rápidas.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.actions,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: LivoraColors.ink.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LivoraColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: LivoraColors.ink.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cajas estilizadas tipo OTP para mostrar códigos y PINs de verificación.
class OtpPinBox extends StatelessWidget {
  const OtpPinBox({
    super.key,
    required this.pin,
    this.length = 4,
    this.isActive = true,
  });

  final String pin;
  final int length;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final chars = pin.padRight(length, '—').split('');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final char = index < chars.length ? chars[index] : '—';
        final isFilled = char != '—' && char != '-' && char.trim().isNotEmpty;

        return Container(
          width: 48,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: isActive
                ? (isFilled ? LivoraColors.blue.withValues(alpha: 0.08) : Colors.white)
                : LivoraColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? (isFilled ? LivoraColors.blue : LivoraColors.ink.withValues(alpha: 0.2))
                  : LivoraColors.ink.withValues(alpha: 0.1),
              width: isFilled ? 2 : 1.2,
            ),
            boxShadow: isActive && isFilled
                ? [
                    BoxShadow(
                      color: LivoraColors.blue.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              char,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: isActive
                    ? (isFilled ? LivoraColors.blue : LivoraColors.ink.withValues(alpha: 0.3))
                    : LivoraColors.ink.withValues(alpha: 0.25),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Fila etiqueta / valor para pantallas de detalle.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: LivoraColors.ink.withValues(alpha: 0.75),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: LivoraColors.deep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón principal con estado de carga.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );
  }
}

/// Muestra un SnackBar flotante moderno con ícono temático contextual,
/// texto sanitizado de alto contraste y soporte para acciones rápidas con retroalimentación háptica.
void showAppSnack(
  BuildContext context,
  String message, {
  bool error = false,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final lower = message.toLowerCase();

  // Determinación contextual del ícono si no se especifica explícitamente
  final IconData effectiveIcon = icon ??
      (error
          ? (lower.contains('internet') ||
                  lower.contains('conexión') ||
                  lower.contains('conectar') ||
                  lower.contains('red')
              ? Icons.wifi_off_rounded
              : Icons.error_outline_rounded)
          : Icons.check_circle_outline_rounded);

  final Color backgroundColor =
      error ? const Color(0xFF9E2A2B) : LivoraColors.deep;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: backgroundColor,
        duration: duration,
        content: Row(
          children: [
            Icon(effectiveIcon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: error ? const Color(0xFFFFD166) : LivoraColors.mint,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAction();
                },
              )
            : null,
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
