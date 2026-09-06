import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../core/stellar.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/niubiz_checkout_modal.dart';
import '../../widgets/web3_confirm_modal.dart';
import 'profile.dart';
import 'qr_scanner_view.dart';
import 'stores_catalog_screen.dart';
import 'transaction_receipt_screen.dart';
import 'wallet_transactions_screen.dart';

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
    final confirmed = await showWeb3ConfirmModal(
      context,
      tokenAmount: amount,
      destinationName: 'Billetera Externa',
      destinationAddress: toAddress,
      actionDescription: 'Transferencia Directa de EcoTokens',
      concept: 'Transferencia P2P',
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
                onPressed: () => Stellar.openTxInExplorer(txId),
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

  Future<void> _scanAndPay([String? preScannedCode]) async {
    final scannedCode = preScannedCode ??
        await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const QRScannerView()),
        );
    if (scannedCode == null || scannedCode.isEmpty || !mounted) return;

    setState(() => _sending = true);
    try {
      final details = await context.read<LivoraApi>().redemptionDetails(scannedCode);
      if (!mounted) return;

      final storeName = details['store']?['name']?.toString() ?? details['store']?['businessName']?.toString() ?? 'Comercio Aliado';
      final tokenAmount = double.tryParse(details['tokenAmount']?.toString() ?? details['amountEcoTokens']?.toString() ?? '0') ?? 0.0;
      final storeAddress = details['store']?['walletAddress']?.toString();
      final concept = details['concept']?.toString() ?? details['description']?.toString() ?? 'Canje en Comercio';

      final confirmed = await showWeb3ConfirmModal(
        context,
        tokenAmount: tokenAmount,
        destinationName: storeName,
        destinationAddress: storeAddress,
        actionDescription: 'Canje de EcoTokens en Comercio Aliado',
        concept: concept,
      );

      if (!confirmed || !mounted) return;

      final result = await context.read<LivoraApi>().confirmRedemption(scannedCode);
      if (!mounted) return;

      final txHash = result['transactionId']?.toString() ?? result['txHash']?.toString() ?? '—';
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionReceiptScreen(
            tokenAmount: tokenAmount,
            storeName: storeName,
            storeAddress: storeAddress,
            concept: concept,
            txHash: txHash,
          ),
        ),
      );
      _loadBalance();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showNiubizRechargeDialog() async {
    double amount = 20.0;
    final controller = TextEditingController(text: '20');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.credit_card, color: LivoraColors.blue),
              SizedBox(width: 8),
              Text('Recarga Niubiz'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Conversión fija: S/ 1.00 PEN = 1.00 EcoToken',
                style: TextStyle(fontSize: 12, color: LivoraColors.slate),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [10, 20, 50, 100].map((preset) {
                  final isSelected = amount == preset.toDouble();
                  return ChoiceChip(
                    label: Text('S/ $preset'),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) {
                        setDialogState(() {
                          amount = preset.toDouble();
                          controller.text = '$preset';
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: livoraInput('Monto a recargar (PEN)', hint: '20.00'),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    setDialogState(() => amount = parsed);
                  }
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recibirás:', style: TextStyle(fontSize: 12)),
                    Text(
                      '${amount.toStringAsFixed(2)} EcoTokens',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: LivoraColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Al confirmar, autorizas a Livora a emitir tokens en Stellar respaldados 1:1 en fondos Soles custodiados.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LivoraColors.blue),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pagar con Niubiz'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final session = await context.read<LivoraApi>().createPaymentSession(amount: amount);
      if (!mounted) return;

      final purchaseNumber = session['purchaseNumber']?.toString();
      if (purchaseNumber == null || purchaseNumber.isEmpty) {
        showAppSnack(context, 'No se pudo generar la orden de pago', error: true);
        return;
      }

      final success = await NiubizCheckoutModal.show(
        context,
        purchaseNumber: purchaseNumber,
        amount: amount,
      );

      if (success == true) {
        _loadBalance();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'Error al conectar con la pasarela de pagos', error: true);
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
                  Builder(
                    builder: (_) {
                      final balanceVal = double.tryParse(_balance ?? '0') ?? 0.0;
                      return Text(
                        '≈ S/ ${balanceVal.toStringAsFixed(2)} PEN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'ECO · Billetera de Incentivos (1 ECO = S/ 1.00)',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        await HapticFeedback.lightImpact();
                        await Clipboard.setData(ClipboardData(text: address));
                        if (context.mounted) {
                          showAppSnack(context, 'Dirección pública copiada');
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
                          final opened = await Stellar.openAccountInExplorer(address);
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
            if (user?.role == Roles.hogar || user?.role == Roles.recolector) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LivoraColors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showNiubizRechargeDialog,
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text(
                  'Recargar Saldo / Comprar EcoTokens',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (user?.role != Roles.tienda && user?.role != Roles.centroAcopio) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _scanAndPay,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Escanear y Pagar QR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LivoraColors.deep,
                  side: const BorderSide(color: LivoraColors.deep),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final scanned = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoresCatalogScreen(),
                    ),
                  );
                  if (scanned != null && mounted) {
                    _scanAndPay(scanned);
                  }
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text(
                  'Explorar Tiendas Aliadas y Canjes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WalletTransactionsScreen(),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text(
                'Ver Historial de Transacciones',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                          hint: 'G…',
                          icon: Icons.account_balance_wallet_outlined,
                        ).copyWith(
                          suffixIcon: IconButton(
                            tooltip: 'Escanear QR de billetera',
                            icon: const Icon(Icons.qr_code_scanner, color: LivoraColors.forest),
                            onPressed: () async {
                              final scanned = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QRScannerView(
                                    validator: (code) =>
                                        Stellar.isValidAddress(Stellar.normalize(code)),
                                  ),
                                ),
                              );
                              if (!context.mounted || scanned == null) return;
                              final clean = Stellar.normalize(scanned);
                              _addressController.text = clean;
                              if (!Stellar.isValidAddress(clean)) {
                                showAppSnack(
                                  context,
                                  'El código no es una dirección Stellar válida (G...)',
                                  error: true,
                                );
                              } else {
                                showAppSnack(context, 'Dirección cargada');
                              }
                            },
                          ),
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: kDecimalInputFormatters,
                        validator: (value) => validateAmount(value, min: 0.10, unit: 'ECO'),
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
