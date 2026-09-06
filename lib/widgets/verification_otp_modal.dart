import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';
import '../models/models.dart';
import '../services/livora_api.dart';
import '../services/offline_queue_manager.dart';
import 'common.dart';

/// Modal emergente de alta fidelidad para el ingreso del PIN de 4 dígitos
/// dictado por el ciudadano y la confirmación/ajuste de pesos reales en campo.
class VerificationOtpModal extends StatefulWidget {
  const VerificationOtpModal({
    super.key,
    required this.request,
  });

  final CollectionRequest request;

  static Future<bool?> show(
    BuildContext context, {
    required CollectionRequest request,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerificationOtpModal(request: request),
    );
  }

  @override
  State<VerificationOtpModal> createState() => _VerificationOtpModalState();
}

class _VerificationOtpModalState extends State<VerificationOtpModal> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  final Map<String, TextEditingController> _weightControllers = {};

  bool _showWeightAdjustment = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final items = widget.request.itemsEstimated;
    items.forEach((mat, weight) {
      _weightControllers[mat] = TextEditingController(
        text: weight > 0 ? weight.toStringAsFixed(1) : '0.0',
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    for (final ctrl in _weightControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _adjustWeight(String mat, double delta) {
    final ctrl = _weightControllers[mat];
    if (ctrl == null) return;
    final current = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
    double updated = current + delta;
    if (updated < 0.5 && updated > 0) {
      updated = delta < 0 ? 0.0 : 0.5;
    } else if (updated < 0) {
      updated = 0.0;
    } else if (updated > 999.0) {
      updated = 999.0;
    }
    setState(() {
      ctrl.text = updated.toStringAsFixed(1);
    });
  }

  Map<String, double> _collectWeights() {
    final result = <String, double>{};
    _weightControllers.forEach((mat, ctrl) {
      final w = double.tryParse(ctrl.text.replaceAll(',', '.'));
      if (w != null && w >= 0.5) {
        result[mat] = double.parse(w.toStringAsFixed(2));
      }
    });
    return result;
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) return;

    final actualWeights = _collectWeights();
    setState(() => _submitting = true);

    try {
      await context.read<LivoraApi>().verifyCollectionRequest(
            widget.request.id,
            pin,
            actualWeights: actualWeights.isNotEmpty ? actualWeights : null,
          );

      if (mounted) {
        showAppSnack(context, 'Recolección verificada y liquidada con éxito');
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      final statusCode = error.statusCode;
      final isNetworkError = statusCode == null ||
          statusCode >= 500 ||
          error.isRateLimited ||
          error.message.toLowerCase().contains('no se pudo conectar') ||
          error.message.toLowerCase().contains('servidor no respondió') ||
          error.message.toLowerCase().contains('conexión');

      if (isNetworkError) {
        await OfflineQueueManager.enqueueVerification(
          widget.request.id,
          pin,
          actualWeights: actualWeights.isNotEmpty ? actualWeights : null,
        );

        if (mounted) {
          widget.request.status = 'COMPLETED';
          showAppSnack(
            context,
            'Sin cobertura. Verificación guardada en el dispositivo; se sincronizará automáticamente.',
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          showAppSnack(context, error.message, error: true);
        }
      }
    } catch (_) {
      await OfflineQueueManager.enqueueVerification(
        widget.request.id,
        pin,
        actualWeights: actualWeights.isNotEmpty ? actualWeights : null,
      );

      if (mounted) {
        widget.request.status = 'COMPLETED';
        showAppSnack(
          context,
          'Guardado localmente. Se sincronizará al recuperar internet.',
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final householdLabel = req.householdName?.isNotEmpty == true
        ? req.householdName!
        : (req.householdEmail?.isNotEmpty == true
            ? req.householdEmail!.split('@').first
            : 'Hogar');
    final addressLabel = req.householdAddress?.isNotEmpty == true
        ? req.householdAddress!
        : 'Dirección física registrada vía GPS';

    final pin = _pinController.text;
    final isPinComplete = pin.length == 4;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra superior decorativa
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header con Información del Hogar
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: LivoraColors.blue.withValues(alpha: 0.12),
                  child: const Icon(Icons.home_outlined, color: LivoraColors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        householdLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        addressLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: LivoraColors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Título instructivo del PIN
            const Text(
              'Ingresa el PIN de 4 dígitos dictado por el ciudadano:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: LivoraColors.ink,
              ),
            ),
            const SizedBox(height: 14),

            // Cajas visuales de alto contraste para OTP
            GestureDetector(
              onTap: () => _pinFocus.requestFocus(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Campo invisible pero accesible para el teclado del sistema
                  Opacity(
                    opacity: 0.0,
                    child: TextField(
                      controller: _pinController,
                      focusNode: _pinFocus,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  // Cajas OTP visuales de alto contraste
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final digit = index < pin.length ? pin[index] : '';
                      final isCurrent = index == pin.length;
                      final isFilled = digit.isNotEmpty;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: isFilled
                              ? LivoraColors.blue.withValues(alpha: 0.08)
                              : LivoraColors.paper,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? LivoraColors.blue
                                : (isFilled
                                    ? LivoraColors.blue.withValues(alpha: 0.8)
                                    : LivoraColors.border),
                            width: isCurrent || isFilled ? 2.0 : 1.2,
                          ),
                          boxShadow: isFilled
                              ? [
                                  BoxShadow(
                                    color: LivoraColors.blue.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            digit,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: LivoraColors.deep,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Sección Desplegable "Ajustar Pesos Reales (Opcional)"
            Card(
              elevation: 0,
              color: LivoraColors.paper,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: LivoraColors.border),
              ),
              child: ExpansionTile(
                initiallyExpanded: _showWeightAdjustment,
                onExpansionChanged: (exp) => setState(() => _showWeightAdjustment = exp),
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                shape: const Border(),
                leading: const Icon(Icons.scale_outlined, color: LivoraColors.forest, size: 22),
                title: const Text(
                  'Ajustar Pesos Reales (Opcional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: LivoraColors.deep,
                  ),
                ),
                subtitle: Text(
                  'Estimado total: ${fmtKg(req.totalEstimatedKg)}',
                  style: const TextStyle(fontSize: 11, color: LivoraColors.forest),
                ),
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Si pesas con báscula portátil, ajusta los kg recolectados:',
                    style: TextStyle(fontSize: 11.5, color: LivoraColors.ink),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in _weightControllers.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              materialLabel(entry.key),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ),
                          // Botón decrementar (-0.5 kg)
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _adjustWeight(entry.key, -0.5),
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: 6),
                          // Campo de entrada directa
                          SizedBox(
                            width: 68,
                            height: 38,
                            child: TextField(
                              controller: entry.value,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: kDecimalInputFormatters,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                suffixText: 'kg',
                                suffixStyle: const TextStyle(fontSize: 10),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: LivoraColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: LivoraColors.border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Botón incrementar (+0.5 kg)
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _adjustWeight(entry.key, 0.5),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CTA Principal de Validación
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: isPinComplete ? LivoraColors.forest : Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (!isPinComplete || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(
                _submitting ? 'Verificando…' : 'Validar Entrega',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
