import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

/// Pantalla de visualización y postulación de subastas de recolección para CENTRO_ACOPIO.
class CenterAuctionsScreen extends StatefulWidget {
  const CenterAuctionsScreen({super.key});

  @override
  State<CenterAuctionsScreen> createState() => _CenterAuctionsScreenState();
}

class _CenterAuctionsScreenState extends State<CenterAuctionsScreen> {
  List<CollectionRequest> _directRequests = [];
  List<CollectionRequest> _auctionRequests = [];
  Map<String, double> _centerPriceMap = {};
  String? _claimingId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final centerId = session.user?.id;
      final api = context.read<LivoraApi>();

      final results = await Future.wait([
        api.collectionRequests(page: 1, limit: 50),
        centerId != null
            ? api
                .fetchCenterPrices(centerId)
                .catchError((_) => <AcopioPriceList>[])
            : Future.value(<AcopioPriceList>[]),
      ]);

      final all = results[0] as List<CollectionRequest>;
      final prices = results[1] as List<AcopioPriceList>;
      final priceMap = <String, double>{};
      for (final p in prices) {
        priceMap[p.materialType.toUpperCase()] = p.pricePerKg;
      }

      final directs = all
          .where((r) =>
              (r.assignmentMode == 'AUTOMATIC' || r.assignmentMode.isEmpty) &&
              r.status == 'PENDING' &&
              r.assignedCenterId == null)
          .toList();

      final auctions = all
          .where((r) => r.assignmentMode == 'AUCTION' && r.status == 'PENDING')
          .toList();

      if (mounted) {
        setState(() {
          _directRequests = directs;
          _auctionRequests = auctions;
          _centerPriceMap = priceMap;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _claimDirectOrder(CollectionRequest request) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Tomar Solicitud Directa',
      message:
          'Al tomar la solicitud #${request.shortId}, se asignará a tu centro aplicando tu tarifario de compra vigente. La orden pasará inmediatamente al radar de los recolectores en ruta.',
      confirmLabel: 'Tomar orden',
    );
    if (!confirmed || !mounted) return;

    setState(() => _claimingId = request.id);
    try {
      await context.read<LivoraApi>().claimAutomatic(request.id);
      await HapticFeedback.heavyImpact();
      if (mounted) {
        showAppSnack(
          context,
          '¡Orden #${request.shortId} asignada a tu centro! Ya está disponible en el radar de recolectores.',
        );
        _loadRequests();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  Future<void> _openBidSheet(CollectionRequest request) async {
    final session = context.read<SessionController>();
    final centerId = session.user?.id;
    if (centerId == null) return;

    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BidSubmissionSheet(request: request, centerId: centerId),
    );

    if (posted == true) {
      _loadRequests();
    }
  }

  Future<void> _withdrawBid(CollectionRequest request, AcopioBid bid) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Retirar Propuesta',
      message:
          '¿Estás seguro de que deseas retirar tu oferta para la solicitud #${request.shortId}?',
      confirmLabel: 'Retirar Oferta',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<LivoraApi>().withdrawBid(request.id, bid.id);
      await HapticFeedback.lightImpact();
      if (mounted) {
        showAppSnack(context, 'Propuesta retirada exitosamente.');
        _loadRequests();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Widget _buildDirectTab() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF115E59)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.amberAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Asignación Directa',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_directRequests.length} orden(es) directas esperando ser tomadas por tu planta.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Error al sincronizar',
                message: _error,
              ),
            )
          else if (_directRequests.isEmpty)
            const EmptyState(
              icon: Icons.flash_off_outlined,
              title: 'No hay órdenes directas pendientes',
              message:
                  'Cuando un hogar publique una recolección directa, aparecerá aquí para ser tomada con tu tarifario.',
            )
          else
            for (final req in _directRequests) ...[
              _DirectOrderCard(
                request: req,
                priceMap: _centerPriceMap,
                claiming: _claimingId == req.id,
                onClaim: () => _claimDirectOrder(req),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildAuctionTab(String? currentCenterId) {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LivoraColors.deep,
                  LivoraColors.deep.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subastas Abiertas',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_auctionRequests.length} solicitud(es) de hogares esperando propuestas comerciales.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Error al cargar subastas',
                message: _error,
              ),
            )
          else if (_auctionRequests.isEmpty)
            const EmptyState(
              icon: Icons.gavel_outlined,
              title: 'No hay subastas activas',
              message:
                  'Actualmente no hay solicitudes de hogares publicadas bajo la modalidad de subasta.',
            )
          else
            for (final req in _auctionRequests) ...[
              _AuctionCard(
                request: req,
                currentCenterId: currentCenterId,
                onBid: () => _openBidSheet(req),
                onWithdraw: (bid) => _withdrawBid(req, bid),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final currentCenterId = session.user?.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mercado de Órdenes'),
          actions: [
            IconButton(
              tooltip: 'Refrescar',
              onPressed: _loading ? null : _loadRequests,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            indicatorColor: LivoraColors.forest,
            labelColor: LivoraColors.forest,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flash_on, size: 18),
                    const SizedBox(width: 6),
                    Text('Directas (${_directRequests.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gavel_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Subastas (${_auctionRequests.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDirectTab(),
                  _buildAuctionTab(currentCenterId),
                ],
              ),
      ),
    );
  }
}

class _DirectOrderCard extends StatelessWidget {
  const _DirectOrderCard({
    required this.request,
    required this.priceMap,
    required this.claiming,
    required this.onClaim,
  });

