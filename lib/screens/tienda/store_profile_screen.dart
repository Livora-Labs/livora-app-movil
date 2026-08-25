import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _rucController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankAccountController = TextEditingController();

  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _rucController.dispose();
    _addressController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final api = context.read<LivoraApi>();
      final profile = await api.getStoreProfile();
      if (profile != null && mounted) {
        _businessNameController.text = profile['businessName']?.toString() ?? '';
        _rucController.text = profile['ruc']?.toString() ?? '';
        _addressController.text = profile['address']?.toString() ?? '';
        _bankAccountController.text = profile['bankAccount']?.toString() ?? '';
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final api = context.read<LivoraApi>();
      await api.updateStoreProfile(
        businessName: _businessNameController.text.trim(),
        ruc: _rucController.text.trim(),
        address: _addressController.text.trim(),
        bankAccount: _bankAccountController.text.trim(),
      );
      if (mounted) {
        showAppSnack(context, 'Perfil comercial guardado con éxito');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Comercial de Tienda'),
        backgroundColor: LivoraColors.deep,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Información de Negocio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Registra los datos fiscales de tu establecimiento y la cuenta bancaria para recibir tus liquidaciones en moneda nacional (Fiat BCP/CCI).',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: livoraInput(
                        'Razón Social / Nombre Comercial',
                        icon: Icons.store_outlined,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa la razón social del negocio'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rucController,
                      decoration: livoraInput(
                        'RUC',
                        icon: Icons.badge_outlined,
                        hint: '20608912345',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().length != 11) {
                          return 'El RUC debe tener 11 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: livoraInput(
                        'Dirección Comercial',
                        icon: Icons.location_on_outlined,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa la dirección física de la tienda'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankAccountController,
                      decoration: livoraInput(
                        'Cuenta Bancaria (BCP CCI)',
                        icon: Icons.account_balance_outlined,
                        hint: '002-191-XXXXXXXXXXXXXXXX-XX',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa tu cuenta interbancaria (CCI)'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: LivoraColors.forest,
                        minimumSize: const Size(0, 50),
                      ),
                      onPressed: _busy ? null : _saveProfile,
                      child: _busy
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Guardar Configuración Comercial'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
