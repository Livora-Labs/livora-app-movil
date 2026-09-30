import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../services/livora_api.dart';
import '../../../widgets/common.dart';

/// Modal de autorización de anulación de canje en punto de venta (Rol TIENDA).
/// Exige motivo y clave PIN de 6 dígitos antes de revertir los fondos al cliente.
class StoreRefundPinModal extends StatefulWidget {
  const StoreRefundPinModal({
    super.key,
    required this.redemptionId,
    required this.tokenAmount,
  });

  final String redemptionId;
  final double tokenAmount;

  static Future<bool?> show(
    BuildContext context, {
    required String redemptionId,
    required double tokenAmount,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StoreRefundPinModal(
        redemptionId: redemptionId,
        tokenAmount: tokenAmount,
      ),
    );
  }

  @override
  State<StoreRefundPinModal> createState() => _StoreRefundPinModalState();
}

class _StoreRefundPinModalState extends State<StoreRefundPinModal> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  String _selectedReason = 'Devolución o cambio de mercadería';
  bool _busy = false;

  static const List<String> _reasons = [
    'Devolución o cambio de mercadería',
    'Error en monto digitado en POS',
    'Cobro duplicado por error de conexión',
    'Cancelación solicitada por el cliente',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _submitRefund() async {
    final pin = _pinController.text.trim();
    if (pin.length < 6) {
      HapticFeedback.vibrate();
      showAppSnack(context, 'Ingresa el PIN de seguridad de 6 dígitos', error: true);
      return;
    }

    setState(() => _busy = true);
    HapticFeedback.lightImpact();

    try {
      final api = context.read<LivoraApi>();
      await api.refundRedemption(widget.redemptionId);

      if (mounted) {
        showAppSnack(context, 'Canje anulado con éxito. Tokens restituidos al cliente.');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al procesar la anulación del cobro', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tirador táctil
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título y advertencia
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.undo_rounded,
                  color: Color(0xFFEF4444),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anular Cobro POS',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    Text(
                      'Restitución de fondos al cliente (Límite: 24h)',
                      style: TextStyle(fontSize: 12, color: LivoraColors.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monto a devolver
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: LivoraColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LivoraColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monto a reembolsar:',
                  style: TextStyle(fontSize: 13, color: LivoraColors.slate, fontWeight: FontWeight.w600),
                ),
                Text(
                  'S/ ${widget.tokenAmount.toStringAsFixed(2)} (${widget.tokenAmount.toStringAsFixed(2)} LIVO)',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Motivo de anulación
          const Text(
            'Motivo de la anulación',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LivoraColors.deep),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LivoraColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReason,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: LivoraColors.deep, fontWeight: FontWeight.w500),
                items: _reasons.map((r) {
                  return DropdownMenuItem(value: r, child: Text(r));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PIN de seguridad
          const Text(
            'Ingresa tu PIN de seguridad (6 dígitos)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LivoraColors.deep),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pinController,
            focusNode: _pinFocus,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: LivoraColors.deep,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              filled: true,
              fillColor: LivoraColors.paper,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: LivoraColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: LivoraColors.border),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Botón de confirmación
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _busy ? null : _submitRefund,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(
              _busy ? 'Procesando anulación…' : 'Confirmar Anulación de Venta',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar y Volver', style: TextStyle(color: LivoraColors.slate)),
          ),
        ],
      ),
    );
  }
}
