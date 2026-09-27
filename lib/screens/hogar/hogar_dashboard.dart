import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';
import '../../services/location_service.dart';
import '../../widgets/carbon_impact_modal.dart';
import '../../widgets/center_picker_pin.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_map_tile_layer.dart';
import '../common/profile.dart';
import '../common/wallet_transactions_screen.dart';
import 'create_request_screen.dart';
import 'auction_bids_screen.dart';
import 'request_detail_screen.dart';
import 'recycled_breakdown_screen.dart';
import 'collection_history_screen.dart';

class HogarDashboard extends StatefulWidget {
  const HogarDashboard({super.key});

  @override
  State<HogarDashboard> createState() => _HogarDashboardState();
}

class _HogarDashboardState extends State<HogarDashboard> {
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _dashboardData;
  bool _loadingDashboard = true;
  List<CollectionRequest>? _requests;
  String? _error;

  StreamSubscription<Map<String, dynamic>>? _bidSub;
  StreamSubscription<Map<String, dynamic>>? _collectionSub;
  StreamSubscription<Map<String, dynamic>>? _collectionCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _collectorArrivedSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final realtime = context.read<LivoraRealtime>();
      _bidSub = realtime.on(RealtimeEvents.auctionBid).listen((data) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        final centerName = data['centerName'] ?? 'Un centro de acopio';
        final penn = data['totalEstimatedPenn'];
        final livos = data['totalEstimatedLivo'];
        showAppSnack(
          context,
          'Nueva oferta de $centerName: S/ $penn ($livos LIVOs)',
        );
        _load();
      });
      _collectionSub = realtime.on(RealtimeEvents.collectionUpdated).listen((_) {
        if (mounted) _load();
      });
      _collectionCreatedSub = realtime.on(RealtimeEvents.collectionCreated).listen((_) {
        if (mounted) _load();
      });
      _collectorArrivedSub = realtime.on(RealtimeEvents.collectorArrived).listen((_) {
        if (mounted) _load();
      });
      _notificationSub = realtime.on(RealtimeEvents.notificationCreated).listen((_) {
        if (mounted) _load();
      });
    });
  }

  @override
  void dispose() {
    _bidSub?.cancel();
    _collectionSub?.cancel();
    _collectionCreatedSub?.cancel();
    _collectorArrivedSub?.cancel();
    _notificationSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<LivoraApi>();
    try {
      final results = await Future.wait([
        api.getDashboard(),
        api.collectionRequests(),
      ]);
      if (!mounted) return;
      final reqList = results[1] as List<CollectionRequest>?;
      CollectionRequest? active;
      if (reqList != null) {
        for (final request in reqList) {
          if (request.status == 'PENDING' ||
              request.status == 'AUCTION_ACTIVE' ||
              request.status == 'AUCTION_ASSIGNED' ||
              request.status == 'AUCTION_OPEN' ||
              request.status == 'ACCEPTED' ||
              request.status == 'ASSIGNED' ||
              request.status == 'EN_ROUTE' ||
              request.status == 'ARRIVED') {
            active = request;
            break;
          }
        }
      }
      context.read<SessionController>().updateActiveRequest(active);

      setState(() {
        _dashboardData = results[0] as Map<String, dynamic>?;
        _requests = reqList;
        _loadingDashboard = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loadingDashboard = false;
        });
      }
    }
  }

  /// El backend solo permite una solicitud activa por hogar (PENDING, ACCEPTED, etc.).
  CollectionRequest? get _activeRequest {
    for (final request in _requests ?? const <CollectionRequest>[]) {
      if (request.status == 'PENDING' ||
          request.status == 'AUCTION_ACTIVE' ||
          request.status == 'AUCTION_ASSIGNED' ||
          request.status == 'AUCTION_OPEN' ||
          request.status == 'ACCEPTED' ||
          request.status == 'ASSIGNED' ||
          request.status == 'EN_ROUTE' ||
          request.status == 'ARRIVED') {
        return request;
      }
    }
    return null;
  }

  Future<void> _openCreate() async {
    final session = context.read<SessionController>();
    final active = session.activeRequest ?? _activeRequest;
    if (active != null) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
      showAppSnack(
        context,
        'Ya cuentas con una solicitud activa. Revisa los detalles en la tarjeta superior.',
      );
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openAddressSelectorModal(AuthUser? user) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddressSelectorBottomSheet(user: user),
    );

    if (result == null || !mounted) return;

    final newAddress = result['address'] as String?;
    final newLat = result['latitude'] as double?;
    final newLng = result['longitude'] as double?;

    if (newAddress != null && newAddress.trim().isNotEmpty) {
      try {
        final api = context.read<LivoraApi>();
        final session = context.read<SessionController>();
        await api.updateProfile(
          address: newAddress.trim(),
          latitude: newLat,
          longitude: newLng,
        );
        if (session.user != null) {
          await session.updateUser(
            session.user!.copyWith(
              address: newAddress.trim(),
              latitude: newLat,
              longitude: newLng,
            ),
          );
        }
        if (mounted) {
          showAppSnack(context, 'Dirección de recojo guardada: $newAddress');
        }
      } catch (e) {
        if (mounted) {
          showAppSnack(context, 'Error al actualizar dirección: $e', error: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final active = session.activeRequest ?? _activeRequest;
    final requests = _requests;

    return Scaffold(
      appBar: livoraAppBar(context, 'Hola, ${Roles.label(user?.role ?? '')}'),
      // Si ya existe una solicitud activa, se remueve el FAB para evitar duplicados y solapamientos
      floatingActionButton: active != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.recycling),
              label: const Text('Solicitar recolección'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // Barra Rappi-style de Ubicación de Recojo Activa
            _ActiveAddressBar(
              address: user?.address,
              onTap: () => _openAddressSelectorModal(user),
            ),

            if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: Color(0xFF8C3A3A)),
                  title: Text(
                    _error!,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: TextButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ),
              ),

            // Tarjeta Héroe de Solicitud en Curso (si existe)
            if (active != null)
              _HeroActiveRequestCard(
                request: active,
                onTapDetail: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(requestId: active.id),
                    ),
                  );
                  _load();
                },
              ),

            if (_loadingDashboard) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: const [
                  Card(child: Padding(padding: EdgeInsets.all(12), child: _Skeleton(height: 16, borderRadius: 8))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: _Skeleton(height: 16, borderRadius: 8))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: _Skeleton(height: 16, borderRadius: 8))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: _Skeleton(height: 16, borderRadius: 8))),
                ],
              ),
              const SizedBox(height: 16),
            ] else if (_dashboardData != null) ...[
              Builder(
                builder: (context) {
                  final esg = _dashboardData!['esgMetrics'];
                  final kgRecycled = (esg?['totalKgRecycled'] as num?)?.toDouble() ?? 0.0;
                  final co2Saved = (esg?['co2SavedKg'] as num?)?.toDouble() ?? 0.0;
                  final collections = (esg?['totalCollections'] as num?)?.toInt() ?? 0;
                  final tokenBal = _dashboardData!['wallet']?['balance']?.toString() ?? "0.00";
                  final treesSaved = (co2Saved / 21.7).toStringAsFixed(1);

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    children: [
                      StatCard(
                        icon: Icons.recycling,
                        label: 'Kg reciclados',
                        value: fmtNumber(kgRecycled),
                        unit: 'kg',
                        color: LivoraColors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecycledBreakdownScreen(
                                totalKg: kgRecycled,
                                requests: _requests ?? [],
                              ),
                            ),
                          );
                        },
                      ),
                      StatCard(
                        icon: Icons.toll,
                        label: 'Saldo de LIVOs',
                        value: tokenBal,
                        unit: 'LIVO',
                        subtitle: '≈ S/ $tokenBal PEN',
                        color: LivoraColors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WalletTransactionsScreen(),
                            ),
                          );
                        },
                      ),
                      StatCard(
                        icon: Icons.eco_outlined,
                        label: 'Kg de CO₂ Ahorrado',
                        value: fmtNumber(co2Saved),
                        subtitle: '≈ $treesSaved árboles salvados',
                        color: LivoraColors.amber,
                        onTap: () {
                          CarbonImpactModal.show(
                            context,
                            co2SavedKg: co2Saved,
                          );
                        },
                      ),
                      StatCard(
                        icon: Icons.list_alt,
                        label: 'Recolecciones',
                        value: '$collections',
                        subtitle: 'Ver historial',
                        color: LivoraColors.cyan,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CollectionHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if ((_dashboardData!['esgMetrics']?['totalCollections'] ?? 0) == 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LivoraColors.ink.withValues(alpha: 0.1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.spa_outlined, color: LivoraColors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aún no has generado impacto. ¡Crea tu primer recojo!',
                          style: TextStyle(
                            fontSize: 12,
                            color: LivoraColors.deep,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SectionTitle(text: 'Mis solicitudes'),
            if (requests == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests != null && requests.isEmpty)
              const EmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'Aún no tienes solicitudes',
                message:
                    'Crea tu primera solicitud de recolección y empieza a ganar LIVOs.',
              )
            else if (requests != null)
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequestCard(
                    request: request,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RequestDetailScreen(requestId: request.id),
                        ),
                      );
                      _load();
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final CollectionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      materialsSummary(request.itemsEstimated),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.deep,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: requestStatusLabel(request.status),
                    color: requestStatusColor(request.status),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                fmtDate(request.createdAt) +
                    (request.collectorName != null || request.collectorEmail != null
                        ? ' · Recolector: ${sanitizedPersonName(request.collectorName, request.collectorEmail)}'
                        : ''),
                style: TextStyle(
                  fontSize: 12,
                  color: LivoraColors.ink.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroActiveRequestCard extends StatelessWidget {
  const _HeroActiveRequestCard({
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
          '¡Recolector en tu puerta!',
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
                  ? '¡Recolector en tu puerta!'
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

            // Resumen de Materiales y Ganancia Estimada
            Text(
              materialsSummary(request.itemsEstimated),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: LivoraColors.deep,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              request.hogarEstimatedEarningsPEN > 0
                  ? 'Ganancia est.: ≈ S/ ${request.hogarEstimatedEarningsPEN.toStringAsFixed(2)} PEN (40%)'
                  : 'Ganancia: 40% a liquidar en pesaje',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LivoraColors.forest,
              ),
            ),
            if (isAssigned &&
                (request.collectorName != null || request.collectorEmail != null)) ...[
              const SizedBox(height: 4),
              Text(
                'Recolector: ${sanitizedPersonName(request.collectorName, request.collectorEmail)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: LivoraColors.ink.withValues(alpha: 0.75),
                ),
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

            // Regla de Seguridad del PIN:
            // Ocultar PIN mientras la orden esté en PENDING / sin recolector.
            // Mostrar OTP Box únicamente cuando pase a ASSIGNED / EN_ROUTE / ACCEPTED con recolector.
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

            // Botón de Acción
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
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text(
                'Ver detalles o cancelar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton({this.height, this.borderRadius});

  final double? height;
  final double? borderRadius;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: double.infinity,
            height: widget.height ?? 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
            ),
          ),
        );
      },
    );
  }
}

