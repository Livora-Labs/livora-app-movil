import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../common/profile.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';

class HogarDashboard extends StatefulWidget {
  const HogarDashboard({super.key});

  @override
  State<HogarDashboard> createState() => _HogarDashboardState();
}

class _HogarDashboardState extends State<HogarDashboard> {
  Map<String, dynamic>? _dashboardData;
  bool _loadingDashboard = true;
  List<CollectionRequest>? _requests;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<LivoraApi>();
    try {
      final results = await Future.wait([
        api.getDashboard(),
        api.collectionRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboardData = results[0];
        _requests = results[1];
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

  /// El backend solo permite una solicitud activa por hogar (PENDING o
  /// ACCEPTED). La detectamos aquí para no dejar que el usuario llene el
  /// formulario y se coma el error al final.
  CollectionRequest? get _activeRequest {
    for (final request in _requests ?? const <CollectionRequest>[]) {
      if (request.status == 'PENDING' || request.status == 'ACCEPTED') {
        return request;
      }
    }
    return null;
  }

  Future<void> _openCreate() async {
    final active = _activeRequest;
    if (active != null) {
      showAppSnack(
        context,
        'Ya tienes una solicitud ${requestStatusLabel(active.status).toLowerCase()}. '
        'Complétala o cancélala para crear otra.',
        error: true,
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
    final user = context.watch<SessionController>().user;
    final requests = _requests;

    return Scaffold(
      appBar: livoraAppBar(context, 'Hola, ${Roles.label(user?.role ?? '')}'),
      // Se ve apagado cuando hay una solicitud activa, pero sigue respondiendo
      // al toque para explicar por qué no se puede crear otra.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _activeRequest != null
            ? LivoraColors.ink.withValues(alpha: 0.25)
            : null,
        foregroundColor: _activeRequest != null ? Colors.white : null,
        icon: Icon(
          _activeRequest != null ? Icons.hourglass_bottom : Icons.recycling,
        ),
        label: Text(
          _activeRequest != null
              ? 'Solicitud en curso'
              : 'Solicitar recolección',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
            // Tarjeta de PIN de Verificación
            if (_loadingDashboard)
              const Card(
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    height: 100,
                    child: Center(child: _Skeleton()),
                  ),
                ),
              )
            else
              _PinVerificationCard(activeRequest: _dashboardData?['activeRequest']),

            if (_loadingDashboard) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: const [
                  Card(child: Padding(padding: const EdgeInsets.all(12), child: _Skeleton())),
                  Card(child: Padding(padding: const EdgeInsets.all(12), child: _Skeleton())),
                  Card(child: Padding(padding: const EdgeInsets.all(12), child: _Skeleton())),
                  Card(child: Padding(padding: const EdgeInsets.all(12), child: _Skeleton())),
                ],
              ),
              const SizedBox(height: 16),
            ] else if (_dashboardData != null) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: [
                  StatCard(
                    icon: Icons.recycling,
                    label: 'Kg reciclados',
                    value: fmtNumber(_dashboardData!['esgMetrics']?['totalKgRecycled'] ?? 0.0),
                    color: LivoraColors.green,
                  ),
                  StatCard(
                    icon: Icons.toll,
                    label: 'Saldo EcoTokens',
                    value: '${_dashboardData!['wallet']?['balance'] ?? "0.00"} ECO',
                    color: LivoraColors.blue,
                  ),
                  StatCard(
                    icon: Icons.eco_outlined,
                    label: 'CO₂ Ahorrado',
                    value: '${fmtNumber(_dashboardData!['esgMetrics']?['co2SavedKg'] ?? 0.0)} kg',
                    color: LivoraColors.amber,
                  ),
                  StatCard(
                    icon: Icons.list_alt,
                    label: 'Recolecciones',
                    value: '${_dashboardData!['esgMetrics']?['totalCollections'] ?? 0}',
                    color: LivoraColors.cyan,
                  ),
                ],
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
                    (request.collectorEmail != null
                        ? ' · Recolector: ${request.collectorEmail}'
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

class _PinVerificationCard extends StatelessWidget {
  const _PinVerificationCard({required this.activeRequest});

  final Map<String, dynamic>? activeRequest;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeRequest != null;
    final pin = hasActive ? activeRequest!['pin'] as String? ?? '---' : '---';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: hasActive ? LivoraColors.blue.withValues(alpha: 0.1) : LivoraColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasActive ? LivoraColors.blue : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.key_rounded,
                  color: hasActive ? LivoraColors.blue : LivoraColors.ink.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PIN DE VERIFICACIÓN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: LivoraColors.deep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pin,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: hasActive ? LivoraColors.blue : LivoraColors.ink.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasActive
                  ? 'Dicta este PIN al recolector al entregar tus materiales.'
                  : 'Sin recolección activa. Se generará automáticamente al solicitar un recojo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: LivoraColors.ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton({this.width, this.height, this.borderRadius});

  final double? width;
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
            width: widget.width ?? double.infinity,
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
