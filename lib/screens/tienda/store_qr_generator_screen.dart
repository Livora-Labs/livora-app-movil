import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/store_qr_modal.dart';
import '../common/profile.dart';

/// Pantalla de Cobro POS para el rol TIENDA con Keypad táctil estilizado,
/// denominaciones rápidas y despliegue de StoreQrModal.
class StoreQrGeneratorScreen extends StatefulWidget {
  const StoreQrGeneratorScreen({super.key});

  @override
  State<StoreQrGeneratorScreen> createState() => _StoreQrGeneratorScreenState();
}

class _StoreQrGeneratorScreenState extends State<StoreQrGeneratorScreen> {
  String _amountRaw = '';
  bool _busy = false;

  static const List<double> _quickChips = [5.0, 10.0, 20.0, 50.0];

  double get _currentAmount {
    if (_amountRaw.isEmpty) return 0.0;
    return double.tryParse(_amountRaw) ?? 0.0;
  }

  void _onKeyPress(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == 'backspace') {
        if (_amountRaw.isNotEmpty) {
          _amountRaw = _amountRaw.substring(0, _amountRaw.length - 1);
        }
      } else if (key == '.') {
        if (!_amountRaw.contains('.')) {
          if (_amountRaw.isEmpty) {
            _amountRaw = '0.';
          } else {
            _amountRaw += '.';
          }
        }
      } else {
        // Validación de decimales: máximo 2 dígitos tras el punto
        if (_amountRaw.contains('.')) {
          final parts = _amountRaw.split('.');
          if (parts.length > 1 && parts[1].length >= 2) {
            return;
          }
        }
        // Evitar números absurdos (> 99999)
        if (_amountRaw.length >= 7) return;

        if (_amountRaw == '0') {
          _amountRaw = key;
        } else {
          _amountRaw += key;
        }
      }
    });
  }

  void _setAmount(double value) {
    HapticFeedback.lightImpact();
    setState(() {
      _amountRaw = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
    });
  }

  void _resetAmount() {
    setState(() => _amountRaw = '');
  }

  Future<void> _generateQr() async {
    final amount = _currentAmount;
    if (amount < 0.10) {
      showAppSnack(context, 'El monto mínimo de cobro es 0.10 ECO', error: true);
      return;
    }

    final api = context.read<LivoraApi>();
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _busy = true);

    try {
      final res = await api.generateQrRedemption(amount);
      final ref = res['qrCodeRef']?.toString();
      if (ref != null && mounted) {
        setState(() => _busy = false);

        // Desplegar modal reactivo de cobro
        final success = await StoreQrModal.show(
          context,
          amount: amount,
          qrRef: ref,
        );

        if (success && mounted) {
          _resetAmount();
          showAppSnack(
            context,
            'Cobro por S/ ${amount.toStringAsFixed(2)} completado con éxito',
          );
        }
      } else {
        throw Exception('Respuesta inválida del servidor');
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al generar código QR de cobro', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _currentAmount;
    final isCtaEnabled = amount >= 0.10 && !_busy;

    return Scaffold(
      appBar: livoraAppBar(context, 'Cobrar EcoTokens'),
      body: SafeArea(
        child: Column(
          children: [
            // Sección superior: Monto e Indicadores
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Título / Rol
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: LivoraColors.forest.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.point_of_sale_rounded, size: 16, color: LivoraColors.forest),
                          SizedBox(width: 6),
                          Text(
                            'PUNTO DE VENTA (POS)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.forest,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Monto formateado en Soles (PEN)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'S/ ${_amountRaw.isEmpty ? "0.00" : _amountRaw}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _amountRaw.isEmpty
                              ? LivoraColors.ink.withValues(alpha: 0.3)
                              : LivoraColors.deep,
                          letterSpacing: -1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),
                    // Equivalencia exacta en EcoTokens
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LivoraColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.toll_rounded, size: 16, color: LivoraColors.green),
                          const SizedBox(width: 6),
                          Text(
                            '${amount.toStringAsFixed(2)} ECO',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(1.00 ECO = S/ 1.00 PEN)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: LivoraColors.ink.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_amountRaw.isNotEmpty && amount < 0.10)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'El monto mínimo de cobro es 0.10 ECO',
                          style: TextStyle(
                            color: Color(0xFFC0392B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    // Fila de Chips de Denominaciones Rápidas
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: _quickChips.map((val) {
                        final isSelected = amount == val;
                        return ActionChip(
                          avatar: Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : LivoraColors.forest,
                          ),
                          label: Text('S/ ${val.toInt()}'),
                          backgroundColor: isSelected ? LivoraColors.forest : Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : LivoraColors.deep,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? LivoraColors.forest
                                : LivoraColors.forest.withValues(alpha: 0.25),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onPressed: () => _setAmount(val),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Keypad Táctil Numérico 4x3 (PosKeypad)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 8),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 8),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 8),
                  _buildKeypadRow(['.', '0', 'backspace']),
                  const SizedBox(height: 16),

                  // Botón Primario CTA: "Generar QR de cobro"
                  BusyButton(
                    label: 'Generar QR de cobro',
                    icon: Icons.qr_code_2_rounded,
                    busy: _busy,
                    onPressed: isCtaEnabled ? _generateQr : null,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _KeypadButton(
              label: k,
              onTap: () => _onKeyPress(k),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == 'backspace';
    final isDot = label == '.';

    return Material(
      color: LivoraColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: LivoraColors.mint.withValues(alpha: 0.25),
        highlightColor: LivoraColors.forest.withValues(alpha: 0.08),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LivoraColors.border),
          ),
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, size: 22, color: LivoraColors.deep)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: isDot ? 28 : 22,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
        ),
      ),
    );
  }
}
