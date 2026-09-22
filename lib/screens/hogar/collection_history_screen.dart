import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/paging_controller.dart';
import '../../core/stellar.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_empty_state.dart';
import '../../widgets/paginated_list_view.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';

/// Historial completo de recolecciones del Hogar con filtros por estado y carga infinita.
class CollectionHistoryScreen extends StatefulWidget {
  const CollectionHistoryScreen({
    super.key,
    this.initialFilter = 'TODAS',
  });

  final String initialFilter;

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  late String _selectedFilter;
  late final PagingController<CollectionRequest> _pagingController;

  static const _filters = [
    'TODAS',
    'PENDING',
    'ACCEPTED',
    'COMPLETED',
    'CANCELLED',
  ];

  static String _filterLabel(String f) => switch (f) {
        'TODAS' => 'Todas',
        'PENDING' => 'Pendientes',
        'ACCEPTED' => 'En camino',
        'COMPLETED' => 'Completadas',
        'CANCELLED' => 'Canceladas',
        _ => f,
      };

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _pagingController = PagingController<CollectionRequest>(
      fetcher: (page, limit) => context.read<LivoraApi>().collectionRequests(
        status: _selectedFilter == 'TODAS' ? null : _selectedFilter,
        page: page,
        limit: limit,
      ),
      keySelector: (r) => r.id,
      pageSize: 15,
    );
    _pagingController.loadFirstPage();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  void _onFilterSelected(String filter) {
    if (_selectedFilter != filter) {
      setState(() => _selectedFilter = filter);
      _pagingController.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Recolecciones'),
      ),
      body: Column(
        children: [
          // Barra de Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(f)),
                    selected: isSelected,
                    selectedColor: LivoraColors.forest.withValues(alpha: 0.18),
                    checkmarkColor: LivoraColors.forest,
                    labelStyle: TextStyle(
                      color: isSelected ? LivoraColors.forest : LivoraColors.ink,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (sel) {
                      if (sel) _onFilterSelected(f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Lista de Solicitudes con Paginación e Infinite Scroll a 60 FPS
          Expanded(
            child: PaginatedListView<CollectionRequest>(
              controller: _pagingController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              emptyState: LivoraEmptyState(
                icon: Icons.history_rounded,
                title: 'Sin solicitudes',
                message: _selectedFilter == 'TODAS'
                    ? 'Aún no has creado solicitudes de reciclaje.'
                    : 'No hay solicitudes en estado ${_filterLabel(_selectedFilter).toLowerCase()}.',
                actionLabel: 'Nueva recolección',
                onAction: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateRequestScreen(),
                    ),
                  );
                  _pagingController.refresh();
                },
              ),
              itemBuilder: (context, req, index) {
                return _HistoryItemCard(
                  request: req,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestDetailScreen(
                          requestId: req.id,
                        ),
                      ),
                    );
                    _pagingController.refresh();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({
    required this.request,
    required this.onTap,
  });

  final CollectionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weights = request.actualWeights ?? request.itemsEstimated;
    final totalKg = weights.values.fold<double>(0.0, (s, w) => s + w);
    final hasTxHash = request.txHash != null && Stellar.isValidTxHash(request.txHash);
    final hasDonation = request.isDonation;
    final reward = request.householdRewardEarned;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila 1: Materiales + Estado ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      materialsSummary(request.itemsEstimated),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: requestStatusLabel(request.status),
                    color: requestStatusColor(request.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Fila 2: Peso + Badge Recompensa / Donación ───────────────
              Row(
                children: [
                  const Icon(Icons.scale_outlined, size: 16, color: LivoraColors.forest),
                  const SizedBox(width: 6),
                  Text(
                    request.actualWeights != null
                        ? 'Pesaje real: ${fmtKg(totalKg)}'
                        : 'Estimado: ${fmtKg(totalKg)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: LivoraColors.forest,
                    ),
                  ),
                  const Spacer(),
                  if (hasDonation)
                    _TinyBadge(
                      label: 'Donación Solidaria',
                      icon: Icons.volunteer_activism_rounded,
                      color: const Color(0xFF6B7280),
                    )
                  else if (reward > 0)
                    _TinyBadge(
                      label: '+${reward.toStringAsFixed(2)} LIVO',
                      icon: Icons.toll_rounded,
                      color: LivoraColors.forest,
                    ),
                ],
              ),

              // ── Fila 3: Hash Stellar (solo si COMPLETED con tx) ──────────
              if (hasTxHash) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 14, color: Color(0xFF5B67E8)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Tx: ${Stellar.shortHash(request.txHash!)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF5B67E8),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Botón copiar hash
                    _TxIconButton(
                      tooltip: 'Copiar hash',
                      icon: Icons.copy_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(
                          ClipboardData(text: Stellar.cleanTxHash(request.txHash!)),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hash copiado al portapapeles'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    // Botón abrir en explorador
                    _TxIconButton(
                      tooltip: 'Ver en Stellar Expert',
                      icon: Icons.open_in_new_rounded,
                      onTap: () => Stellar.openTxInExplorer(request.txHash),
                    ),
                  ],
                ),
              ],

              // ── Fila 4: Fecha + Recolector ────────────────────────────────
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: LivoraColors.ink.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    fmtDate(request.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: LivoraColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  if (request.collectorName != null || request.collectorEmail != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '·  ${sanitizedPersonName(request.collectorName, request.collectorEmail)}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: LivoraColors.ink.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge pequeño con icono y texto para recompensa o tipo de recolección.
class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón icónico para acciones de tx hash (copiar / explorador).
class _TxIconButton extends StatelessWidget {
  const _TxIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5B67E8);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    );
  }
}

