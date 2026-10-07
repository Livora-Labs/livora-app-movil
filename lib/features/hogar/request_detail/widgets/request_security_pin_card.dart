import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/app_theme.dart';
import '../../../../widgets/common.dart';

/// Micro-componente que presenta el PIN de 4 dígitos de verificación física.
class RequestSecurityPinCard extends StatelessWidget {
  const RequestSecurityPinCard({
    super.key,
    required this.pin,
  });

  final String pin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LivoraColors.deep,
            LivoraColors.deep.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: LivoraColors.deep.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, color: LivoraColors.mint, size: 18),
              const SizedBox(width: 8),
              Text(
                'PIN DE VALIDACIÓN FÍSICA',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: pin));
              HapticFeedback.lightImpact();
              showAppSnack(context, 'PIN copiado al portapapeles');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                pin,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Dicta o muestra este código al recolector cuando llegue a tu domicilio para confirmar la entrega.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
