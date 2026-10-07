import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/session.dart';
import '../../../../data/repositories/collection_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/livora_realtime.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/view_state_scaffold.dart';
import '../../../../screens/hogar/gamification/batch_celebration_dialog.dart';
import '../view_model/request_detail_view_model.dart';
import '../widgets/collector_telemetry_card.dart';
import '../widgets/edit_request_materials_dialog.dart';
import '../widgets/request_actions_header.dart';
import '../widgets/request_auction_bids_section.dart';
import '../widgets/request_materials_section.dart';
import '../widgets/request_map_section.dart';
import '../widgets/request_rating_card.dart';
import '../widgets/request_security_pin_card.dart';

/// Vista de Detalle de Solicitud de Recolección (HOGAR).
/// Arquitectura MVVM reactiva (<250 líneas) conectada al RequestDetailViewModel.
class RequestDetailView extends StatelessWidget {
  const RequestDetailView({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => RequestDetailViewModel(
        requestId: requestId,
        repository: CollectionRepository(api: ctx.read<LivoraApi>()),
        realtime: ctx.read<LivoraRealtime>(),
      ),
      child: const _RequestDetailContent(),
    );
  }
}

class _RequestDetailContent extends StatefulWidget {
  const _RequestDetailContent();

  @override
  State<_RequestDetailContent> createState() => _RequestDetailContentState();
}

