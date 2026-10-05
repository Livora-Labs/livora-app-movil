import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_theme.dart';
import '../../../widgets/common.dart';

/// Diálogo modal a pantalla casi completa para confirmar con éxito un cobro POS.
/// Incluye aviso sonoro/háptico, código de autorización y opción de compartir comprobante vía WhatsApp.
class StorePosSuccessDialog extends StatefulWidget {
  const StorePosSuccessDialog({
    super.key,
    required this.amount,
    required this.authCode,
    this.customerName,
    required this.timestamp,
    this.txHash,
  });

  final double amount;
  final String authCode;
  final String? customerName;
  final DateTime timestamp;
  final String? txHash;

  static Future<bool?> show(
    BuildContext context, {
    required double amount,
    required String authCode,
    String? customerName,
    DateTime? timestamp,
    String? txHash,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StorePosSuccessDialog(
        amount: amount,
        authCode: authCode,
        customerName: customerName,
        timestamp: timestamp ?? DateTime.now(),
        txHash: txHash,
      ),
    );
  }

  @override
  State<StorePosSuccessDialog> createState() => _StorePosSuccessDialogState();
}

class _StorePosSuccessDialogState extends State<StorePosSuccessDialog> {
  @override
  void initState() {
    super.initState();
    // Feedback sonoro y háptico de caja registradora al desplegarse
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _shareViaWhatsapp() async {
    final dateStr = _formatDate(widget.timestamp);
    final cleanRef = widget.authCode.replaceAll(RegExp(r'^LIVORA-QR-|^LIV-'), '');
    final msg = StringBuffer()
      ..writeln('*COMPROBANTE DE PAGO EN TIENDA ALIADA - LIVORA*')
      ..writeln('--------------------------------')
      ..writeln('Monto Abonado: S/ ${widget.amount.toStringAsFixed(2)} (${widget.amount.toStringAsFixed(2)} LIVOs)')
      ..writeln('Código de Aprobación: $cleanRef')
      ..writeln('Fecha y Hora: $dateStr')
      ..writeln('Estado: Pago Confirmado en Red Stellar')
      ..writeln('--------------------------------')
      ..writeln('Gracias por impulsar la economía circular y el reciclaje.');

    final encoded = Uri.encodeComponent(msg.toString());
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        showAppSnack(context, 'No se pudo abrir WhatsApp en el dispositivo', error: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al abrir WhatsApp', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanRef = widget.authCode.replaceAll(RegExp(r'^LIVORA-QR-|^LIV-'), '');
    final shortRef = cleanRef.length > 12 ? cleanRef.substring(0, 12) : cleanRef;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono animado de éxito
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: LivoraColors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: LivoraColors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Cobro Confirmado',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Los tokens han sido acreditados a tu billetera comercial.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: LivoraColors.slate,
                ),
              ),
              const SizedBox(height: 16),

              // Monto destacado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LivoraColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'S/ ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: LivoraColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.amount.toStringAsFixed(2)} LIVO',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ficha de detalle de la transacción
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LivoraColors.border),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Código de Aprobación',
                      value: shortRef,
                      isBold: true,
                    ),
                    const Divider(height: 14),
                    _DetailRow(
                      label: 'Fecha y Hora',
                      value: _formatDate(widget.timestamp),
                    ),
                    if (widget.customerName != null && widget.customerName!.isNotEmpty) ...[
                      const Divider(height: 14),
                      _DetailRow(
                        label: 'Cliente',
                        value: widget.customerName!,
                      ),
                    ],
                    const Divider(height: 14),
                    const _DetailRow(
                      label: 'Liquidación',
                      value: 'Abonado en Balance Comercial',
                      valueColor: LivoraColors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botones de acción
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: LivoraColors.forest),
                    foregroundColor: LivoraColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _shareViaWhatsapp,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Compartir Ticket (WhatsApp)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: LivoraColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Nuevo Cobro',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: LivoraColors.slate,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? LivoraColors.deep,
            ),
          ),
        ),
      ],
    );
  }
}
