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
  HouseholdMetrics? _metrics;
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
        api.householdMetrics(),
        api.collectionRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _metrics = results[0] as HouseholdMetrics;
        _requests = results[1] as List<CollectionRequest>;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final metrics = _metrics;
    final requests = _requests;

    return Scaffold(
      appBar: livoraAppBar(context, 'Hola, ${Roles.label(user?.role ?? '')}'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.recycling),
        label: const Text('Solicitar recolección'),
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
            if (metrics != null) ...[
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
                    value: fmtNumber(metrics.totalRecycledKg),
                    color: LivoraColors.green,
                  ),
                  StatCard(
                    icon: Icons.toll,
                    label: 'EcoTokens ganados',
                    value: fmtNumber(metrics.ecoTokensEarned),
                    color: LivoraColors.blue,
                  ),
                  StatCard(
                    icon: Icons.list_alt,
                    label: 'Solicitudes totales',
                    value: '${metrics.totalRequests}',
                    color: LivoraColors.cyan,
                  ),
                  StatCard(
                    icon: Icons.check_circle_outline,
                    label: 'Completadas',
                    value: '${metrics.completedRequests}',
                    color: LivoraColors.forest,
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