class _RequestDetailContentState extends State<_RequestDetailContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<RequestDetailViewModel>();
      vm.eventNotifier.addListener(() {
        final event = vm.eventNotifier.value;
        if (event == null || !mounted) return;

        if (event == 'SHOW_CELEBRATION') {
          final req = vm.request;
          if (req != null) {
            final reward = req.householdRewardEarned > 0 ? req.householdRewardEarned : req.escrowLocked;
            final kgActual = req.actualWeights?.values.fold<double>(0.0, (s, w) => s + w) ?? 0.0;
            final kgEstimated = req.itemsEstimated.values.fold<double>(0.0, (s, w) => s + w);
            final totalKg = kgActual > 0 ? kgActual : kgEstimated;

            BatchCelebrationDialog.show(
              context,
              rewardLivo: reward,
              kgRecycled: totalKg,
              co2SavedKg: totalKg * 2.5,
              txHash: req.txHash,
              isDonation: req.isDonation,
            );
          }
        } else if (event == 'COLLECTOR_ARRIVED') {
          HapticFeedback.vibrate();
          showAppSnack(context, 'El recolector ha llegado al domicilio. Muestra tu código PIN.');
        } else if (event == 'GEOFENCE_ALERT') {
          HapticFeedback.heavyImpact();
          showAppSnack(context, 'Tu recolector está a menos de 50 metros. Acércate a la puerta.');
        } else if (event == 'REQUEST_EDITED') {
          showAppSnack(context, 'Solicitud actualizada con éxito.');
        } else if (event == 'BID_SELECTED') {
          showAppSnack(context, 'Oferta aceptada. El centro coordinará el recojo.');
        } else if (event == 'RATING_SUBMITTED') {
          showAppSnack(context, '¡Muchas gracias por calificar el servicio!');
        }
      });
    });
  }

  Future<void> _handleCancel(BuildContext context, RequestDetailViewModel vm, CollectionRequest req) async {
    final hasCollector = req.collectorName != null;
    final confirmed = await confirmDialog(
      context,
      title: 'Cancelar solicitud',
      message: hasCollector
          ? 'El recolector ya está asignado. ¿Seguro que deseas cancelar?'
          : '¿Estás seguro de que deseas cancelar esta solicitud?',
      confirmLabel: 'Sí, cancelar',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      await vm.cancelRequest();
      if (context.mounted) {
        context.read<SessionController>().updateActiveRequest(null);
        context.read<SessionController>().notifyBatchesChanged();
        showAppSnack(context, 'Solicitud cancelada.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RequestDetailViewModel>();
    final state = vm.state;
    final req = state.dataOrNull;

    final canEdit = req != null &&
        (req.status == 'PENDING' || req.status == 'AUCTION_OPEN' || req.status == 'AUCTION_ACTIVE');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Solicitud'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Editar solicitud',
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: () => EditRequestMaterialsDialog.show(
                context,
                request: req,
                viewModel: vm,
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => vm.loadRequest(forceRefresh: true),
          ),
        ],
      ),
      body: ViewStateScaffold(
        isLoading: state.isLoading && req == null,
        hasError: state.isError && req == null,
        errorMessage: state is UIError<CollectionRequest> ? state.message : null,
        onRetry: () => vm.loadRequest(forceRefresh: true),
        onRefresh: () => vm.loadRequest(forceRefresh: true),
        child: req == null
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () => vm.loadRequest(forceRefresh: true),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                      children: [
                        // 1. Banner superior de estado
                        RequestActionsHeader(request: req),
                        const SizedBox(height: 14),

                        // 2. Mapa geoespacial (si está en ruta o asignado)
                        if (req.status == 'EN_ROUTE' || req.status == 'ACCEPTED' || req.status == 'ARRIVED') ...[
                          RequestMapSection(
                            householdLat: req.latitude,
                            householdLng: req.longitude,
                            collectorPos: vm.collectorPos,
                            collectorHeading: vm.collectorHeading,
                            polylinePoints: vm.polylinePoints,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 3. Tarjeta de telemetría del recolector
                        if (req.collectorName != null) ...[
                          CollectorTelemetryCard(
                            collectorName: req.collectorName!,
                            collectorPhone: req.collectorPhone,
                            transportType: vm.transportType,
                            etaMinutes: vm.etaMinutes,
                            distanceMeters: vm.distanceMeters,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 4. PIN de seguridad para entrega física
                        if (req.verificationPin != null &&
                            (req.status == 'PENDING' ||
                                req.status == 'ACCEPTED' ||
                                req.status == 'EN_ROUTE' ||
                                req.status == 'ARRIVED')) ...[
                          RequestSecurityPinCard(pin: req.verificationPin!),
                          const SizedBox(height: 14),
                        ],

                        // 4.1 Calificación de Servicio al Recolector (RF-12)
                        if (req.status == 'COMPLETED' && (req.collectorName != null || req.collectorId != null)) ...[
                          RequestRatingCard(
                            collectorName: req.collectorName ?? 'Recolector asignado',
                            isSubmitting: vm.isSubmittingRating,
                            existingRating: req.rating,
                            existingFeedback: req.feedback,
                            onSubmitRating: (stars, comment) => vm.submitRating(rating: stars, feedback: comment),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 5. Desglose de materiales y balanza ecológica
                        RequestMaterialsSection(request: req),
                        const SizedBox(height: 16),

                        // 6. Ofertas de Centros de Acopio en Subasta
                        if (req.assignmentMode == 'AUCTION' || req.bids.isNotEmpty) ...[
                          RequestAuctionBidsSection(
                            request: req,
                            selectingBidId: vm.selectingBidId,
                            onSelectBid: (bidId) => vm.selectBid(bidId),
                            onRefresh: () => vm.loadRequest(forceRefresh: true),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 7. Modificar materiales / indicaciones
                        if (canEdit) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LivoraColors.forest,
                              side: const BorderSide(color: LivoraColors.forest),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Editar materiales de la solicitud'),
                            onPressed: () => EditRequestMaterialsDialog.show(
                              context,
                              request: req,
                              viewModel: vm,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 8. Botón de Cancelación
                        if (req.status == 'PENDING' ||
                            req.status == 'ACCEPTED' ||
                            req.status == 'AUCTION_OPEN' ||
                            req.status == 'AUCTION_ACTIVE')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LivoraColors.coral,
                              side: const BorderSide(color: LivoraColors.coral),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: vm.isCancelling
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.cancel_outlined),
                            label: Text(vm.isCancelling ? 'Cancelando...' : 'Cancelar Solicitud'),
                            onPressed: vm.isCancelling ? null : () => _handleCancel(context, vm, req),
                          ),
                      ],
                    ),
                  ),
                  if (vm.incomingBidToast != null)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: _IncomingBidToastWidget(
                        data: vm.incomingBidToast!,
                        secondsLeft: vm.bidToastSecondsLeft,
                        onDismiss: () => vm.dismissBidToast(),
                        onViewOffers: () => vm.dismissBidToast(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _IncomingBidToastWidget extends StatelessWidget {
  const _IncomingBidToastWidget({
    required this.data,
    required this.secondsLeft,
    required this.onDismiss,
    required this.onViewOffers,
  });

  final Map<String, dynamic> data;
  final int secondsLeft;
  final VoidCallback onDismiss;
  final VoidCallback onViewOffers;

  @override
  Widget build(BuildContext context) {
    final centerName = data['centerName'] ?? 'Centro de Acopio';
    final livos = (data['totalEstimatedLivo'] as num?)?.toDouble() ?? 0.0;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black45,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade400, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '¡Nueva oferta de acopio recibida!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Text(
                  '${secondsLeft}s',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$centerName ofrece una cotización estimada de ${livos.toStringAsFixed(2)} LIVO.',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onDismiss,
                  child: const Text('Ignorar', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade400,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onViewOffers,
                  child: const Text(
                    'Ver ofertas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

