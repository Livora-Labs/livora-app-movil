import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import 'eco_confetti_overlay.dart';

/// Modal de celebración festiva que se muestra cuando un lote de reciclaje es completado.
class BatchCelebrationDialog extends StatefulWidget {
  const BatchCelebrationDialog({
    super.key,
    required this.rewardLivo,
    required this.kgRecycled,
    required this.co2SavedKg,
    this.txHash,
    this.isDonation = false,
  });

  final double rewardLivo;
  final double kgRecycled;
  final double co2SavedKg;
  final String? txHash;
  final bool isDonation;

  static Future<void> show(
    BuildContext context, {
    required double rewardLivo,
    required double kgRecycled,
    required double co2SavedKg,
    String? txHash,
    bool isDonation = false,
  }) {
    HapticFeedback.heavyImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => BatchCelebrationDialog(
        rewardLivo: rewardLivo,
        kgRecycled: kgRecycled,
        co2SavedKg: co2SavedKg,
        txHash: txHash,
        isDonation: isDonation,
      ),
    );
  }

  @override
  State<BatchCelebrationDialog> createState() => _BatchCelebrationDialogState();
}

class _BatchCelebrationDialogState extends State<BatchCelebrationDialog>
    with SingleTickerProviderStateMixin {
  final GlobalKey<EcoConfettiOverlayState> _confettiKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiKey.currentState?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: EcoConfettiOverlay(
        key: _confettiKey,
        autoStart: true,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: LivoraColors.deep.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emblema animado central
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5A3), Color(0xFF00A878)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A878).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  '¡Lote Completado con Éxito!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tus materiales ya fueron pesados e ingresados a la cadena de valor.',
                  style: TextStyle(
                    fontSize: 13,
                    color: LivoraColors.ink.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Tarjeta de Tokens / Donación con adaptación según modalidad
                if (widget.isDonation)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: LivoraColors.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: LivoraColors.mint.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'DONACIÓN SOLIDARIA Y ECOLÓGICA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.forest,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volunteer_activism_rounded, color: LivoraColors.forest, size: 26),
                            SizedBox(width: 8),
                            Text(
                              '¡Aporte Solidario!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tus materiales fueron donados al recolector para impulsar el reciclaje comunitario.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: LivoraColors.ink.withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (widget.rewardLivo <= 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: LivoraColors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: LivoraColors.blue.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ACREDITACIÓN EN CURSO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.blue,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Procesando en Stellar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tus Livos se están consolidando en la blockchain y se reflejarán en tu billetera en breve.',
                          style: TextStyle(
                            fontSize: 12,
                            color: LivoraColors.ink.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: LivoraColors.forest.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: LivoraColors.forest.withValues(alpha: 0.2),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'RECOMPENSA ACREDITADA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.forest,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: widget.rewardLivo),
                          duration: const Duration(milliseconds: 1400),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '+${value.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: LivoraColors.deep,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'LIVO',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: LivoraColors.forest,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Text(
                          'Canjeables en comercios aliados',
                          style: TextStyle(
                            fontSize: 12,
                            color: LivoraColors.ink.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Resumen de Impacto Ecológico Tangible
                Row(
                  children: [
                    Expanded(
                      child: _MetricBadge(
                        icon: Icons.recycling_rounded,
                        label: 'Pesaje Real',
                        value: '${widget.kgRecycled.toStringAsFixed(1)} kg',
                        color: LivoraColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricBadge(
                        icon: Icons.eco_rounded,
                        label: 'CO₂ Evitado',
                        value: '${widget.co2SavedKg.toStringAsFixed(1)} kg',
                        color: LivoraColors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LivoraColors.forest,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      '¡Continuar reciclando!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: LivoraColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LivoraColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: LivoraColors.ink.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: LivoraColors.deep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
