import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../core/stellar.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import 'profile.dart';
import 'qr_scanner_view.dart';

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
    final toAddress = Stellar.normalize(_addressController.text);
    final confirmed = await confirmDialog(
      context,
      title: 'Confirmar transferencia',
      message:
          '¿Enviar $amount EcoTokens a\n$toAddress?\n\nLa comisión de red la cubre Livora.',
      confirmLabel: 'Enviar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    try {
      final result = await context.read<LivoraApi>().sendTokens(
            toAddress: toAddress,
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
            'Tu transacción está siendo verificada.\n\nCódigo: $txId',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            if (Stellar.isValidTxHash(txId))
              TextButton.icon(
                onPressed: () =>
                    Stellar.openInExplorer(Stellar.transactionUrl(txId)),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Ver comprobante digital'),
              ),
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

  Future<void> _scanAndPay(BuildContext context) async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerView()),
    );
    if (scannedCode == null || scannedCode.isEmpty || !mounted) return;

    setState(() => _sending = true);
    try {
      final details = await context.read<LivoraApi>().redemptionDetails(scannedCode);
      if (!mounted) return;

      final storeName = details['store']?['name']?.toString() ?? 'Comercio';
      final tokenAmount = double.tryParse(details['tokenAmount']?.toString() ?? '0') ?? 0.0;

      final confirmed = await confirmDialog(
        context,
        title: 'Confirmar Canje',
        message: '¿Autorizas el pago de $tokenAmount EcoTokens a "$storeName"?',
        confirmLabel: 'Confirmar Pago',
      );

      if (!confirmed || !mounted) return;

      final result = await context.read<LivoraApi>().confirmRedemption(scannedCode);
      if (!mounted) return;

      final txHash = result['transactionId']?.toString() ?? result['txHash']?.toString() ?? '—';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: LivoraColors.green,
            size: 40,
          ),
          title: const Text('Canje Exitoso'),
          content: Text(
            'Has transferido $tokenAmount EcoTokens a "$storeName" correctamente.\n\nTx: $txHash',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            if (Stellar.isValidTxHash(txHash))
              TextButton.icon(
                onPressed: () =>
                    Stellar.openInExplorer(Stellar.transactionUrl(txHash)),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Ver comprobante digital'),
              ),
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
                  Text(
                    'ECO · Billetera de Incentivos',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final opened = await Stellar.openInExplorer(
                            Stellar.accountUrl(address),
                          );
                          if (!opened && context.mounted) {
                            showAppSnack(
                              context,
                              'No se pudo abrir el explorador de transacciones',
                              error: true,
                            );
                          }
                        },
                        icon: const Icon(Icons.receipt_long_outlined, size: 16),
                        label: const Text(
                          'Ver en el explorador digital',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (user?.role != Roles.almacen) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _scanAndPay(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Escanear y Pagar QR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
                          hint: 'G…',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z2-7]'),
                          ),
                          TextInputFormatter.withFunction(
                            (_, next) => next.copyWith(
                              text: next.text.toUpperCase(),
                            ),
                          ),
                        ],
                        validator: (value) => Stellar.isValidAddress(value)
                            ? null
                            : 'Dirección de billetera inválida (formato G… de 56 caracteres)',
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
