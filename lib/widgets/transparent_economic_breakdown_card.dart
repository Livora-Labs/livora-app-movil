import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Componente modular reutilizable de Desglose Económico Transparente (Clean Architecture).
/// Presenta al usuario la recompensa estimada en tokens LIVO (25%) como valor principal
/// y ofrece un acordeón táctil colapsable con flecha animada (rotación 180°)
/// para revelar el split del 100% del valor del reciclaje:
/// - 🏠 Hogar: 25% (Tokens LIVO o 0% en Donación)
/// - 🚴 Recolector: 70% (Remuneración en efectivo / 100% en Donación)
/// - 🏛️ Protocolo Livora: 5% (Infraestructura / 0% en Donación)
/// - 🏭 Nota transparente del Centro de Acopio (Comprador que fija la tarifa).
class TransparentEconomicBreakdownCard extends StatefulWidget {
  const TransparentEconomicBreakdownCard({
    super.key,
    required this.totalGrossPEN,
    required this.hogarLivo,
    required this.collectorPEN,
    required this.livoraFeePEN,
    this.isDonation = false,
    this.initiallyExpanded = false,
    this.title = 'Desglose Económico Transparente',
  });

  final double totalGrossPEN;
  final double hogarLivo;
  final double collectorPEN;
  final double livoraFeePEN;
  final bool isDonation;
  final bool initiallyExpanded;
  final String title;

  @override
  State<TransparentEconomicBreakdownCard> createState() =>
      _TransparentEconomicBreakdownCardState();
}

class _TransparentEconomicBreakdownCardState
    extends State<TransparentEconomicBreakdownCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDonation
              ? const Color(0xFFF472B6).withValues(alpha: 0.6)
              : LivoraColors.forest.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera interactiva con Flecha Animada
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _expanded = !_expanded);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.isDonation
                            ? const Color(0xFFFBCFE8)
                            : LivoraColors.mint.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isDonation
                            ? Icons.volunteer_activism_rounded
                            : Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: widget.isDonation
                            ? const Color(0xFF9D174D)
                            : LivoraColors.forest,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.deep,
                            ),
                          ),
                          Text(
                            widget.isDonation
                                ? 'Entrega solidaria al recolector'
                                : 'Valor estimado: ${widget.totalGrossPEN.toStringAsFixed(2)} LIVOs',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _expanded ? 'Ocultar' : 'Ver detalles',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: widget.isDonation
                                ? const Color(0xFFDB2777)
                                : LivoraColors.forest,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0, // Rota 180 grados (apunta arriba / abajo)
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: widget.isDonation
                                ? const Color(0xFFDB2777)
                                : LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenido Expandible
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedBreakdown(),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedBreakdown() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          Divider(color: Colors.grey.shade200, height: 16),
          // Fila 1: Hogar (Vecino)
          _BreakdownRow(
            icon: Icons.home_rounded,
            actor: 'Tu Recompensa (Hogar)',
            amountLabel: widget.isDonation
                ? '0.00 LIVO'
                : '${widget.hogarLivo.toStringAsFixed(2)} LIVO',
            accentColor: widget.isDonation ? Colors.grey : LivoraColors.forest,
            badge: widget.isDonation ? 'Donado solidariamente' : 'Recompensa directa',
          ),
          const SizedBox(height: 8),

          // Fila 2: Recolector
          _BreakdownRow(
            icon: Icons.pedal_bike_rounded,
            actor: 'Ingreso Recolector',
            amountLabel: '${widget.collectorPEN.toStringAsFixed(2)} LIVO',
            accentColor: const Color(0xFF2563EB),
            badge: widget.isDonation ? 'Compensación íntegra' : 'Labor de recojo',
          ),
          const SizedBox(height: 8),

          // Fila 3: Livora Protocolo
          _BreakdownRow(
            icon: Icons.hub_rounded,
            actor: 'Comisión Livora',
            amountLabel: '${widget.livoraFeePEN.toStringAsFixed(2)} LIVO',
            accentColor: Colors.blueGrey,
            badge: 'Mantenimiento del servicio',
          ),
          const SizedBox(height: 12),

          // Nota transparente sobre el Centro de Acopio
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.store_rounded, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Centro de Acopio: Adquiere el lote de material y emite la liquidación en tokens LIVO.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
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

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.actor,
    required this.amountLabel,
    required this.accentColor,
    required this.badge,
  });

  final IconData icon;
  final String actor;
  final String amountLabel;
  final Color accentColor;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                actor,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LivoraColors.deep,
                ),
              ),
              Text(
                badge,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          amountLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: accentColor,
          ),
        ),
      ],
    );
  }
}
