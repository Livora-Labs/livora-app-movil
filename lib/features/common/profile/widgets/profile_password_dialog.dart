import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../widgets/common.dart';

/// Modal para cambio seguro de contraseña.
class ProfilePasswordDialog extends StatefulWidget {
  const ProfilePasswordDialog({
    super.key,
    required this.onSave,
  });

  final Future<bool> Function(String current, String newPass) onSave;

  static Future<void> show(BuildContext context, Future<bool> Function(String, String) onSave) {
    return showDialog(
      context: context,
      builder: (_) => ProfilePasswordDialog(onSave: onSave),
    );
  }

  @override
  State<ProfilePasswordDialog> createState() => _ProfilePasswordDialogState();
}

class _ProfilePasswordDialogState extends State<ProfilePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final ok = await widget.onSave(
      _currentController.text.trim(),
      _newController.text.trim(),
    );

    if (mounted) {
      setState(() => _busy = false);
      if (ok) {
        Navigator.of(context).pop();
        showAppSnack(context, 'Contraseña actualizada exitosamente');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Cambiar Contraseña', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _newController.text) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: LivoraColors.forest),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