  final CollectionRequest request;
  final Map<String, double> priceMap;
  final bool claiming;
  final VoidCallback onClaim;

  double _calculateEstimatedPayout() {
    double sum = 0.0;
    final estimated = request.itemsEstimated;
    for (final entry in estimated.entries) {
      final code = entry.key.toUpperCase();
      final weight = entry.value;
      final rate = priceMap[code] ?? 1.0;
      sum += weight * rate;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final householdAlias = request.householdName ??
        (request.householdEmail != null
            ? request.householdEmail!.split('@').first
            : 'Hogar Livora');
    final estimatedPayout = _calculateEstimatedPayout();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF0F766E).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Orden #${request.shortId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flash_on, size: 12, color: Color(0xFF0F766E)),
                      SizedBox(width: 4),
                      Text(
                        'DIRECTA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  householdAlias,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (request.householdAddress != null &&
                    request.householdAddress!.isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Text(
                      request.householdAddress!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Materiales Declarados:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${fmtKg(request.totalEstimatedKg)} total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: request.itemsEstimated.entries.map((e) {
                      final rate = priceMap[e.key.toUpperCase()] ?? 1.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          '${e.key}: ${fmtKg(e.value)} @ S/ ${rate.toStringAsFixed(2)}/kg',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pago Fiduciario Estimado:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      'S/ ${estimatedPayout.toStringAsFixed(2)} PEN',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.forest,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: claiming ? null : onClaim,
                  icon: claiming
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(claiming ? 'Tomando...' : 'Tomar orden'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({
    required this.request,
    required this.currentCenterId,
    required this.onBid,
    required this.onWithdraw,
  });

  final CollectionRequest request;
  final String? currentCenterId;
  final VoidCallback onBid;
  final void Function(AcopioBid bid) onWithdraw;

  @override
  Widget build(BuildContext context) {
    // Verificar si el centro ya postuló
    final myBid = request.bids.cast<AcopioBid?>().firstWhere(
          (b) => b?.centerId == currentCenterId && b?.status == 'PENDING',
          orElse: () => null,
        );

    final hasBid = myBid != null;
    final householdAlias = request.householdName ??
        (request.householdEmail != null
            ? request.householdEmail!.split('@').first
            : 'Hogar Livora');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasBid
              ? LivoraColors.forest.withValues(alpha: 0.6)
              : Colors.grey.withValues(alpha: 0.2),
          width: hasBid ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Solicitud #${request.shortId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB7791F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel_rounded, size: 12, color: Color(0xFFB7791F)),
                      SizedBox(width: 4),
                      Text(
                        'SUBASTA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB7791F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  householdAlias,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (request.householdAddress != null && request.householdAddress!.isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Text(
                      request.householdAddress!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Materiales Estimados:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${fmtKg(request.totalEstimatedKg)} total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    materialsSummary(request.itemsEstimated),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LivoraColors.deep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (hasBid) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: LivoraColors.mint.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: LivoraColors.forest.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: LivoraColors.forest,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tu propuesta está postulada',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.forest,
                            ),
                          ),
                          Text(
                            'Total: S/ ${myBid.totalEstimatedPenn.toStringAsFixed(2)} PEN (${myBid.totalEstimatedEco.toStringAsFixed(2)} ECO)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: LivoraColors.coral,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => onWithdraw(myBid),
                      child: const Text('Retirar'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Text(
                    '${request.bids.length} oferta(s) postulada(s)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: LivoraColors.forest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onBid,
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('Postular Oferta'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BidSubmissionSheet extends StatefulWidget {
  const _BidSubmissionSheet({
    required this.request,
    required this.centerId,
  });

  final CollectionRequest request;
  final String centerId;

  @override
  State<_BidSubmissionSheet> createState() => _BidSubmissionSheetState();
}

class _BidSubmissionSheetState extends State<_BidSubmissionSheet> {
  final Map<String, TextEditingController> _rateControllers = {};
  bool _loadingRates = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initRates();
  }

  @override
  void dispose() {
    for (final c in _rateControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initRates() async {
    // 1. Inicializar con valor por defecto 1.00 por material en la solicitud
    for (final mat in widget.request.itemsEstimated.keys) {
      _rateControllers[mat] = TextEditingController(text: '1.00');
    }

    try {
      final prices =
          await context.read<LivoraApi>().fetchCenterPrices(widget.centerId);
      if (mounted) {
        for (final p in prices) {
          final code = p.materialType.toUpperCase().trim();
          if (_rateControllers.containsKey(code)) {
            _rateControllers[code]!.text = p.pricePerKg.toStringAsFixed(2);
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingRates = false);
    }
  }

  double get _totalEstimatedPEN {
    double sum = 0.0;
    widget.request.itemsEstimated.forEach((mat, weight) {
      final ctrl = _rateControllers[mat];
      final rate = double.tryParse(ctrl?.text.replaceAll(',', '.') ?? '') ?? 0.0;
      sum += weight * rate;
    });
    return sum;
  }

  double get _totalEstimatedECO => _totalEstimatedPEN; // 1 ECO = 1 PEN

  Future<void> _submitBid() async {
    final proposedRates = <String, double>{};
    for (final entry in _rateControllers.entries) {
      final rate = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0.0;
      if (rate < 0.05) {
        showAppSnack(
          context,
          'La tarifa para ${entry.key} debe ser de al menos S/ 0.05 PEN/kg',
          error: true,
        );
        return;
      }
      proposedRates[entry.key] = double.parse(rate.toStringAsFixed(2));
    }

    setState(() => _submitting = true);
    try {
      await context.read<LivoraApi>().submitBid(
            widget.request.id,
            proposedRates: proposedRates,
          );
      await HapticFeedback.lightImpact();
      if (mounted) {
        showAppSnack(
          context,
          '¡Oferta de subasta enviada con éxito al hogar!',
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnack(context, e.message, error: true);
        setState(() => _submitting = false);
      }
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel_rounded, color: LivoraColors.forest),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Postular a Subasta #${widget.request.shortId}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Ajusta tus tarifas unitarias para este lote. Se precargaron tus precios vigentes de compra.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_loadingRates)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else ...[
              for (final entry in widget.request.itemsEstimated.entries) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            materialLabel(entry.key),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: LivoraColors.deep,
                            ),
                          ),
                          Text(
                            'Cantidad: ${fmtKg(entry.value)}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _rateControllers[entry.key],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixText: 'S/ ',
                          labelText: 'Tarifa / kg',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Divider(),
              const SizedBox(height: 8),
              // Caja de cálculo dinámico en tiempo real
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LivoraColors.mint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LivoraColors.forest.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Estimado a Ofertar:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.deep,
                          ),
                        ),
                        Text(
                          'S/ ${_totalEstimatedPEN.toStringAsFixed(2)} PEN',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Equivalencia en Tokens:',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        Text(
                          '${_totalEstimatedECO.toStringAsFixed(2)} ECO',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Split garantizado: 40% Hogar · 50% Recolector · 10% Livora',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BusyButton(
                label: 'Enviar Propuesta a Subasta',
                icon: Icons.send_rounded,
                busy: _submitting,
                onPressed: _submitBid,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
