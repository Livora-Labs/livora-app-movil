import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/stellar.dart';

/// Comprobante digital formal de canje Web3 en comercios aliados.
class TransactionReceiptScreen extends StatelessWidget {
  const TransactionReceiptScreen({
    super.key,
    required this.tokenAmount,
    required this.storeName,
    this.storeAddress,
    required this.concept,
    required this.txHash,
    this.timestamp,
  });

  final double tokenAmount;
  final String storeName;
  final String? storeAddress;
  final String concept;
  final String txHash;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final validTx = Stellar.isValidTxHash(txHash);
    final effectiveDate = timestamp ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobante de Canje'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta Principal de Voucher
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Icono de Éxito
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: LivoraColors.green.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: LivoraColors.green,
                          size: 54,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '¡Canje Confirmado!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: LivoraColors.deep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu operación ha sido liquidada exitosamente',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: LivoraColors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Monto Destacado
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: LivoraColors.forest.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '-${tokenAmount.toStringAsFixed(2)} ECO',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: LivoraColors.forest,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '≈ S/ ${tokenAmount.toStringAsFixed(2)} PEN',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: LivoraColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Desglose de Operación
                      _ReceiptRow(
                        label: 'Comercio Aliado',
                        value: storeName,
                        isBold: true,
                      ),
                      const SizedBox(height: 10),
                      _ReceiptRow(
                        label: 'Concepto / Beneficio',
                        value: concept,
                      ),
                      if (storeAddress != null && storeAddress!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _ReceiptRow(
                          label: 'Dirección del Local',
                          value: storeAddress!,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _ReceiptRow(
                        label: 'Fecha y Hora',
                        value: fmtDate(effectiveDate),
                      ),
                      const SizedBox(height: 10),
                      const _ReceiptRow(
                        label: 'Método de Canje',
                        value: 'Escáner QR POS (Delegated Web3)',
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Hash de Stellar y Explorador
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Transacción Blockchain (${Stellar.networkLabel})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: LivoraColors.paper,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: LivoraColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                txHash,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: LivoraColors.deep,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar Hash',
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: txHash));
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('ID de transacción copiado al portapapeles'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      if (validTx) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LivoraColors.blue,
                            side: const BorderSide(color: LivoraColors.blue),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Stellar.openTxInExplorer(txHash),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text(
                            'Verificar en Stellar Expert Explorer',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cláusula Legal de Cumplimiento (Indecopi / ANPD)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LivoraColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 16, color: LivoraColors.slate),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transacción custodial inmutable firmada en Stellar Blockchain. '
                        'Los EcoTokens han sido transferidos al comercio asociado como medio de canje '
                        'no reembolsable por dinero en efectivo (T&C Livora / Ley 29571).',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: LivoraColors.ink.withValues(alpha: 0.6),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón Finalizar
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Volver a mi Billetera',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: LivoraColors.ink.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: LivoraColors.deep,
            ),
          ),
        ),
      ],
    );
  }
}
