import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../core/stellar.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/web3_confirm_modal.dart';
import '../../../../screens/common/qr_scanner_view.dart';

/// Tarjeta y formulario de transferencia directa de tokens LIVOs con Web3 signing modal.
class WalletTransferCard extends StatefulWidget {
  final bool isSending;
  final String? userRole;
  final Future<void> Function(String toAddress, double amount) onSend;

  const WalletTransferCard({
    super.key,
    required this.isSending,
    required this.userRole,
    required this.onSend,
  });

  @override
  State<WalletTransferCard> createState() => _WalletTransferCardState();
}

class _WalletTransferCardState extends State<WalletTransferCard> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final toAddress = Stellar.normalize(_addressController.text);

    final confirmed = await showWeb3ConfirmModal(
      context,
      tokenAmount: amount,
      destinationName: 'Billetera Externa',
      destinationAddress: toAddress,
      actionDescription: 'Transferencia Directa de LIVOs',
      concept: 'Transferencia P2P',
    );
    if (!confirmed || !mounted) return;

    await widget.onSend(toAddress, amount);
    if (mounted) {
      _addressController.clear();
      _amountController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHogar = widget.userRole == 'HOGAR';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          text: isHogar ? 'Donar o Transferir LIVOs' : 'Transferir LIVOs',
        ),
        if (isHogar) ...[
          const SizedBox(height: 4),
          const Text(
            'Puedes transferir LIVOs a familiares o donar tus recompensas a recicladores de base mediante su clave pública Stellar.',
            style: TextStyle(fontSize: 12, color: LivoraColors.slate),
          ),
          const SizedBox(height: 10),
        ],
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
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z2-7]')),
                      TextInputFormatter.withFunction(
                        (_, next) => next.copyWith(text: next.text.toUpperCase()),
                      ),
                    ],
                    validator: (value) => Stellar.isValidAddress(value)
                        ? null
                        : 'Dirección de billetera inválida (formato G… de 56 caracteres)',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amountController,
                    decoration: livoraInput('Cantidad', icon: Icons.toll_outlined),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: kDecimalInputFormatters,
                    validator: (value) => validateAmount(value, min: 0.10, unit: 'LIVO'),
                  ),
                  const SizedBox(height: 16),
                  BusyButton(
                    label: 'Enviar',
                    icon: Icons.send_rounded,
                    busy: widget.isSending,
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
