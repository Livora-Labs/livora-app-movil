import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

class StoreQrGeneratorScreen extends StatefulWidget {
  const StoreQrGeneratorScreen({super.key});

  @override
  State<StoreQrGeneratorScreen> createState() => _StoreQrGeneratorScreenState();
}

class _StoreQrGeneratorScreenState extends State<StoreQrGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _qrRef;
  double? _generatedAmount;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    setState(() => _busy = true);
    try {
      final res = await context.read<LivoraApi>().generateQrRedemption(amount);
      final ref = res['qrCodeRef']?.toString();
      if (ref != null && mounted) {
        setState(() {
          _qrRef = ref;
          _generatedAmount = amount;
        });
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _qrRef = null;
      _generatedAmount = null;
      _amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobrar EcoTokens'),
        backgroundColor: LivoraColors.deep,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_qrRef == null) ...[
                const Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: LivoraColors.forest,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cobro en EcoTokens',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: LivoraColors.deep,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa la cantidad de tokens que deseas cobrar. El ciudadano escaneará tu código desde su billetera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: LivoraColors.ink,
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: livoraInput(
                      'Monto a cobrar',
                      icon: Icons.toll_outlined,
                      hint: '0.00',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    validator: (value) {
                      final val = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      if (val == null || val <= 0) {
                        return 'Ingresa un valor mayor a 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                BusyButton(
                  label: 'Generar QR de cobro',
                  icon: Icons.qr_code_2,
                  busy: _busy,
                  onPressed: _generate,
                ),
              ] else ...[
                const Text(
                  'Solicitud de Pago Lista',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LivoraColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monto: $_generatedAmount ECO',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrRef!,
                      version: QrVersions.auto,
                      size: 220,
                      gapless: false,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Código de referencia:\n$_qrRef',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: LivoraColors.ink.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: LivoraColors.forest),
                    foregroundColor: LivoraColors.forest,
                  ),
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nuevo cobro'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
