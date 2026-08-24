import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RoleOption {
  const _RoleOption(this.role, this.description);

  final String role;
  final String description;
}

const _roleOptions = [
  _RoleOption(
    Roles.hogar,
    'Solicita recolecciones en casa y gana EcoTokens por reciclar.',
  ),
  _RoleOption(
    Roles.recolector,
    'Acepta solicitudes cercanas y lleva los materiales al centro de acopio.',
  ),
  _RoleOption(
    Roles.centroAcopio,
    'Recibe lotes, pesa materiales, consolida y vende a empresas.',
  ),
  _RoleOption(
    Roles.almacen,
    'Gestiona el inventario de tu tienda y recibe EcoTokens como pago.',
  ),
];

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _role = Roles.hogar;
  bool _obscure = true;
  bool _busy = false;

  /// Replica la validación del `RegisterDto` del backend para que el usuario
  /// vea el error antes de enviar el formulario y no reciba un 400 al final.
  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Debe incluir al menos una minúscula';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Debe incluir al menos una mayúscula';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Debe incluir al menos un número';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_+\-=\[\]\\/]').hasMatch(password)) {
      return 'Debe incluir al menos un símbolo (! @ # \$ % ...)';
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _busy = true);
    try {
      await context.read<SessionController>().register(
            email: email,
            password: _passwordController.text,
            role: _role,
          );
      if (mounted) {
        // El registro solo dispara el envío del OTP: la cuenta y el token
        // salen del paso de verificación.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VerifyEmailScreen(email: email),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
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
                    const SectionTitle(text: '¿Cómo participas en Livora?'),
                    for (final option in _roleOptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RoleCard(
                          option: option,
                          selected: _role == option.role,
                          onTap: () => setState(() => _role = option.role),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const SectionTitle(text: 'Tus datos'),
                    TextFormField(
                      controller: _emailController,
                      decoration: livoraInput(
                        'Correo electrónico',
                        icon: Icons.mail_outline,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value == null || !value.contains('@')
                              ? 'Ingresa un correo válido'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      decoration: livoraInput(
                        'Contraseña',
                        icon: Icons.lock_outline,
                        helper: 'Mínimo 8 caracteres, con mayúscula, '
                            'minúscula, número y símbolo (ej. Password123!)',
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      obscureText: _obscure,
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      decoration: livoraInput(
                        'Confirmar contraseña',
                        icon: Icons.lock_outline,
                      ),
                      obscureText: _obscure,
                      validator: (value) =>
                          value != _passwordController.text
                              ? 'Las contraseñas no coinciden'
                              : null,
                    ),
                    const SizedBox(height: 22),
                    BusyButton(
                      label: 'Crear cuenta',
                      busy: _busy,
                      onPressed: _register,
                    ),
                    const SizedBox(height: 24),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? LivoraColors.mint.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? LivoraColors.forest
                : LivoraColors.deep.withValues(alpha: 0.1),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? LivoraColors.forest
                    : LivoraColors.paper,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Roles.icon(option.role),
                color: selected ? Colors.white : LivoraColors.forest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Roles.label(option.role),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.deep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: LivoraColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: LivoraColors.forest),
          ],
        ),
      ),
    );
  }
}
