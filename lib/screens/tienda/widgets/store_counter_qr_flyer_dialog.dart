import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/app_theme.dart';
import '../../../widgets/common.dart';

/// Diálogo con el Cartel Institucional de Mostrador para el comercio aliado.
/// Diseñado para exhibirse en el punto de venta o exportarse para impresión en acrílico/vinilo.
class StoreCounterQrFlyerDialog extends StatelessWidget {
  const StoreCounterQrFlyerDialog({
    super.key,
    required this.businessName,
    required this.walletAddress,
    required this.ruc,
    required this.address,
  });

  final String businessName;
  final String walletAddress;
  final String ruc;
  final String address;

  static Future<void> show(
    BuildContext context, {
    required String businessName,
    required String walletAddress,
    required String ruc,
    required String address,
  }) {
    HapticFeedback.lightImpact();
    return showDialog<void>(
      context: context,
      builder: (_) => StoreCounterQrFlyerDialog(
        businessName: businessName,
        walletAddress: walletAddress,
        ruc: ruc,
        address: address,
      ),
    );
  }

  String get _qrPayload {
    // Formato estructurado del QR estático de tienda para escaneo directo
    return 'livora:pay:$walletAddress?name=${Uri.encodeComponent(businessName)}&ruc=$ruc';
  }

  void _copyQrLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _qrPayload));
    HapticFeedback.mediumImpact();
    showAppSnack(context, 'Identificador y enlace del comercio copiado al portapapeles');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabecera institucional del cartel
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LivoraColors.brandGradient,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'COMERCIO ALIADO OFICIAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      businessName.isNotEmpty ? businessName : 'Mi Comercio Aliado',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ruc.isNotEmpty ? 'RUC: $ruc' : 'Comercio Registrado en Livora',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Cuerpo con el Código QR de alta resolución
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    const Text(
                      'Paga aquí con tus LIVOs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Escanea este código desde la app Livora para pagar tus compras al instante.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: LivoraColors.slate,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Marco decorativo del QR
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: LivoraColors.border, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _qrPayload,
                        version: QrVersions.auto,
                        size: 200,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: LivoraColors.deep,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dirección física del local
                    if (address.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: LivoraColors.slate),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              address,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: LivoraColors.slate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Badge de Paridad Oficial
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: LivoraColors.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: LivoraColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.currency_exchange_rounded, size: 14, color: LivoraColors.forest),
                          SizedBox(width: 6),
                          Text(
                            'Paridad garantizada: 1 LIVO = S/ 1.00 PEN',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Botones de acción inferiores
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: LivoraColors.forest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _copyQrLink(context),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text(
                          'Copiar Datos del Cartel',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(color: LivoraColors.slate, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
