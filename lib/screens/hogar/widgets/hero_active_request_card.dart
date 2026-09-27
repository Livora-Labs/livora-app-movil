import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/formats.dart';
import '../../../models/models.dart';
import '../../../widgets/common.dart';
import '../auction_bids_screen.dart';

/// Tarjeta Héroe que muestra la solicitud de reciclaje activa del hogar en el Dashboard.
/// Cumple con la directiva: LIVO como unidad principal y Soles (S/) como valor secundario referencial.
class HeroActiveRequestCard extends StatelessWidget {
  const HeroActiveRequestCard({
    super.key,
    required this.request,
    required this.onTapDetail,
  });

  final CollectionRequest request;
  final VoidCallback onTapDetail;

  @override
  Widget build(BuildContext context) {
    final isAuction = request.assignmentMode == 'AUCTION';
    final isCenterAssigned = request.assignedCenterId != null ||
        request.assignedCenterName != null;
    final isAssigned = request.status == 'ACCEPTED' ||
        request.status == 'ASSIGNED' ||
        request.status == 'EN_ROUTE' ||
        request.status == 'ARRIVED' ||
        request.collectorId != null ||
        request.collectorName != null ||
        request.collectorEmail != null;

    final (badgeLabel, badgeColor, badgeIcon) = switch (request.status) {
      'ARRIVED' => (
          'Recolector en tu puerta',
          LivoraColors.forest,
          Icons.door_front_door_rounded,
        ),
      'ACCEPTED' || 'ASSIGNED' || 'EN_ROUTE' => (
          'Recolector en camino',
          LivoraColors.green,
          Icons.delivery_dining,
        ),
      'AUCTION_ACTIVE' || 'AUCTION_OPEN' => (
          'Subasta · ${request.bids.length} ${request.bids.length == 1 ? 'oferta' : 'ofertas'}',
          Colors.indigo,
          Icons.gavel,
        ),
      'AUCTION_ASSIGNED' => (
          'Acopio asignado · Esperando recolector',
          LivoraColors.forest,
          Icons.store_rounded,
        ),
      _ => isAssigned
          ? (
              request.status == 'ARRIVED'
                  ? 'Recolector en tu puerta'
                  : 'Recolector en camino',
              LivoraColors.green,
              Icons.delivery_dining,
            )
          : isCenterAssigned
              ? (
                  'Acopio asignado · Esperando recolector',
                  LivoraColors.forest,
                  Icons.store_rounded,
                )
              : isAuction
                  ? (
                      'Subasta activa · ${request.bids.length} ${request.bids.length == 1 ? 'oferta' : 'ofertas'}',
                      Colors.indigo,
                      Icons.gavel,
                    )
                  : (
                      'Buscando centro de acopio',
                      LivoraColors.amber,
                      Icons.search,
                    ),
    };

    final livoEarnings = request.hogarEstimatedEarningsPEN;
    final penEarnings = request.hogarEstimatedEarningsPEN;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: LivoraColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isAssigned
              ? LivoraColors.green.withValues(alpha: 0.6)
              : isCenterAssigned
                  ? LivoraColors.forest.withValues(alpha: 0.6)
                  : LivoraColors.forest.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con Estado en Tiempo Real
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 5),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  fmtDate(request.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: LivoraColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Resumen de Materiales y Recompensa Estimada (LIVO Principal)
            Text(
              materialsSummary(request.itemsEstimated),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: LivoraColors.deep,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  request.isDonation
                      ? Icons.volunteer_activism_rounded
                      : Icons.toll,
                  size: 16,
                  color: request.isDonation ? LivoraColors.slate : LivoraColors.forest,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (request.isDonation)
                          const TextSpan(
                            text: 'Entrega Solidaria · 100% cedido al recolector',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.slate,
                            ),
                          )
                        else ...[
                          TextSpan(
                            text: livoEarnings > 0
                                ? 'Recompensa est.: ${livoEarnings.toStringAsFixed(2)} LIVO'
                                : 'Recompensa calculada al pesar',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.forest,
                            ),
                          ),
                          if (livoEarnings > 0)
                            TextSpan(
                              text: ' (≈ S/ ${penEarnings.toStringAsFixed(2)})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: LivoraColors.ink.withValues(alpha: 0.65),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isAssigned &&
                (request.collectorName != null || request.collectorEmail != null)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded, size: 15, color: LivoraColors.slate),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recolector: ${sanitizedPersonName(request.collectorName, request.collectorEmail)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.ink.withValues(alpha: 0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (isCenterAssigned && !isAssigned) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: LivoraColors.forest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warehouse_rounded, size: 18, color: LivoraColors.forest),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.assignedCenterName != null
                                ? 'Acopio: ${request.assignedCenterName}'
                                : 'Centro de Acopio asignado',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.forest,
                            ),
                          ),
                          const Text(
                            'Tarifario confirmado · Visible en el radar de recolectores',
                            style: TextStyle(
                              fontSize: 11,
                              color: LivoraColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Regla de Seguridad del PIN OTP
            if (isAssigned) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LivoraColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LivoraColors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.key_rounded, size: 16, color: LivoraColors.blue),
                        SizedBox(width: 6),
                        Text(
                          'PIN DE ENTREGA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: LivoraColors.deep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OtpPinBox(
                      pin: request.verificationPin ?? '----',
                      isActive: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dicta este PIN al recolector únicamente al entregar y pesar tus materiales.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: LivoraColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: LivoraColors.ink.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: LivoraColors.slate),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAuction
                            ? (request.status == 'AUCTION_ASSIGNED'
                                ? 'Centro de acopio seleccionado. Esperando que un recolector tome el viaje.'
                                : 'Esperando ofertas de centros de acopio. Elige una oferta para que se asigne un recolector.')
                            : (isCenterAssigned
                                ? 'Centro de acopio asignado. Esperando que un recolector tome el viaje hacia tu domicilio.'
                                : 'Buscando un centro de acopio cercano para cotizar tus materiales reciclables. Luego se asignará el recolector.'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: LivoraColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            if (isAuction) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuctionBidsScreen(request: request),
                  ),
                ),
                icon: const Icon(Icons.gavel, size: 16),
                label: Text(
                  'Comparar ofertas de acopio (${request.bids.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Botón de Acción Principal
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: LivoraColors.deep,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onTapDetail,
              icon: Icon(
                isAssigned ? Icons.navigation_outlined : Icons.arrow_forward,
                size: 16,
              ),
              label: Text(
                isAssigned ? 'Seguir recolector en vivo' : 'Ver detalles o cancelar',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
