import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_shimmer.dart';
import '../common/profile.dart';
import '../common/stores_catalog_screen.dart';
import 'collection_history_screen.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';
import 'widgets/hero_active_request_card.dart';
import 'widgets/hogar_active_address_bar.dart';
import 'widgets/hogar_esg_stats_grid.dart';
import 'widgets/hogar_first_steps_dialog.dart';

/// Pantalla principal del HOGAR.
/// Optimizado, modularizado y con tokenomics LIVO como moneda principal y S/ secundario.
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
      HogarFirstStepsDialog.checkAndShow(context);
      final realtime = context.read<LivoraRealtime>();
      _bidSub = realtime.on(RealtimeEvents.auctionBid).listen((data) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        final centerName = data['centerName'] ?? 'Un centro de acopio';
        final penn = data['totalEstimatedPenn'];
        final livos = data['totalEstimatedLivo'] ?? penn;
        showAppSnack(
          context,
          'Nueva oferta de $centerName: $livos LIVO (≈ S/ $penn)',
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

  /// El backend solo permite una solicitud activa por hogar.
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
      builder: (sheetContext) => AddressSelectorBottomSheet(user: user),
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
            // Barra de Ubicación de Recojo Activa estilo Rappi
            HogarActiveAddressBar(
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
              HeroActiveRequestCard(
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

            // Métricas ESG y Saldo LIVO
            if (_loadingDashboard) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: const [
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                ],
              ),
              const SizedBox(height: 16),
            ] else if (_dashboardData != null) ...[
              HogarEsgStatsGrid(
                dashboardData: _dashboardData!,
                requests: _requests ?? [],
              ),
              const SizedBox(height: 16),

              // Banner educativo y motivacional para nuevos hogares
              if ((_dashboardData!['esgMetrics']?['totalCollections'] ?? 0) == 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        LivoraColors.mint.withValues(alpha: 0.3),
                        LivoraColors.paper,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: LivoraColors.forest.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.eco_rounded, color: LivoraColors.forest, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inicia tu primera recolección domiciliaria',
                              style: TextStyle(
                                fontSize: 13,
                                color: LivoraColors.deep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Separa plástico o cartón en casa, solicita el recojo y canjea tus LIVOs en tiendas aliadas.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: LivoraColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if ((_dashboardData!['esgMetrics']?['totalCollections'] ?? 0) > 0)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  color: LivoraColors.forest.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: LivoraColors.forest.withValues(alpha: 0.2)),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StoresCatalogScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: LivoraColors.forest.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
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
                                  'Canjea tus LIVOs en comercios aliados',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: LivoraColors.deep,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'BioFerias, cafeterías y minimarkets cercanos en Lima',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: LivoraColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: LivoraColors.forest,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionTitle(text: 'Mis solicitudes'),
                if (requests != null && requests.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: LivoraColors.forest,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CollectionHistoryScreen(),
                        ),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text(
                      'Ver todas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            if (requests == null && _error == null)
              const LivoraShimmerList(itemCount: 3)
            else if (requests != null && requests.isEmpty)
              const EmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'Aún no tienes solicitudes',
                message:
                    'Crea tu primera solicitud de recolección y empieza a acumular LIVOs.',
              )
            else if (requests != null) ...[
              for (final request in requests.take(5))
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
              if (requests.length > 5) ...[
                const SizedBox(height: 2),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LivoraColors.forest,
                    side: BorderSide(color: LivoraColors.forest.withValues(alpha: 0.35)),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CollectionHistoryScreen(),
                      ),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                  label: Text(
                    'Ver historial completo (${requests.length} solicitudes)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
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
    final weights = request.actualWeights ?? request.itemsEstimated;
    final totalKg = weights.values.fold<double>(0.0, (s, w) => s + w);
    final reward = request.householdRewardEarned;

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${fmtKg(totalKg)} · ${fmtDate(request.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: LivoraColors.ink.withValues(alpha: 0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (request.isDonation)
                    const Text(
                      'Donación Solidaria',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.slate,
                      ),
                    )
                  else if (reward > 0)
                    Text(
                      '+${reward.toStringAsFixed(2)} LIVO',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.forest,
                      ),
                    )
                  else if (request.hogarEstimatedEarningsPEN > 0 && request.status != 'CANCELLED')
                    Text(
                      '~${request.hogarEstimatedEarningsPEN.toStringAsFixed(2)} LIVO',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB7791F),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
