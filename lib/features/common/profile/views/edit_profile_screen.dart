import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/session.dart';
import '../../../../widgets/common.dart';
import '../view_model/profile_view_model.dart';

/// Pantalla dedicada y enfocada para editar los datos de contacto y domicilio del usuario.
/// Incorpora navegación limpia con retroceso '<' y botón de guardar que solo se activa al haber cambios.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.viewModel,
  });

  final ProfileViewModel viewModel;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  double? _latitude;
  double? _longitude;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final sessionUser = context.read<SessionController>().user;
    final u = widget.viewModel.user;
    final initialName = (u.name?.trim().isNotEmpty == true)
        ? u.name!
        : (sessionUser?.name?.trim().isNotEmpty == true ? sessionUser!.name! : '');
    final initialPhone = (u.phone?.trim().isNotEmpty == true)
        ? u.phone!
        : (sessionUser?.phone?.trim().isNotEmpty == true ? sessionUser!.phone! : '');
    final initialAddress = (u.address?.trim().isNotEmpty == true)
        ? u.address!
        : (sessionUser?.address?.trim().isNotEmpty == true ? sessionUser!.address! : '');

    _nameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: initialPhone);
    _addressController = TextEditingController(text: initialAddress);
    _latitude = u.latitude ?? sessionUser?.latitude;
    _longitude = u.longitude ?? sessionUser?.longitude;

    _nameController.addListener(_checkDirty);
    _phoneController.addListener(_checkDirty);
    _addressController.addListener(_checkDirty);
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkDirty);
    _phoneController.removeListener(_checkDirty);
    _addressController.removeListener(_checkDirty);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _checkDirty() {
    final sessionUser = context.read<SessionController>().user;
    final u = widget.viewModel.user;
    final origName = (u.name?.trim().isNotEmpty == true)
        ? u.name!.trim()
        : (sessionUser?.name?.trim() ?? '');
    final origPhone = (u.phone?.trim().isNotEmpty == true)
        ? u.phone!.trim()
        : (sessionUser?.phone?.trim() ?? '');
    final origAddress = (u.address?.trim().isNotEmpty == true)
        ? u.address!.trim()
        : (sessionUser?.address?.trim() ?? '');
    final origLat = u.latitude ?? sessionUser?.latitude;
    final origLng = u.longitude ?? sessionUser?.longitude;

    final dirty = _nameController.text.trim() != origName ||
        _phoneController.text.trim() != origPhone ||
        _addressController.text.trim() != origAddress ||
        _latitude != origLat ||
        _longitude != origLng;

    if (dirty != _isDirty && mounted) {
      setState(() => _isDirty = dirty);
    }
  }

  Future<void> _handleGps() async {
    final data = await widget.viewModel.fetchCurrentGps();
    if (data != null && mounted) {
      setState(() {
        _latitude = data['latitude'] as double?;
        _longitude = data['longitude'] as double?;
        final addr = data['address'] as String?;
        if (addr != null && addr.isNotEmpty) {
          _addressController.text = addr;
        }
        _isDirty = true;
      });
      showAppSnack(context, 'Ubicación GPS actualizada.');
    } else if (mounted) {
      showAppSnack(context, 'No se pudo obtener la posición GPS actual.');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final session = context.read<SessionController>();
    final ok = await widget.viewModel.updateProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    if (mounted) {
      if (ok) {
        await session.updateUser(widget.viewModel.user);
        if (!mounted) return;
        showAppSnack(context, 'Perfil actualizado correctamente.');
        Navigator.of(context).pop(true);
      } else {
        showAppSnack(
          context,
          widget.viewModel.feedbackMessage ?? 'Error al actualizar perfil',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return Scaffold(
      backgroundColor: LivoraColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Editar Perfil'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos Personales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.deep,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mantén tus datos actualizados para facilitar la llegada del recolector.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre y Apellidos',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de contacto',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Dirección o Domicilio de Recojo',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: vm.isFetchingGps
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Capturar GPS actual',
                              icon: const Icon(Icons.my_location_rounded,
                                  color: LivoraColors.forest),
                              onPressed: _handleGps,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDirty ? LivoraColors.forest : Colors.grey.shade300,
                foregroundColor: _isDirty ? Colors.white : Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _isDirty ? 3 : 0,
              ),
              onPressed: (_isDirty && !vm.isSaving) ? _handleSave : null,
              child: vm.isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Guardar Cambios',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