class _ActiveAddressBar extends StatelessWidget {
  const _ActiveAddressBar({
    required this.address,
    required this.onTap,
  });

  final String? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null && address!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LivoraColors.forest.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: LivoraColors.forest,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Dirección de recojo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAddress ? address! : 'Fijar dirección de recojo...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasAddress ? LivoraColors.deep : LivoraColors.slate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: LivoraColors.mint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasAddress ? 'Cambiar' : 'Fijar',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: LivoraColors.deep,
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

class _AddressSelectorBottomSheet extends StatelessWidget {
  const _AddressSelectorBottomSheet({this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LivoraColors.forest.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: LivoraColors.forest,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dirección de recojo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    Text(
                      'Fija la ubicación para tus solicitudes de recolección',
                      style: TextStyle(
                        fontSize: 12,
                        color: LivoraColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (user?.address != null && user!.address!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: LivoraColors.forest, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dirección actual guardada:',
                          style: TextStyle(fontSize: 11, color: LivoraColors.slate),
                        ),
                        Text(
                          user!.address!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.deep,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Opción 1: GPS Actual
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LivoraColors.mint.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: LivoraColors.deep,
                size: 20,
              ),
            ),
            title: const Text(
              'Usar mi ubicación GPS actual',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Detectar automáticamente vía sensor del teléfono',
              style: TextStyle(fontSize: 11.5),
            ),
            onTap: () async {
              final enabled = await LocationService.isLocationServiceEnabled();
              if (!enabled) {
                if (!context.mounted) return;
                final choice = await showDialog<String>(
                  context: context,
                  builder: (dlgCtx) => AlertDialog(
                    icon: const Icon(Icons.location_off_outlined, color: LivoraColors.forest, size: 36),
                    title: const Text('Ubicación desactivada', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text(
                      'Para detectar tu posición satelital automáticamente, activa el GPS del dispositivo. También puedes buscar tu dirección en el mapa.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dlgCtx, 'MANUAL'),
                        child: const Text('Elegir en el mapa'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dlgCtx, 'SETTINGS');
                          LocationService.openLocationSettings();
                        },
                        child: const Text('Activar GPS'),
                      ),
                    ],
                  ),
                );
                if (choice == 'MANUAL' && context.mounted) {
                  final res = await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _InteractiveMapPickerModal(
                      initialLat: user?.latitude,
                      initialLng: user?.longitude,
                    ),
                  );
                  if (res != null && context.mounted) {
                    Navigator.pop(context, res);
                  }
                }
                return;
              }

              var perm = await LocationService.checkPermission();
              if (perm == LocationPermission.denied) {
                perm = await LocationService.requestPermission();
              }
              if (perm == LocationPermission.deniedForever) {
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (dlgCtx) => AlertDialog(
                    icon: const Icon(Icons.security_outlined, color: LivoraColors.forest, size: 36),
                    title: const Text('Permiso de ubicación requerido', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text(
                      'Livora requiere permiso de ubicación para fijar tu dirección de recojo. Puedes concederlo en los ajustes de la aplicación.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dlgCtx),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dlgCtx);
                          LocationService.openAppSettings();
                        },
                        child: const Text('Abrir Ajustes'),
                      ),
                    ],
                  ),
                );
                return;
              }

