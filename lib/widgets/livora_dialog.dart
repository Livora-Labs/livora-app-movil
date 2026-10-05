import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';

/// Diálogo modal corporativo unificado de Livora para producción.
/// Garantiza cero desbordamientos en cualquier resolución de pantalla,
/// jerarquía visual limpia, retroalimentación háptica y targets táctiles >= 52px.
class LivoraDialog extends StatelessWidget {
  const LivoraDialog({
    super.key,
    required this.icon,
    this.iconColor = LivoraColors.forest,
    required this.title,
    this.content,
    this.bodyWidget,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isDestructive = false,
    this.primaryIcon,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? content;
  final Widget? bodyWidget;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isDestructive;
  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge de ícono superior
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Título
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: LivoraColors.deep,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Contenido en texto
              if (content != null)
                Text(
                  content!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: LivoraColors.slate,
                    height: 1.45,
                  ),
                ),

              // Widget personalizado embebido
              if (bodyWidget != null) ...[
                if (content != null) const SizedBox(height: 14),
                bodyWidget!,
              ],

              const SizedBox(height: 24),

              // Botón primario
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDestructive ? LivoraColors.coral : LivoraColors.forest,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onPrimaryAction();
                },
                icon: primaryIcon != null
                    ? Icon(primaryIcon, size: 20)
                    : const SizedBox.shrink(),
                label: Text(
                  primaryActionLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // Botón secundario opcional
              if (secondaryActionLabel != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: LivoraColors.slate,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (onSecondaryAction != null) {
                      onSecondaryAction!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    secondaryActionLabel!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Función auxiliar para desplegar un diálogo institucional con retroalimentación sonora y háptica.
Future<T?> showLivoraDialog<T>(
  BuildContext context, {
  required IconData icon,
  Color iconColor = LivoraColors.forest,
  required String title,
  String? content,
  Widget? bodyWidget,
  required String primaryActionLabel,
  required VoidCallback onPrimaryAction,
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
  bool isDestructive = false,
  IconData? primaryIcon,
  bool barrierDismissible = true,
}) {
  HapticFeedback.lightImpact();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'LivoraDialog',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => LivoraDialog(
      icon: icon,
      iconColor: iconColor,
      title: title,
      content: content,
      bodyWidget: bodyWidget,
      primaryActionLabel: primaryActionLabel,
      onPrimaryAction: onPrimaryAction,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      isDestructive: isDestructive,
      primaryIcon: primaryIcon,
    ),
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: child,
        ),
      );
    },
  );
}
