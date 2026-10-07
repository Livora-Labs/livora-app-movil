import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/api_client.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/session.dart';
import '../../../../core/stellar.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/izipay_checkout_modal.dart';
import '../../../../widgets/web3_confirm_modal.dart';
import '../../../../screens/common/profile.dart';
import '../../../../screens/common/qr_scanner_view.dart';
import '../../../../screens/common/transaction_receipt_screen.dart';
import '../view_model/wallet_view_model.dart';
import '../widgets/wallet_balance_header.dart';
import '../widgets/wallet_quick_actions.dart';
import '../widgets/wallet_transfer_card.dart';

/// Vista desacoplada MVVM para la Billetera LIVO y activos Web3. (<200 líneas).
class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  Future<void> _handleTransfer(WalletViewModel vm, String toAddress, double amount) async {
    try {
      final result = await vm.sendTokens(toAddress: toAddress, amount: amount);
      if (!mounted) return;
      final txId = result['transactionId']?.toString() ?? '—';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: LivoraColors.green, size: 40),
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
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _scanAndPay(WalletViewModel vm, [String? preScannedCode]) async {
    final scannedCode = preScannedCode ??
        await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const QRScannerView()),
        );
    if (scannedCode == null || scannedCode.isEmpty || !mounted) return;

    try {
      final details = await vm.getRedemptionDetails(scannedCode);
      if (!mounted) return;

      final storeName = details['store']?['name']?.toString() ??
          details['store']?['businessName']?.toString() ?? 'Comercio Aliado';
      final tokenAmount = double.tryParse(details['tokenAmount']?.toString() ??
              details['amountEcoTokens']?.toString() ?? '0') ?? 0.0;
      final storeAddress = details['store']?['walletAddress']?.toString();
      final concept = details['concept']?.toString() ?? details['description']?.toString() ?? 'Canje en Comercio';

      final confirmed = await showWeb3ConfirmModal(
        context,
        tokenAmount: tokenAmount,
        destinationName: storeName,
        destinationAddress: storeAddress,
        actionDescription: 'Canje de LIVOs en Comercio Aliado',
        concept: concept,
      );

      if (!confirmed || !mounted) return;

      final result = await vm.confirmRedemption(scannedCode);
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
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _showIzipayRechargeDialog(WalletViewModel vm) async {
    double amount = 20.0;
    final controller = TextEditingController(text: '20');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.credit_card, color: LivoraColors.forest),
              SizedBox(width: 8),
              Text('Recarga Izipay'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Conversión fija: S/ 1.00 PEN = 1.00 LIVO\nMonto mínimo: S/ 10.00 PEN',
                style: TextStyle(fontSize: 12, color: LivoraColors.slate),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [10, 20, 50, 100].map((preset) {
                  final isSelected = amount == preset.toDouble();
                  return ChoiceChip(
                    label: Text('S/ $preset'),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) {
                        HapticFeedback.selectionClick();
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recibirás:', style: TextStyle(fontSize: 12)),
                    Text(
                      '${amount.toStringAsFixed(2)} LIVOs',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: LivoraColors.forest),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Al confirmar, se abrirá la pasarela segura Izipay. Tras la confirmación del pago, tus LIVOs se acreditarán de inmediato en tu saldo disponible.',
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
              style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
              onPressed: () {
                if (amount < 10.0) {
                  showAppSnack(context, 'El monto mínimo de recarga es S/ 10.00 PEN', error: true);
                  return;
                }
                if (amount > 500.0) {
                  showAppSnack(context, 'El monto máximo por recarga es S/ 500.00 PEN', error: true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Pagar con Izipay'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final session = await vm.createPaymentSession(amount);
      if (!mounted) return;
      final orderId = session['orderId']?.toString() ?? session['purchaseNumber']?.toString();
      if (orderId == null || orderId.isEmpty) {
        showAppSnack(context, 'No se pudo generar la orden de pago en Izipay', error: true);
        return;
      }
      final success = await IzipayCheckoutModal.show(context, orderId: orderId, amount: amount);
      if (success == true) {
        vm.loadBalance(forceRefresh: true);
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Error al conectar con la pasarela Izipay', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final vm = context.watch<WalletViewModel>();

    return Scaffold(
      appBar: livoraAppBar(context, 'Billetera'),
      body: RefreshIndicator(
        onRefresh: () => vm.loadBalance(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
          children: [
            WalletBalanceHeader(
              balance: vm.balanceState.dataOrNull,
              isLoading: vm.balanceState.isLoading,
              userRole: user?.role,
              walletAddress: user?.walletAddress,
              onRefresh: () => vm.loadBalance(forceRefresh: true),
            ),
            WalletQuickActions(
              userRole: user?.role,
              onIzipayRecharge: () => _showIzipayRechargeDialog(vm),
              onScanAndPay: () => _scanAndPay(vm),
              onCatalogStoreSelected: (code) => _scanAndPay(vm, code),
            ),
            const SizedBox(height: 20),
            WalletTransferCard(
              isSending: vm.isSending,
              userRole: user?.role,
              onSend: (to, amt) => _handleTransfer(vm, to, amt),
            ),
            const SizedBox(height: 12),
            Text(
              'Sin costo de red para ti. '
              'Los LIVOs se ganan reciclando y pueden canjearse en tiendas aliadas.',
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
