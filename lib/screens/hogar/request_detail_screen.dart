import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

/// Detalle de una solicitud de recolección (vista del HOGAR).
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  CollectionRequest? _request;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final request = await context
          .read<LivoraApi>()
          .collectionRequestDetail(widget.requestId);
      if (mounted) {
        setState(() {
          _request = request;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cancelar solicitud',
      message: '¿Seguro que deseas cancelar esta solicitud de recolección?',
      confirmLabel: 'Sí, cancelar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context
          .read<LivoraApi>()
          .updateCollectionStatus(widget.requestId, 'CANCELLED');
      if (mounted) {
        showAppSnack(context, 'Solicitud cancelada');
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de solicitud')),
      body: _error != null
          ? EmptyState(
              icon: Icons.cloud_off,
              title: 'No se pudo cargar la solicitud',
              message: _error,
            )
          : request == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          StatusChip(
                            label: requestStatusLabel(request.status),
                            color: requestStatusColor(request.status),
                          ),
                          const Spacer(),
                          Text(
                            fmtDate(request.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: LivoraColors.ink.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (request.photoUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            request.photoUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // Si el bucket no sirve la imagen no rompemos la
                            // pantalla: el resto del detalle sigue siendo útil.
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (request.status == 'PENDING' ||
                          request.status == 'ACCEPTED') ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LivoraColors.brandGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'PIN de verificación',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                request.verificationPin ?? '----',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Compártelo únicamente con tu recolector al entregar los materiales.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SectionTitle(text: 'Materiales estimados'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              for (final entry
                                  in request.itemsEstimated.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.recycling,
                                        size: 18,
                                        color: LivoraColors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          materialLabel(entry.key),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: LivoraColors.deep,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        fmtKg(entry.value),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: LivoraColors.forest,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Total estimado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: LivoraColors.deep,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    fmtKg(request.totalEstimatedKg),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: LivoraColors.deep,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionTitle(text: 'Información'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              InfoRow(
                                label: 'Recolector',
                                value: request.collectorEmail ??
                                    'Aún sin asignar',
                              ),
                              InfoRow(
                                label: 'Notas',
                                value: request.description?.isNotEmpty == true
                                    ? request.description!
                                    : '—',
                              ),
                              InfoRow(
                                label: 'Ubicación',
                                value:
                                    '${request.latitude}, ${request.longitude}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (request.status == 'PENDING' ||
                          request.status == 'ACCEPTED')
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8C3A3A),
                            side: const BorderSide(
                              color: Color(0xFF8C3A3A),
                            ),
                          ),
                          onPressed: _cancelling ? null : _cancel,
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(
                            _cancelling
                                ? 'Cancelando…'
                                : 'Cancelar solicitud',
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