              final pos = await LocationService.getCurrentPosition();
              if (pos == null) {
                if (context.mounted) {
                  showAppSnack(
                    context,
                    'No se pudo obtener el GPS actual. Intenta nuevamente o ingresa tu dirección en el mapa.',
                    error: true,
                  );
                }
                return;
              }
              final street = await LocationService.reverseGeocode(
                pos.latitude,
                pos.longitude,
              );
              if (context.mounted) {
                Navigator.pop(context, {
                  'address': street ?? 'Ubicación GPS (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
                  'latitude': pos.latitude,
                  'longitude': pos.longitude,
                });
              }
            },
          ),
          const SizedBox(height: 10),

          // Opción 2: Elegir en el mapa
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LivoraColors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_outlined,
                color: LivoraColors.forest,
                size: 20,
              ),
            ),
            title: const Text(
              'Elegir en el mapa interactivo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Buscar por calle, mover el mapa y fijar pin exacto',
              style: TextStyle(fontSize: 11.5),
            ),
            onTap: () async {
              final res = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _InteractiveMapPickerModal(
                  initialLat: user?.latitude,
                  initialLng: user?.longitude,
                ),
              );
              if (res != null && context.mounted) {
                Navigator.pop(context, res);
              }
            },
          ),
          const SizedBox(height: 10),

          // Opción 3: Escribir manualmente
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            title: const Text(
              'Escribir y buscar dirección',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Ingresar calle y ubicar automáticamente en el mapa',
              style: TextStyle(fontSize: 11.5),
            ),
            onTap: () async {
              final res = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _InteractiveMapPickerModal(
                  initialLat: user?.latitude,
                  initialLng: user?.longitude,
                  initialAddressQuery: user?.address,
                  focusSearch: true,
                ),
              );
              if (res != null && context.mounted) {
                Navigator.pop(context, res);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InteractiveMapPickerModal extends StatefulWidget {
  const _InteractiveMapPickerModal({
    this.initialLat,
    this.initialLng,
    this.initialAddressQuery,
    this.focusSearch = false,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddressQuery;
  final bool focusSearch;

  @override
  State<_InteractiveMapPickerModal> createState() =>
      _InteractiveMapPickerModalState();
}

class _InteractiveMapPickerModalState
    extends State<_InteractiveMapPickerModal> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late double _lat;
  late double _lng;
  String _address = 'Buscando dirección...';
  bool _isDragging = false;
  bool _geocoding = false;

  Timer? _debounceTimer;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat ?? -12.0864; // Miraflores default
    _lng = widget.initialLng ?? -77.0351;
    if (widget.initialAddressQuery != null && widget.initialAddressQuery!.isNotEmpty) {
      _searchController.text = widget.initialAddressQuery!;
      _address = widget.initialAddressQuery!;
    }
    _resolveAddress(_lat, _lng);

    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await LocationService.searchAddress(clean);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = (item['latitude'] as num).toDouble();
    final lng = (item['longitude'] as num).toDouble();
    final addr = item['address'] as String;

    _searchFocusNode.unfocus();
    setState(() {
      _lat = lat;
      _lng = lng;
      _address = addr;
      _searchController.text = addr;
      _searchResults = [];
    });

    _mapController.move(LatLng(lat, lng), 17);
    HapticFeedback.lightImpact();
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    setState(() => _geocoding = true);
    try {
      final street = await LocationService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _address = street ??
              'Ubicación seleccionada (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
          if (!_searchFocusNode.hasFocus) {
            _searchController.text = _address;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address =
            'Coordenadas: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}');
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: LivoraColors.forest),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Fijar ubicación de recojo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Buscador integrado
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              decoration: livoraInput(
                'Buscar dirección o avenida',
                hint: 'Ej: Av. Larco 450, Miraflores',
                icon: Icons.search,
              ).copyWith(
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: LivoraColors.forest),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_lat, _lng),
                    initialZoom: 16,
                    maxZoom: 18,
                    minZoom: 10,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture && !_isDragging) {
                        setState(() => _isDragging = true);
                      }
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        if (_isDragging) {
                          setState(() => _isDragging = false);
                          HapticFeedback.lightImpact();
                          final center = _mapController.camera.center;
                          _lat = center.latitude;
                          _lng = center.longitude;
                          _resolveAddress(_lat, _lng);
                        }
                      }
                    },
                  ),
                  children: const [
                    LivoraMapTileLayer(),
                  ],
                ),
                CenterPickerPin(isDragging: _isDragging),

                // Tarjeta flotante superior con dirección resuelta
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (_geocoding)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: LivoraColors.forest,
                            ),
                          )
                        else
                          const Icon(Icons.place, color: LivoraColors.forest, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: LivoraColors.deep,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Banner de incitación para ajustar el pin a la puerta exacta
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 64,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: LivoraColors.mint.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 18, color: LivoraColors.deep),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mueve el mapa para situar el pin con exactitud en la puerta de tu domicilio.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón GPS flotante
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'map_picker_gps_fab',
                    backgroundColor: Colors.white,
                    foregroundColor: LivoraColors.forest,
                    onPressed: () async {
                      final enabled = await LocationService.isLocationServiceEnabled();
                      if (!enabled) {
                        LocationService.openLocationSettings();
                        return;
                      }
                      final pos = await LocationService.getCurrentPosition();
                      if (pos != null && mounted) {
                        _lat = pos.latitude;
                        _lng = pos.longitude;
                        _mapController.move(LatLng(_lat, _lng), 17);
                        _resolveAddress(_lat, _lng);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),

                // Lista flotante de sugerencias predictivas de búsqueda
                if (_searchResults.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, color: LivoraColors.forest, size: 20),
                            title: Text(
                              item['address'] as String,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(item),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text(
                  'Confirmar esta ubicación',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    'address': _address,
                    'latitude': _lat,
                    'longitude': _lng,
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
