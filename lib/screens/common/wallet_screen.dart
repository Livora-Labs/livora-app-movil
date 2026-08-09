import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import 'profile.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _balance;
  bool _loadingBalance = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() => _loadingBalance = true);
    try {
      final balance = await context.read<LivoraApi>().walletBalance();
      if (mounted) setState(() => _balance = balance);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final confirmed = await confirmDialog(
      context,
      title: 'Confirmar transferencia',
      message:
          '¿Enviar $amount EcoTokens a\n${_addressController.text.trim()}?\n\nLa comisión de red la cubre Livora.',
      confirmLabel: 'Enviar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    try {
      final result = await context.read<LivoraApi>().sendTokens(
            toAddress: _addressController.text.trim(),
            amount: amount,
          );
      if (!mounted) return;
      _addressController.clear();
      _amountController.clear();
      final txId = result['transactionId']?.toString() ?? '—';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: LivoraColors.green,
            size: 40,
          ),
          title: const Text('Transferencia enviada'),
          content: Text(
            'La red Arbitrum está procesando tu transacción.\n\nID: $txId',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      _loadBalance();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final address = user?.walletAddress;

    return Scaffold(
      appBar: livoraAppBar(context, 'Billetera'),
      body: RefreshIndicator(
        onRefresh: _loadBalance,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LivoraColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Saldo EcoTokens',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _loadingBalance ? null : _loadBalance,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _loadingBalance
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : Text(
                          _balance ?? '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                  const SizedBox(height: 2),
                  const Text(
                    'ECO · Arbitrum Sepolia',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: address));
                        if (context.mounted) {
                          showAppSnack(context, 'Dirección copiada');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                address,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle(text: 'Transferir EcoTokens'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _addressController,
                        decoration: livoraInput(
                          'Dirección destino',
                          hint: '0x…',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          final valid = RegExp(r'^0x[0-9a-fA-F]{40}$')
                              .hasMatch(text);
                          return valid
                              ? null
                              : 'Dirección inválida (formato 0x… de 42 caracteres)';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _amountController,
                        decoration: livoraInput(
                          'Cantidad',
                          icon: Icons.toll_outlined,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        validator: (value) {
                          final amount = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          return amount == null || amount <= 0
                              ? 'Ingresa una cantidad mayor a 0'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      BusyButton(
                        label: 'Enviar',
                        icon: Icons.send_rounded,
                        busy: _sending,
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Las transferencias usan el Relayer de Livora: no pagas gas. '
              'Los EcoTokens se ganan reciclando y pueden canjearse en tiendas aliadas.',
              style: TextStyle(
                fontSize: 12,
                color: LivoraColors.ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
