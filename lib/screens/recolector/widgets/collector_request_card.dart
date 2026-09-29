import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/app_theme.dart';
import '../../../core/formats.dart';
import '../../../models/models.dart';

/// Tarjeta de solicitud disponible diseñada para el recolector profesional en calle:
/// - Toma de decisión en < 3 segundos: Ganancia neta en Soles (PEN), distancia (km) y materiales (kg).
/// - Zero-Data-Leakage: Aislamiento total de splits internos (40%/10%) y comisiones de plataforma.
/// - Ergonomía y eficiencia de datos: Imagen y notas colapsables para no consumir datos móviles en 4G.
class CollectorRequestCard extends StatefulWidget {
  const CollectorRequestCard({
    super.key,
    required this.request,
    required this.walletBalance,
    required this.kycStatus,
    required this.accepting,
    required this.onAccept,
    required this.onRechargeNeeded,
    required this.onKycNeeded,
  });

  final CollectionRequest request;
  final double walletBalance;
  final KycStatus kycStatus;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onRechargeNeeded;
  final VoidCallback onKycNeeded;

  @override
  State<CollectorRequestCard> createState() => _CollectorRequestCardState();
}

class _CollectorRequestCardState extends State<CollectorRequestCard> {
  bool _expanded = false;

  Color _materialColor(String key) {
    switch (key.toLowerCase()) {
      case 'plastico':
      case 'plastic':
        return const Color(0xFF2E7D32); // Verde reciclaje
      case 'papel':
      case 'carton':
      case 'paper':
      case 'cardboard':
        return const Color(0xFF1565C0); // Azul NTP
      case 'vidrio':
      case 'glass':
        return const Color(0xFF00897B); // Verde azulado
      case 'metal':
      case 'latas':
        return const Color(0xFFE65100); // Ámbar metal
      default:
        return LivoraColors.forest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final distance = req.distanceMeters;
    final hasEnoughEscrow = widget.walletBalance >= req.requiredEscrow;

    final householdLabel = sanitizedPersonName(
      req.householdName,
      req.householdEmail,
      defaultLabel: 'Hogar',
    );
    final householdAddress = req.householdAddress?.isNotEmpty == true
        ? req.householdAddress!
        : 'Dirección física fijada vía GPS';
    final centerLabel = sanitizedCenterName(
      req.assignedCenterName,
      req.assignedCenterEmail,
      defaultLabel: 'Centro de Acopio Asignado',
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _expanded = !_expanded);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cabecera de Alto Rendimiento: Ganancia Neta en Soles + Distancia
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S/ ${req.collectorMarginPEN.toStringAsFixed(2)} PEN',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: LivoraColors.forest,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'Ganancia estimada en acopio',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: LivoraColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (distance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: LivoraColors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation_rounded, size: 13, color: LivoraColors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${(distance / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Pastillas Normativas de Residuos (NTP 900.058)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: req.itemsEstimated.entries.map((entry) {
                  final color = _materialColor(entry.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${materialLabel(entry.key)}: ${fmtKg(entry.value)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // 3. Destino y Centro Comprador
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: LivoraColors.forest),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$householdLabel · $householdAddress',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 15, color: LivoraColors.slate),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Destino: $centerLabel (S/ ${req.averageRatePerKg.toStringAsFixed(2)}/kg)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: LivoraColors.slate,
                      ),
                    ),
                  ),
                ],
              ),

              // 4. Detalle Desplegable Bajo Demanda (Foto y notas)
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: LivoraColors.border),
                const SizedBox(height: 12),

                if (req.description?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LivoraColors.paper,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Nota del hogar: "${req.description}"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: LivoraColors.ink,
                        ),
                      ),
                    ),
                  ),

                if (req.photoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: req.photoUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                        placeholder: (_, __) => Container(
                          height: 140,
                          color: LivoraColors.paper,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 140,
                          color: LivoraColors.paper,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, color: LivoraColors.slate),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Explicación limpia de garantía (Zero-Data-Leakage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: req.isDonation
                        ? LivoraColors.green.withValues(alpha: 0.08)
                        : LivoraColors.paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: req.isDonation
                          ? LivoraColors.green.withValues(alpha: 0.3)
                          : LivoraColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        req.isDonation ? Icons.volunteer_activism_rounded : Icons.shield_outlined,
                        size: 16,
                        color: req.isDonation ? LivoraColors.green : LivoraColors.slate,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          req.isDonation
                              ? 'Donación solidaria: 0 LIVO requeridos (El 100% de la venta en acopio es para ti).'
                              : 'Garantía temporal de cumplimiento: ${req.requiredEscrow.toStringAsFixed(2)} LIVO (Reembolsable en acopio).',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: req.isDonation ? LivoraColors.forest : LivoraColors.deep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // 5. Botón CTA Ergonómico de Acción Inmediata
              SizedBox(
                width: double.infinity,
                child: _buildCta(context, hasEnoughEscrow),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCta(BuildContext context, bool hasEnoughEscrow) {
    final req = widget.request;

    // Validación KYC
    if (widget.kycStatus == KycStatus.unverified ||
        widget.kycStatus == KycStatus.rejected ||
        widget.kycStatus == KycStatus.observed) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFC53030),
          side: const BorderSide(color: Color(0xFFC53030)),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: widget.onKycNeeded,
        icon: const Icon(Icons.shield_outlined, size: 18),
        label: const Text(
          'Verificar cuenta para aceptar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    if (widget.kycStatus == KycStatus.pending) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey.shade400,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: null,
        icon: const Icon(Icons.hourglass_top, size: 18),
        label: const Text(
          'Cuenta en revisión',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    // Saldo escrow insuficiente
    if (!hasEnoughEscrow && !req.isDonation) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.shade700,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: widget.onRechargeNeeded,
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
        label: Text(
          'Garantía insuficiente (${req.requiredEscrow.toStringAsFixed(1)} LIVO)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    // Aceptar Solicitud
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: LivoraColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: widget.accepting ? null : widget.onAccept,
      icon: widget.accepting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.check_circle_outline, size: 18),
      label: Text(
        widget.accepting ? 'Aceptando pedido...' : 'Aceptar solicitud',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }
}
