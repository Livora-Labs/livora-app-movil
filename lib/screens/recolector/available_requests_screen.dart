import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../common/profile.dart';

/// Solicitudes PENDING disponibles para el recolector, con filtro de cercanía.
class AvailableRequestsScreen extends StatefulWidget {
  const AvailableRequestsScreen({super.key});

  @override
  State<AvailableRequestsScreen> createState() =>
      _AvailableRequestsScreenState();
}

class _AvailableRequestsScreenState extends State<AvailableRequestsScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '5');

  List<CollectionRequest>? _requests;
  String? _error;
  bool _nearbyFilter = false;
  String? _acceptingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  double? _num(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.'));

  Future<void> _load() async {
    final lat = _nearbyFilter ? _num(_latController) : null;
    final lng = _nearbyFilter ? _num(_lngController) : null;
    final radius = _nearbyFilter ? _num(_radiusController) : null;
    try {
      final requests = await context.read<LivoraApi>().collectionRequests(
            lat: lat,
            lng: lng,
            radiusKm: radius,
          );
      if (mounted) {
        setState(() {
          _requests = requests;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _accept(CollectionRequest request) async {
    setState(() => _acceptingId = request.id);
    try {
      await context
          .read<LivoraApi>()
          .updateCollectionStatus(request.id, 'ACCEPTED');
      if (!mounted) return;
      showAppSnack(
        context,
        'Solicitud aceptada. Se agregará a tu lote abierto en "Mi lote".',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;

    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Solicitudes',
        actions: [
          IconButton(
            tooltip: 'Mi reputación',
            onPressed: () => _showReputation(context),
            icon: const Icon(Icons.star_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _nearbyFilter,
                    onChanged: (value) {
                      setState(() => _nearbyFilter = value);
                      if (!value) _load();
                    },
                    title: const Text(
                      'Buscar cerca de una ubicación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.deep,
                      ),
                    ),
                    activeTrackColor: LivoraColors.green,
                  ),
                  if (_nearbyFilter)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _latController,
                                  decoration: livoraInput('Latitud'),
                                  keyboardType: const TextInputType
                                      .numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,\-]'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _lngController,
                                  decoration: livoraInput('Longitud'),
                                  keyboardType: const TextInputType
                                      .numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,\-]'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _radiusController,
                                  decoration: livoraInput('Km'),
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: _load,
                              icon: const Icon(Icons.search),
                              label: const Text('Buscar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                title: 'No se pudieron cargar las solicitudes',
                message: _error,
              )
            else if (requests == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isEmpty)
              const EmptyState(
                icon: Icons.travel_explore,
                title: 'No hay solicitudes pendientes',
                message:
                    'Desliza hacia abajo para actualizar o amplía el radio de búsqueda.',
              )
            else
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AvailableCard(
                    request: request,
                    accepting: _acceptingId == request.id,
                    onAccept: () => _accept(request),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReputation(BuildContext context) async {
    final api = context.read<LivoraApi>();
    try {
      final reputation = await api.collectorReputation();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.star, color: Color(0xFFE0A400), size: 36),
          title: Text('Reputación: ${reputation.score}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoRow(
                label: 'Recolecciones',
                value: '${reputation.totalPickups}',
              ),
              InfoRow(
                label: 'Calificaciones',
                value: '${reputation.ratingCount}',
              ),
              InfoRow(
                label: 'Insignia',
                value: reputation.badge == 'VERIFIED_COLLECTOR'
                    ? 'Recolector verificado'
                    : reputation.badge,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    }
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({
    required this.request,
    required this.accepting,
    required this.onAccept,
  });

  final CollectionRequest request;
  final bool accepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final distance = request.distanceMeters;
    return Card(
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
                if (distance != null)
                  StatusChip(
                    label: '${(distance / 1000).toStringAsFixed(1)} km',
                    color: LivoraColors.blue,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (request.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  request.description!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: LivoraColors.ink,
                  ),
                ),
              ),
            Text(
              '${request.householdEmail ?? 'Hogar'} · '
              '${request.latitude.toStringAsFixed(4)}, '
              '${request.longitude.toStringAsFixed(4)} · '
              '${fmtDate(request.createdAt)}',
              style: TextStyle(
                fontSize: 11.5,
                color: LivoraColors.ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: accepting ? null : onAccept,
                icon: accepting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(accepting ? 'Aceptando…' : 'Aceptar recolección'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
