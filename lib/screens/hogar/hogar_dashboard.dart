import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/carbon_impact_modal.dart';
import '../../widgets/common.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
              request.status == 'ACCEPTED' ||
              request.status == 'AUCTION_OPEN' ||
              request.status == 'ASSIGNED' ||
              request.status == 'IN_ROUTE') {
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
          request.status == 'ACCEPTED' ||
          request.status == 'AUCTION_OPEN' ||
          request.status == 'ASSIGNED' ||
          request.status == 'IN_ROUTE') {
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
                        label: 'Saldo EcoTokens',
                        value: tokenBal,
                        unit: 'ECO',
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
                    'Crea tu primera solicitud de recolección y empieza a ganar EcoTokens.',
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
    final isAssigned = request.status == 'ACCEPTED' ||
        request.status == 'ASSIGNED' ||
        request.status == 'IN_ROUTE' ||
        request.collectorName != null ||
        request.collectorEmail != null;

    final (badgeLabel, badgeColor, badgeIcon) = switch (request.status) {
      'ACCEPTED' || 'ASSIGNED' || 'IN_ROUTE' => (
          'Recolector en camino',
          LivoraColors.green,
          Icons.delivery_dining,
        ),
      'AUCTION_OPEN' => (
          'Subasta · ${request.bids.length} ${request.bids.length == 1 ? 'oferta' : 'ofertas'}',
          Colors.indigo,
          Icons.gavel,
        ),
      _ => isAuction
          ? (
              'Subasta abierta · ${request.bids.length} ${request.bids.length == 1 ? 'oferta' : 'ofertas'}',
              Colors.indigo,
              Icons.gavel,
            )
          : (
              'Buscando acopio',
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
            const SizedBox(height: 14),

            // Regla de Seguridad del PIN:
            // Ocultar PIN mientras la orden esté en PENDING / sin recolector.
            // Mostrar OTP Box únicamente cuando pase a ASSIGNED / IN_ROUTE / ACCEPTED con recolector.
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
                            ? 'Esperando ofertas de centros de acopio. Elige una oferta para que se asigne un recolector.'
                            : 'Esperando asignación de recolector. El PIN de entrega se activará cuando un recolector tome tu pedido.',
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
