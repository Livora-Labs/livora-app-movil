import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';
import '../models/models.dart';
import '../services/livora_api.dart';
import 'common.dart';
import 'verification_otp_modal.dart';

/// Tarjeta Héroe multiparada desacoplada y anclada en la parte superior (Sticky Header)
/// del radar para pedidos activos en ruta (ACCEPTED / EN_ROUTE / ARRIVED).
///
/// Implementa ordenamiento inteligente por cercanía GPS, selector secuencial de paradas
/// (Parada X de Y) y botones de acción directa: Navegar (Maps/Waze), Llamar,
/// Iniciar Ruta, Notificar Llegada, Validar PIN, Reportar Inasistencia y Rechazo en Sitio.
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
  bool _busy = false;

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

  Future<void> _startRoute(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await context.read<LivoraApi>().startRoute(request.id);
      if (mounted) {
        showAppSnack(context, 'Ruta iniciada hacia el hogar');
        widget.onVerificationCompleted();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reachDestination(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await context.read<LivoraApi>().reachDestination(request.id);
      if (mounted) {
        showAppSnack(context, 'Llegada notificada al hogar. Solicita el PIN de verificación.');
        widget.onVerificationCompleted();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportNoShow(CollectionRequest request) async {
    final arrivedAt = request.arrivedAt;
    if (arrivedAt != null) {
      final elapsedMinutes = DateTime.now().difference(arrivedAt).inMinutes;
      if (elapsedMinutes < 10) {
        final remaining = 10 - elapsedMinutes;
        showAppSnack(
          context,
          'Debes esperar 10 minutos reglamentarios frente al domicilio (faltan $remaining min).',
          error: true,
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reportar Inasistencia del Hogar'),
        content: const Text(
          'Se cancelará la recolección por inasistencia. Se liberará tu garantía de depósito, recibirás 2.0 EcoTokens de compensación por traslado y se penalizará la reputación del hogar.\n\n¿Deseas confirmar el reporte?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC53030)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Inasistencia'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<LivoraApi>().reportNoShow(request.id);
      if (mounted) {
        showAppSnack(context, 'Inasistencia reportada. Garantía liberada y compensación acreditada.');
        widget.onVerificationCompleted();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectOnSite(CollectionRequest request) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Recolección en Sitio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indica el motivo técnico del rechazo (ej. materiales contaminados, orgánicos mezclados o peso discrepante):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Describe el estado de los materiales...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC53030)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      showAppSnack(context, 'Debes ingresar un motivo del rechazo en sitio.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<LivoraApi>().rejectOnSite(request.id, reason);
      if (mounted) {
        showAppSnack(context, 'Recolección rechazada en sitio. Garantía liberada.');
        widget.onVerificationCompleted();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
          // Header: Badge de Estado de Ruta + Carrusel Selector de Paradas
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (current.status == 'ARRIVED'
                          ? LivoraColors.green
                          : (current.status == 'EN_ROUTE'
                              ? LivoraColors.forest
                              : LivoraColors.blue))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (current.status == 'ARRIVED'
                            ? LivoraColors.green
                            : (current.status == 'EN_ROUTE'
                                ? LivoraColors.forest
                                : LivoraColors.blue))
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      current.status == 'ARRIVED'
                          ? Icons.pin_drop_rounded
                          : (current.status == 'EN_ROUTE'
                              ? Icons.directions_bike_rounded
                              : Icons.schedule_rounded),
                      size: 15,
                      color: current.status == 'ARRIVED'
                          ? LivoraColors.green
                          : (current.status == 'EN_ROUTE'
                              ? LivoraColors.forest
                              : LivoraColors.blue),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      current.status == 'ARRIVED'
                          ? 'EN PUERTA'
                          : (current.status == 'EN_ROUTE' ? 'EN RUTA' : 'ASIGNADA'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: current.status == 'ARRIVED'
                            ? LivoraColors.green
                            : (current.status == 'EN_ROUTE'
                                ? LivoraColors.forest
                                : LivoraColors.blue),
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

          // Acciones de Navegación y Contacto Directo
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
            ],
          ),
          const SizedBox(height: 10),

          // Progresión de Ruta y Contingencias según FSM 2
          if (current.status == 'ACCEPTED')
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: LivoraColors.forest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _busy ? null : () => _startRoute(current),
              icon: const Icon(Icons.directions_bike_rounded, size: 18),
              label: const Text(
                'Iniciar Ruta al Domicilio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          else if (current.status == 'EN_ROUTE')
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: LivoraColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _busy ? null : () => _reachDestination(current),
              icon: const Icon(Icons.pin_drop_rounded, size: 18),
              label: const Text(
                'Llegué al Domicilio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          else if (current.status == 'ARRIVED') ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: LivoraColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _busy ? null : () => _openOtpModal(current),
              icon: const Icon(Icons.pin_outlined, size: 18),
              label: const Text(
                'Validar PIN del Hogar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC53030),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _busy ? null : () => _reportNoShow(current),
                    icon: const Icon(Icons.timer_off_outlined, size: 15),
                    label: const Text('Inasistencia (10 min)', style: TextStyle(fontSize: 11)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC53030),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _busy ? null : () => _rejectOnSite(current),
                    icon: const Icon(Icons.block_outlined, size: 15),
                    label: const Text('Rechazar en Sitio', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
