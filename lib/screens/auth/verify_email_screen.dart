import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

/// Paso 2 del registro: el backend guardó los datos en Redis y envió un código
/// de 6 dígitos al correo. Al verificarlo se crea la cuenta y se abre sesión.
///
/// Tiempos del backend (`AuthService`): el OTP vive 10 minutos y el reenvío
/// tiene un cooldown de 60 s.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _otpLifetime = Duration(minutes: 10);
  static const _resendCooldown = Duration(seconds: 60);

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  Timer? _ticker;
  Duration _expiresIn = _otpLifetime;
  Duration _resendIn = _resendCooldown;
  bool _busy = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_expiresIn > Duration.zero) {
          _expiresIn -= const Duration(seconds: 1);
        }
        if (_resendIn > Duration.zero) {
          _resendIn -= const Duration(seconds: 1);
        }
      });
    });
  }

  String _mmss(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<SessionController>().verifyEmail(
            email: widget.email,
            code: _codeController.text.trim(),
          );
      if (mounted) {
        // La raíz de la app ya muestra el panel del rol al haber sesión.
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Ocurrió un error inesperado', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await context.read<SessionController>().resendOtp(widget.email);
      if (!mounted) return;
      setState(() {
        _resendIn = _resendCooldown;
        _expiresIn = _otpLifetime;
      });
      showAppSnack(context, 'Te enviamos un código nuevo');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _expiresIn <= Duration.zero;
    final canResend = _resendIn <= Duration.zero && !_resending;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu correo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 56,
                      color: LivoraColors.forest,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enviamos un código de 6 dígitos a',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: LivoraColors.ink.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _codeController,
                      decoration: livoraInput(
                        'Código de verificación',
                        hint: '123456',
                        icon: Icons.password_outlined,
                        helper: expired
                            ? 'El código caducó. Pide uno nuevo.'
                            : 'El código caduca en ${_mmss(_expiresIn)}.',
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) => (value ?? '').trim().length != 6
                          ? 'Ingresa los 6 dígitos'
                          : null,
                      onFieldSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 8),
                    BusyButton(
                      label: 'Verificar y entrar',
                      busy: _busy,
                      onPressed: _verify,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: canResend ? _resend : null,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        canResend
                            ? 'Reenviar código'
                            : 'Reenviar código (${_mmss(_resendIn)})',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Revisa también la carpeta de spam. Si el código caduca, '
                      'pide uno nuevo con "reenviar": tu registro se conserva '
                      '30 minutos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: LivoraColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
