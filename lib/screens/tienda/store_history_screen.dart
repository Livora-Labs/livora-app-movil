import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

class StoreHistoryScreen extends StatefulWidget {
  const StoreHistoryScreen({super.key});

  @override
  State<StoreHistoryScreen> createState() => _StoreHistoryScreenState();
}

class _StoreHistoryScreenState extends State<StoreHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<dynamic>? _redemptions;
  List<dynamic>? _settlements;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<LivoraApi>();
      final results = await Future.wait([
        api.storeRedemptions(),
        api.storeSettlements(),
      ]);

      if (mounted) {
        setState(() {
          _redemptions = results[0];
          _settlements = results[1];
        });
      }
    } on ApiException catch (err) {
      if (mounted) {
        setState(() => _error = err.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _requestSettlement() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final double? amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solicitar Liquidación FIAT'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Los EcoTokens acumulados en tu billetera de tienda serán transferidos y convertidos a tu cuenta bancaria registrada.',
                style: TextStyle(fontSize: 12.5, color: LivoraColors.ink),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                decoration: livoraInput(
                  'Tokens a liquidar',
                  icon: Icons.toll_outlined,
                  hint: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (value) {
                  final val = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  if (val == null || val <= 0) {
                    return 'Ingresa un monto válido';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final val = double.parse(
                  controller.text.replaceAll(',', '.'),
                );
                Navigator.pop(dialogContext, val);
              }
            },
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );

    if (amount == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await context.read<LivoraApi>().requestSettlement(amount);
      if (mounted) {
        showAppSnack(
          context,
          'Solicitud de liquidación por $amount ECO creada correctamente',
        );
        _loadData();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '—';
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial y Liquidaciones'),
        backgroundColor: LivoraColors.deep,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ventas (Cobros)'),
            Tab(text: 'Liquidaciones FIAT'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading && _redemptions == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildRedemptionsTab(),
                  _buildSettlementsTab(),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LivoraColors.forest,
        foregroundColor: Colors.white,
        onPressed: _requestSettlement,
        icon: const Icon(Icons.account_balance),
        label: const Text('Liquidar a FIAT'),
      ),
    );
  }

  Widget _buildRedemptionsTab() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    final list = _redemptions;
    if (list == null || list.isEmpty) {
      return const Center(child: Text('No hay cobros registrados en tu historial.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isConfirmed = item['status'] == 'CONFIRMED';
        final userEmail = item['user']?['email'] ?? 'Usuario';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: LivoraColors.paper,
              child: Icon(Icons.toll, color: LivoraColors.forest),
            ),
            title: Text(
              '$userEmail',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: Text(
              'Fecha: ${_formatDate(item['createdAt'])}',
              style: const TextStyle(fontSize: 11.5),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${item['tokenAmount']} ECO',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: LivoraColors.forest,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                StatusChip(
                  label: isConfirmed ? 'Cobrado' : 'Pendiente',
                  color: isConfirmed ? LivoraColors.green : Colors.amber,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettlementsTab() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    final list = _settlements;
    if (list == null || list.isEmpty) {
      return const Center(child: Text('No hay solicitudes de liquidación registradas.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final status = item['status']?.toString().toUpperCase() ?? 'PENDING';
        final isApproved = status == 'APPROVED' || status == 'COMPLETED';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: LivoraColors.paper,
              child: Icon(Icons.account_balance, color: LivoraColors.deep),
            ),
            title: Text(
              'Liquidación FIAT',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: Text(
              'Fecha: ${_formatDate(item['createdAt'])}',
              style: const TextStyle(fontSize: 11.5),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${item['tokenAmount']} ECO',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                StatusChip(
                  label: isApproved ? 'Aprobado' : 'Procesando',
                  color: isApproved ? LivoraColors.green : Colors.amber,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
