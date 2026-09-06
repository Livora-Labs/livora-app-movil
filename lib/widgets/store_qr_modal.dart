import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';
import '../services/livora_api.dart';
import '../services/livora_realtime.dart';
import 'common.dart';

enum _QrModalState {
  waitingPayment,
  success,
  expired,
}

/// Modal reactivo de cobranza POS con código QR dinámico, temporizador de 5 minutos
/// y recepción de eventos WebSocket en tiempo real (`redemption:completed`).
class StoreQrModal extends StatefulWidget {
  const StoreQrModal({
    super.key,
    required this.initialAmount,
    required this.initialQrRef,
  });

  final double initialAmount;
  final String initialQrRef;

  /// Abre el modal y retorna `true` si el cobro se completó exitosamente.
  static Future<bool> show(
    BuildContext context, {
    required double amount,
    required String qrRef,
  }) async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => StoreQrModal(
        initialAmount: amount,
        initialQrRef: qrRef,
      ),
    );
    return result ?? false;
  }

  @override
  State<StoreQrModal> createState() => _StoreQrModalState();
}

class _StoreQrModalState extends State<StoreQrModal> {
  static const int _kTotalSeconds = 300; // 5 minutos exactos

  late double _amount;
  late String _qrRef;

  _QrModalState _state = _QrModalState.waitingPayment;
  int _secondsLeft = _kTotalSeconds;

  Timer? _countdownTimer;
  Timer? _fallbackPollTimer;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  bool _isRegenerating = false;
  Map<String, dynamic>? _successPayload;

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount;
    _qrRef = widget.initialQrRef;
    _startTimersAndSubscriptions();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fallbackPollTimer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  void _startTimersAndSubscriptions() {
    _countdownTimer?.cancel();
    _fallbackPollTimer?.cancel();
    _wsSub?.cancel();

    _secondsLeft = _kTotalSeconds;
    _state = _QrModalState.waitingPayment;

    // Temporizador regresivo de 5 minutos
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _fallbackPollTimer?.cancel();
        _wsSub?.cancel();
        setState(() {
          _secondsLeft = 0;
          _state = _QrModalState.expired;
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });

    // Suscripción WebSocket al evento 'redemption:completed'
    final realtime = context.read<LivoraRealtime>();
    _wsSub = realtime.on(RealtimeEvents.redemptionCompleted).listen((data) {
      final incomingRef = data['qrCodeRef']?.toString() ?? data['redemptionId']?.toString();
      if (incomingRef != null && (incomingRef == _qrRef || incomingRef.contains(_qrRef))) {
        _onPaymentSuccess(data);
      }
    });

    // Polling de respaldo cada 7 segundos para garantizar consistencia si el socket reconecta
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 7), (_) async {
      if (!mounted || _state != _QrModalState.waitingPayment) return;
      try {
        final api = context.read<LivoraApi>();
        final details = await api.redemptionDetails(_qrRef);
        final status = details['status']?.toString().toUpperCase();
        if (status == 'COMPLETED' || status == 'CONFIRMED') {
          _onPaymentSuccess(details);
        }
      } catch (_) {
        // Ignorar fallos transitorios de polling
      }
    });
  }

  void _onPaymentSuccess(Map<String, dynamic> data) {
    if (_state == _QrModalState.success || !mounted) return;
    _countdownTimer?.cancel();
    _fallbackPollTimer?.cancel();
    _wsSub?.cancel();

    HapticFeedback.vibrate();

    setState(() {
      _state = _QrModalState.success;
      _successPayload = data;
    });
  }

  Future<void> _regenerateQr() async {
    setState(() => _isRegenerating = true);
    try {
      final api = context.read<LivoraApi>();
      final res = await api.generateQrRedemption(_amount);
      final newRef = res['qrCodeRef']?.toString();
      if (newRef != null && mounted) {
        setState(() {
          _qrRef = newRef;
          _isRegenerating = false;
        });
        _startTimersAndSubscriptions();
      } else {
        throw Exception('No se generó el código QR');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isRegenerating = false);
        showAppSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRegenerating = false);
        showAppSnack(context, 'Error al renovar código de cobro', error: true);
      }
    }
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
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
            switch (_state) {
              _QrModalState.waitingPayment => _buildWaitingView(),
              _QrModalState.success => _buildSuccessView(),
              _QrModalState.expired => _buildExpiredView(),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    final timerWarning = _secondsLeft <= 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: LivoraColors.forest, size: 24),
                SizedBox(width: 8),
                Text(
                  'Cobro en EcoTokens POS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Cancelar cobro',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Badge de temporizador
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: timerWarning
                  ? Colors.red.shade50
                  : LivoraColors.forest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: timerWarning
                    ? Colors.red.shade300
                    : LivoraColors.forest.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 15,
                  color: timerWarning ? Colors.red : LivoraColors.forest,
                ),
                const SizedBox(width: 6),
                Text(
                  'Expira en ${_formatTimer(_secondsLeft)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: timerWarning ? Colors.red : LivoraColors.forest,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Monto principal
        Text(
          'S/ ${_amount.toStringAsFixed(2)} PEN',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: LivoraColors.deep,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '≈ ${_amount.toStringAsFixed(2)} ECO (Tasa 1:1)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: LivoraColors.ink.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 18),
        // Contenedor del código QR vectorial
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: LivoraColors.forest.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: LivoraColors.forest.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: QrImageView(
              data: _qrRef,
              version: QrVersions.auto,
              size: 210,
              gapless: false,
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
        ),
        const SizedBox(height: 14),
        Text(
          'Código: $_qrRef',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: LivoraColors.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: LivoraColors.forest,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Esperando escaneo del cliente...',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: LivoraColors.ink.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: LivoraColors.ink,
            side: BorderSide(color: LivoraColors.ink.withValues(alpha: 0.25)),
            minimumSize: const Size(double.infinity, 44),
          ),
          child: const Text('Cancelar cobro'),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final ticketLabel = formatCustomerTicket(_successPayload ?? {'qrCodeRef': _qrRef});

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: LivoraColors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: LivoraColors.green,
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '¡Cobro Exitoso!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: LivoraColors.deep,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Los tokens han sido acreditados a tu billetera comercial.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: LivoraColors.ink.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LivoraColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LivoraColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monto cobrado:',
                    style: TextStyle(fontSize: 13, color: LivoraColors.ink),
                  ),
                  Text(
                    'S/ ${_amount.toStringAsFixed(2)} PEN',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.deep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Acreditado:',
                    style: TextStyle(fontSize: 13, color: LivoraColors.ink),
                  ),
                  Text(
                    '+${_amount.toStringAsFixed(2)} ECO',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: LivoraColors.forest,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Comprador:',
                    style: TextStyle(fontSize: 13, color: LivoraColors.ink),
                  ),
                  Text(
                    ticketLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LivoraColors.deep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BusyButton(
          label: 'Realizar nuevo cobro',
          icon: Icons.refresh_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }

  Widget _buildExpiredView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.18,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: _qrRef,
                    version: QrVersions.auto,
                    size: 160,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Código QR expirado',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tiempo de Cobro Agotado',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: LivoraColors.deep,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Por seguridad, este código QR ha expirado al superarse los 5 minutos de validez.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: LivoraColors.ink.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 24),
        BusyButton(
          label: 'Regenerar QR',
          icon: Icons.autorenew_rounded,
          busy: _isRegenerating,
          onPressed: _regenerateQr,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar cobro'),
        ),
      ],
    );
  }
}
