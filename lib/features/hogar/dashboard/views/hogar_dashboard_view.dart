import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../core/session.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/livora_realtime.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/livora_shimmer.dart';
import '../../../../screens/common/profile.dart';
import '../../../../screens/common/stores_catalog_screen.dart';
import '../../../../screens/hogar/collection_history_screen.dart';
import '../../../../screens/hogar/create_request_screen.dart';
import '../../../../screens/hogar/request_detail_screen.dart';
import '../../../../screens/hogar/widgets/hero_active_request_card.dart';
import '../../../../screens/hogar/widgets/hogar_active_address_bar.dart';
import '../../../../screens/hogar/widgets/hogar_esg_stats_grid.dart';
import '../../../../screens/hogar/widgets/hogar_first_steps_dialog.dart';
import '../view_model/hogar_dashboard_view_model.dart';

/// Vista principal declarativa del Dashboard del Hogar (Clean Architecture MVVM).
/// Libre de lógica de negocio, optimizada para 60/120 FPS y reactiva a WebSockets.
class HogarDashboardView extends StatelessWidget {
  const HogarDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HogarDashboardViewModel>(
      create: (ctx) => HogarDashboardViewModel(
        api: ctx.read<LivoraApi>(),
        realtime: ctx.read<LivoraRealtime>(),
        session: ctx.read<SessionController>(),
      ),
      child: const _HogarDashboardContent(),
    );
  }
}

class _HogarDashboardContent extends StatefulWidget {
  const _HogarDashboardContent();

  @override
  State<_HogarDashboardContent> createState() => _HogarDashboardContentState();
}

class _HogarDashboardContentState extends State<_HogarDashboardContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HogarFirstStepsDialog.checkAndShow(context);

      final vm = context.read<HogarDashboardViewModel>();
      vm.liveNotificationNotifier.addListener(_onLiveNotification);
    });
  }

  void _onLiveNotification() {
    if (!mounted) return;
    final msg = context.read<HogarDashboardViewModel>().liveNotificationNotifier.value;
    if (msg != null && msg.isNotEmpty) {
      HapticFeedback.heavyImpact();
      showAppSnack(context, msg);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final session = context.read<SessionController>();
    final active = session.activeRequest;

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

    final user = session.user;
    final hasAddress = user?.address != null &&
        user!.address!.trim().isNotEmpty &&
        !user.address!.startsWith('Ubicación GPS');

    if (!hasAddress) {
      showAppSnack(
        context,
        'Por favor, fija tu dirección de recojo antes de solicitar.',
      );
      await _openAddressSelectorModal(user);
      if (!mounted) return;
      final updatedUser = context.read<SessionController>().user;
      final nowHasAddress = updatedUser?.address != null &&
          updatedUser!.address!.trim().isNotEmpty &&
          !updatedUser.address!.startsWith('Ubicación GPS');
      if (!nowHasAddress) return;
    }

    if (!mounted) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
    );
    if (created == true && mounted) {
      context.read<HogarDashboardViewModel>().refresh();
    }
  }

  Future<void> _openAddressSelectorModal(AuthUser? user) async {
    final api = context.read<LivoraApi>();
    final session = context.read<SessionController>();

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

  String _formatGreeting(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) return '¡Bienvenido!';
    final firstName = rawName.trim().split(RegExp(r'\s+')).first;
    if (firstName.isEmpty) return '¡Bienvenido!';
    return 'Hola, ${firstName[0].toUpperCase()}${firstName.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    // Micro-optimización reactiva: Seleccionamos solo los campos necesarios de la sesión
    final userName = context.select<SessionController, String?>((s) => s.user?.name);
    final userAddress = context.select<SessionController, String?>((s) => s.user?.address);
    final fullUser = context.select<SessionController, AuthUser?>((s) => s.user);

    final vm = context.watch<HogarDashboardViewModel>();
    final state = vm.state;
    final data = state.dataOrNull;
    final active = data?.activeRequest;
    final requests = data?.requests;

    return Scaffold(
      appBar: livoraAppBar(context, _formatGreeting(userName)),
      body: RefreshIndicator(
        onRefresh: () => vm.refresh(),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          children: [
            // Barra de Ubicación de Recojo Activa estilo Rappi
            HogarActiveAddressBar(
              address: userAddress,
              onTap: () => _openAddressSelectorModal(fullUser),
            ),

            if (state.isError && data == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: Color(0xFF8C3A3A)),
                  title: Text(
                    state.errorMessageOrNull ?? 'Error al sincronizar datos',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: TextButton(
                    onPressed: () => vm.load(),
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
                  if (mounted) vm.refresh();
                },
              ),

            // Métricas ESG y Saldo LIVO
            if (state.isLoading && data == null) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.50,
                children: const [
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                  Card(child: Padding(padding: EdgeInsets.all(12), child: LivoraShimmer(child: ShimmerBox(height: 70, borderRadius: 12)))),
                ],
              ),
              const SizedBox(height: 8),
            ] else if (data != null) ...[
              HogarEsgStatsGrid(
                dashboardData: data.metrics,
                requests: requests ?? [],
              ),
              const SizedBox(height: 8),

              // Banner educativo y motivacional para nuevos hogares
              if (data.isNewHogar)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openCreate(),
                    child: Container(
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
                          const Icon(Icons.chevron_right_rounded, color: LivoraColors.forest),
                        ],
                      ),
                    ),
                  ),
                ),

              if (data.totalCollections > 0)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
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

            SectionTitle(
              text: 'Mis solicitudes',
              trailing: (requests != null && requests.isNotEmpty)
                  ? TextButton.icon(
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
                        if (mounted) vm.refresh();
                      },
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Ver todas'),
                    )
                  : null,
            ),
            const SizedBox(height: 6),

            if (state.isLoading && data == null)
              const LivoraShimmerList(itemCount: 3)
            else if (requests != null && requests.isEmpty)
              const EmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'Aún no tienes solicitudes',
                message:
                    'Crea tu primera solicitud de recolección y empieza a acumular LIVOs.',
              )
            else if (requests != null) ...[
              for (final request in requests.take(3))
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
                      if (mounted) vm.refresh();
                    },
                  ),
                ),
              if (requests.length > 3) ...[
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
                    if (mounted) vm.refresh();
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
