import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';
import '../models/models.dart';
import 'common.dart';
import 'verification_otp_modal.dart';

/// Tarjeta Héroe multiparada desacoplada y anclada en la parte superior (Sticky Header)
/// del radar para pedidos activos en ruta (ACCEPTED / IN_ROUTE).
///
/// Implementa ordenamiento inteligente por cercanía GPS, selector secuencial de paradas
/// (Parada X de Y) y botones de acción directa: Navegar (Maps/Waze), Llamar y Validar PIN.
class ActiveRouteHeroCard extends StatefulWidget {
  const ActiveRouteHeroCard({
    super.key,
    required this.requests,
    this.userLat,
    this.userLng,
    required this.onVerificationCompleted,
  });

  final List<CollectionRequest> requests;
  final double? userLat;
  final double? userLng;
  final VoidCallback onVerificationCompleted;

  @override
  State<ActiveRouteHeroCard> createState() => _ActiveRouteHeroCardState();
}

class _ActiveRouteHeroCardState extends State<ActiveRouteHeroCard> {
  int _currentIndex = 0;

  List<CollectionRequest> get _sortedRequests {
    final list = List<CollectionRequest>.from(widget.requests);
    if (widget.userLat != null && widget.userLng != null) {
      list.sort((a, b) {
        final distA = a.distanceMeters ?? double.infinity;
        final distB = b.distanceMeters ?? double.infinity;
        return distA.compareTo(distB);
      });
    }
    return list;
  }

  @override
  void didUpdateWidget(covariant ActiveRouteHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex >= widget.requests.length) {
      _currentIndex = 0;
    }
  }

  Future<void> _openNavigation(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    final lat = request.latitude;
    final lng = request.longitude;

    // Intent geo nativo para Google Maps / Waze con fallback a URL web
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final webMapsUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final wazeUri =
        Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showAppSnack(
            context,
            'No se encontró una aplicación de mapas compatible',
            error: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al iniciar la navegación GPS', error: true);
      }
    }
  }

  Future<void> _makeCall(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    final phone = request.householdPhone?.trim();
    if (phone == null || phone.isEmpty) {
      showAppSnack(context, 'El Hogar no registró un número telefónico');
      return;
    }

    final telUri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        if (mounted) {
          showAppSnack(context, 'No se pudo iniciar la llamada telefónica',
              error: true);
        }
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al abrir la app de llamadas', error: true);
      }
    }
  }

  Future<void> _openOtpModal(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    final verified = await VerificationOtpModal.show(context, request: request);
    if (verified == true) {
      widget.onVerificationCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedRequests;
    if (sorted.isEmpty) return const SizedBox.shrink();

    final safeIndex = _currentIndex.clamp(0, sorted.length - 1);
    final current = sorted[safeIndex];

    final householdName = sanitizedPersonName(
      current.householdName,
      current.householdEmail,
      defaultLabel: 'Hogar',
    );
    final householdAddress = current.householdAddress?.isNotEmpty == true
        ? current.householdAddress!
        : 'Ubicación verificada por GPS';

    final centerName = sanitizedCenterName(
      current.assignedCenterName,
      current.assignedCenterEmail,
      defaultLabel: 'Acopio Asignado',
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LivoraColors.forest, width: 2),
        boxShadow: [
          BoxShadow(
            color: LivoraColors.forest.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Badge EN RUTA + Carrusel Selector de Paradas
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LivoraColors.forest.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: LivoraColors.forest.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_bike_rounded,
                      size: 15,
                      color: LivoraColors.forest,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'EN RUTA',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: LivoraColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (sorted.length > 1) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: safeIndex > 0
                      ? () {
                          HapticFeedback.lightImpact();
                          setState(() => _currentIndex = safeIndex - 1);
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                ),
                Text(
                  'Parada ${safeIndex + 1} de ${sorted.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: safeIndex < sorted.length - 1
                      ? () {
                          HapticFeedback.lightImpact();
                          setState(() => _currentIndex = safeIndex + 1);
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                ),
              ] else
                const Text(
                  'Parada 1 de 1',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Información del Hogar y Acopio Destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      householdName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      householdAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: LivoraColors.ink.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: LivoraColors.mint.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: LivoraColors.mint.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  centerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: LivoraColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Resumen de Materiales y Garantía
          Row(
            children: [
              Expanded(
                child: Text(
                  materialsSummary(current.itemsEstimated),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: LivoraColors.forest,
                  ),
                ),
              ),
              StatusChip(
                label:
                    'Garantía: ${current.requiredEscrow.toStringAsFixed(1)} ECO',
                color: LivoraColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Acciones Directas: Navegar | Llamar | Validar Entrega
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: LivoraColors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openNavigation(current),
                  icon: const Icon(
                    Icons.navigation_outlined,
                    size: 16,
                    color: LivoraColors.blue,
                  ),
                  label: const Text(
                    'Navegar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: LivoraColors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _makeCall(current),
                  icon: const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: LivoraColors.deep,
                  ),
                  label: const Text(
                    'Llamar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: LivoraColors.forest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openOtpModal(current),
                  icon: const Icon(Icons.pin_outlined, size: 16),
                  label: const Text(
                    'Validar Entrega',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
