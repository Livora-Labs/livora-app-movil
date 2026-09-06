import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';
import '../services/livora_api.dart';
import '../screens/tienda/store_profile_screen.dart';
import 'common.dart';

/// Modal BottomSheet para solicitar liquidación FIAT desde la billetera comercial.
/// Implementa validación estricta de CCI bancario registrado y desglose financiero transparente.
class CashOutModal extends StatefulWidget {
  const CashOutModal({
    super.key,
    required this.availableBalance,
    this.initialBankAccount,
  });

  final double availableBalance;
  final String? initialBankAccount;

  static Future<bool> show(
    BuildContext context, {
    required double availableBalance,
    String? initialBankAccount,
  }) async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CashOutModal(
        availableBalance: availableBalance,
        initialBankAccount: initialBankAccount,
      ),
    );
    return result ?? false;
  }

  @override
  State<CashOutModal> createState() => _CashOutModalState();
}

class _CashOutModalState extends State<CashOutModal> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loadingProfile = false;
  bool _busy = false;
  String? _bankAccount;

  @override
  void initState() {
    super.initState();
    _bankAccount = widget.initialBankAccount;
    if (_bankAccount == null || _bankAccount!.trim().isEmpty) {
      _loadStoreProfile();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final profile = await context.read<LivoraApi>().getStoreProfile();
      if (mounted && profile != null) {
        setState(() {
          _bankAccount = profile['bankAccount']?.toString();
        });
      }
    } catch (_) {
      // Manejo silencioso: se tratará como no registrado si falla
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  double get _enteredAmount {
    final text = _amountController.text.replaceAll(',', '.').trim();
    return double.tryParse(text) ?? 0.0;
  }

  bool get _hasValidCci {
    if (_bankAccount == null) return false;
    final digits = _bankAccount!.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 20;
  }

  void _fillMaxAmount() {
    HapticFeedback.lightImpact();
    final balance = widget.availableBalance;
    _amountController.text = balance > 0 ? balance.toStringAsFixed(2) : '0.00';
    setState(() {});
  }

  Future<void> _submitSettlement() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _enteredAmount;
    if (amount <= 0 || amount > widget.availableBalance) return;

    final api = context.read<LivoraApi>();
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _busy = true);

    try {
      await api.requestSettlement(amount);
      if (mounted) {
        Navigator.pop(context, true);
        showAppSnack(
          context,
          'Solicitud de liquidación por ${amount.toStringAsFixed(2)} ECO enviada correctamente',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al procesar la liquidación', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasCci = _hasValidCci;
    final amount = _enteredAmount;
    final isAmountValid = amount > 0 && amount <= widget.availableBalance;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Asa superior
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: LivoraColors.ink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabecera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_rounded, color: LivoraColors.forest, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Solicitar Liquidación FIAT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Transfiere tus EcoTokens acumulados a tu cuenta bancaria nacional en Soles (PEN).',
              style: TextStyle(fontSize: 12.5, color: LivoraColors.ink),
            ),
            const SizedBox(height: 18),

            if (_loadingProfile) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: LivoraColors.forest),
                ),
              ),
            ] else if (!hasCci) ...[
              // ESTADO 2: SIN CCI REGISTRADO (BLOQUEO PREVENTIVO)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No tienes una cuenta bancaria (CCI) configurada para recibir transferencias en Soles.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade900,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Debes ingresar tu Código de Cuenta Interbancario (CCI) de 20 dígitos en tu perfil comercial para procesar retiros bancarios.',
                      style: TextStyle(fontSize: 12, color: LivoraColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Configurar Cuenta Bancaria (CCI)',
                icon: Icons.edit_note_rounded,
                onPressed: () async {
                  Navigator.pop(context, false);
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
                  );
                },
              ),
            ] else ...[
              // ESTADO 1: CON CCI REGISTRADO (FLUJO HABILITADO)
              // Tarjeta de Destino Bancario
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LivoraColors.forest.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance, color: LivoraColors.forest, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                formatMaskedCci(_bankAccount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: LivoraColors.deep,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, size: 16, color: LivoraColors.green),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Cuenta destino validada (20 dígitos)',
                            style: TextStyle(fontSize: 11, color: LivoraColors.ink),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () async {
                        Navigator.pop(context, false);
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
                        );
                      },
                      child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Formulario de Monto a Liquidar
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Disponible: ${widget.availableBalance.toStringAsFixed(2)} ECO',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: LivoraColors.ink,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          onPressed: _fillMaxAmount,
                          icon: const Icon(Icons.flash_on_rounded, size: 14),
                          label: const Text('Liquidar Saldo Total', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      decoration: livoraInput(
                        'Tokens a liquidar',
                        icon: Icons.toll_outlined,
                        hint: '0.00',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: kDecimalInputFormatters,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final val = double.tryParse((value ?? '').replaceAll(',', '.'));
                        if (val == null || val <= 0) {
                          return 'Ingresa un monto mayor a 0';
                        }
                        if (val < 0.10) {
                          return 'El monto mínimo de liquidación es 0.10 ECO';
                        }
                        if (val > widget.availableBalance) {
                          return 'El monto supera tu saldo disponible';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Desglose Transparente
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LivoraColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monto en EcoTokens:', style: TextStyle(fontSize: 12.5, color: LivoraColors.ink)),
                        Text('${amount.toStringAsFixed(2)} ECO',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tasa de conversión:', style: TextStyle(fontSize: 12.5, color: LivoraColors.ink)),
                        Text('1.00 ECO = S/ 1.00 PEN',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LivoraColors.forest)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('Comisión de transferencia:', style: TextStyle(fontSize: 12.5, color: LivoraColors.ink)),
                            SizedBox(width: 4),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: LivoraColors.mint.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'S/ 0.00 PEN · Promo Lanzamiento',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Abono neto a tu CCI:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                        ),
                        Text(
                          'S/ ${amount.toStringAsFixed(2)} PEN',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botón CTA Principal
              BusyButton(
                label: 'Solicitar Liquidación',
                icon: Icons.send_rounded,
                busy: _busy,
                onPressed: isAmountValid ? _submitSettlement : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
