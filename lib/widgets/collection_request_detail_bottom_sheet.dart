import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';
import '../models/models.dart';
import 'common.dart';
import 'kyc_required_bottom_sheet.dart';

/// Modal BottomSheet deslizable para ver el detalle interactivo completo de una solicitud (Tap-to-Expand).
class CollectionRequestDetailBottomSheet extends StatelessWidget {
  const CollectionRequestDetailBottomSheet({
    super.key,
    required this.request,
    required this.walletBalance,
    this.userLat,
    this.userLng,
    this.kycStatus = KycStatus.approved,
    this.onKycRequired,
    required this.onAccept,
    required this.onRechargeNeeded,
  });

  final CollectionRequest request;
  final double walletBalance;
  final double? userLat;
  final double? userLng;
  final KycStatus kycStatus;
  final VoidCallback? onKycRequired;
  final VoidCallback onAccept;
  final VoidCallback onRechargeNeeded;

  static Future<void> show(
    BuildContext context, {
    required CollectionRequest request,
    required double walletBalance,
    double? userLat,
    double? userLng,
    KycStatus kycStatus = KycStatus.approved,
    VoidCallback? onKycRequired,
    required VoidCallback onAccept,
    required VoidCallback onRechargeNeeded,
  }) async {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CollectionRequestDetailBottomSheet(
        request: request,
        walletBalance: walletBalance,
        userLat: userLat,
        userLng: userLng,
        kycStatus: kycStatus,
        onKycRequired: onKycRequired,
        onAccept: onAccept,
        onRechargeNeeded: onRechargeNeeded,
      ),
    );
  }

  Future<void> _launchMaps(BuildContext context) async {
    HapticFeedback.lightImpact();
    final lat = request.latitude;
    final lng = request.longitude;
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final webMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showAppSnack(context, 'No se pudo abrir la aplicación de mapas', error: true);
        }
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Error al abrir mapas', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = request.distanceMeters;
    final hasEnoughEscrow = walletBalance >= request.requiredEscrow;
    final isAuction = request.assignmentMode == 'AUCTION';

    final householdLabel = sanitizedPersonName(
      request.householdName,
      request.householdEmail,
      defaultLabel: 'Hogar',
    );
    final householdAddress = request.householdAddress?.isNotEmpty == true
        ? request.householdAddress!
        : 'Dirección física registrada vía GPS';
    final centerName = sanitizedCenterName(
      request.assignedCenterName,
      request.assignedCenterEmail,
      defaultLabel: 'Centro de Acopio Asignado',
    );

    final totalPEN = request.totalEstimatedValuePEN;
    final hogarPEN = totalPEN * 0.40;
    final livoraPEN = totalPEN * 0.10;
    final recolectorPEN = totalPEN * 0.50;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (sheetContext, scrollController) => Column(
        children: [
          // Tirador táctil (Drag Handle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Contenido con Scroll
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                // Cabecera: Título y Badges (Modalidad y Estado)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Solicitud #${request.shortId}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAuction
                            ? Colors.purple.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAuction
                              ? Colors.purple.shade200
                              : Colors.amber.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isAuction ? 'Subasta' : 'Directa',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isAuction
                                  ? Colors.purple.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: requestStatusLabel(request.status),
                      color: requestStatusColor(request.status),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Visor de Evidencia Fotográfica
                if (request.photoUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: request.photoUrl!,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 800,
                      memCacheHeight: 600,
                      placeholder: (context, url) => Container(
                        height: 190,
                        color: LivoraColors.forest.withValues(alpha: 0.08),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 190,
                        color: LivoraColors.paper,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: LivoraColors.ink,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Información de Ubicación Completa
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_pin_circle_outlined,
                              color: LivoraColors.forest, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              householdLabel,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ),
                          if (distance != null)
                            StatusChip(
                              label: '${(distance / 1000).toStringAsFixed(1)} km',
                              color: LivoraColors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: LivoraColors.forest),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              householdAddress,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (request.latitude != 0 && request.longitude != 0) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              side: const BorderSide(color: LivoraColors.forest),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _launchMaps(context),
                            icon: const Icon(Icons.map_outlined, size: 16, color: LivoraColors.forest),
                            label: const Text(
                              'Ver en Google Maps / Waze',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Resumen de Materiales
                const SectionTitle(text: 'Materiales declarados'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Column(
                    children: [
                      for (final entry in request.itemsEstimated.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.recycling_rounded, size: 16, color: LivoraColors.forest),
                                  const SizedBox(width: 8),
                                  Text(
                                    materialLabel(entry.key),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: LivoraColors.deep,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                fmtKg(entry.value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: LivoraColors.deep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (request.description?.isNotEmpty == true) ...[
                        const Divider(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes, size: 16, color: LivoraColors.ink),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                request.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: LivoraColors.ink.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Centro de Acopio Asignado
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warehouse_rounded, size: 20, color: LivoraColors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Centro de Acopio Destino',
                              style: TextStyle(fontSize: 10.5, color: LivoraColors.blue, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              centerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Desglose Transparente de Garantía de Recolección
                const SectionTitle(text: 'Garantía Temporal de Recolección'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor bruto estimado:', style: TextStyle(fontSize: 12.5)),
                          Text(
                            'S/ ${totalPEN.toStringAsFixed(2)} PEN',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.home_outlined, size: 14, color: LivoraColors.forest),
                              SizedBox(width: 6),
                              Text('Pago al Hogar (40%):', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(
                            'S/ ${hogarPEN.toStringAsFixed(2)} PEN',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: LivoraColors.blue),
                              SizedBox(width: 6),
                              Text('Tarifa plataforma Livora (10%):', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(
                            'S/ ${livoraPEN.toStringAsFixed(2)} PEN',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF2E7D32)),
                              SizedBox(width: 6),
                              Text(
                                'Margen neto recolector (50%):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                              ),
                            ],
                          ),
                          Text(
                            'S/ ${recolectorPEN.toStringAsFixed(2)} PEN',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: LivoraColors.paper,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Garantía temporal a retener:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                            ),
                            Text(
                              '${request.requiredEscrow.toStringAsFixed(2)} ECO',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nota: Esta garantía temporal se retiene de tu monedero y se devuelve íntegramente al validar la entrega en el centro de acopio mediante el PIN de 4 dígitos.',
                  style: TextStyle(
                    fontSize: 11,
                    color: LivoraColors.ink.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),

          // Barra Fija Inferior de Acción Principal
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: _buildActionButton(sheetContext, hasEnoughEscrow),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext sheetContext, bool hasEnoughEscrow) {
    if (kycStatus != KycStatus.approved) {
      final (label, color, icon) = switch (kycStatus) {
        KycStatus.unverified => (
            'Verificar Identidad para Aceptar',
            const Color(0xFFD97706),
            Icons.shield_outlined,
          ),
        KycStatus.pending => (
            'Verificación en Revisión',
            const Color(0xFFD97706),
            Icons.hourglass_top_rounded,
          ),
        KycStatus.rejected => (
            'Reintentar Verificación',
            const Color(0xFFC0392B),
            Icons.gpp_bad_rounded,
          ),
        KycStatus.approved => (
            'Aceptar recolección',
            LivoraColors.forest,
            Icons.check_circle_outline,
          ),
      };

      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(sheetContext);
          if (onKycRequired != null) {
            onKycRequired!();
          } else {
            KycRequiredBottomSheet.show(sheetContext, kycStatus: kycStatus);
          }
        },
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (hasEnoughEscrow) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: LivoraColors.forest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(sheetContext);
          onAccept();
        },
        icon: const Icon(Icons.check_circle_outline, size: 20),
        label: Text(
          'Aceptar recolección (${request.requiredEscrow.toStringAsFixed(1)} ECO)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: const Color(0xFFD97706),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(sheetContext);
          onRechargeNeeded();
        },
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
        label: const Text(
          'Saldo insuficiente · Recargar vía Niubiz',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}
