import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

/// Registro de venta de material consolidado a una empresa B2B.
class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.initialWeightKg});

  final double? initialWeightKg;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  final _amountController = TextEditingController();
  final _buyerController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.initialWeightKg == null
          ? ''
          : fmtNumber(widget.initialWeightKg!),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _amountController.dispose();
    _buyerController.dispose();
    super.dispose();
  }

  double? _num(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<LivoraApi>().createSale(
            weightKg: _num(_weightController)!,
            totalAmount: _num(_amountController)!,
            buyerId: _buyerController.text.trim(),
          );
      if (!mounted) return;
      showAppSnack(context, 'Venta registrada exitosamente');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar venta B2B')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _weightController,
                  decoration: livoraInput(
                    'Peso vendido (kg)',
                    icon: Icons.scale_outlined,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (_) {
                    final weight = _num(_weightController);
                    return weight == null || weight <= 0
                        ? 'Ingresa un peso válido'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  decoration: livoraInput(
                    'Monto total (USD / Token)',
                    icon: Icons.payments_outlined,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (_) {
                    final amount = _num(_amountController);
                    return amount == null || amount <= 0
                        ? 'Ingresa un monto válido'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _buyerController,
                  decoration: livoraInput(
                    'ID de la empresa compradora',
                    hint: 'UUID de la empresa B2B',
                    icon: Icons.business_outlined,
                    helper:
                        'La empresa compradora encuentra su ID de usuario en el perfil de su cuenta Livora.',
                  ),
                  validator: (value) {
                    final uuid = RegExp(
                      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
                      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                    );
                    return uuid.hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Ingresa un UUID válido';
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Al registrar la venta, la empresa podrá recibir su '
                  'certificado ESG de trazabilidad.',
                  style: TextStyle(
                    fontSize: 12,
                    color: LivoraColors.ink.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                BusyButton(
                  label: 'Registrar venta',
                  icon: Icons.point_of_sale,
                  busy: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
