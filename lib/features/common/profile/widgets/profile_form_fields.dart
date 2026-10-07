import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Micro-widget para edición de datos de contacto y domicilio con soporte GPS.
class ProfileFormFields extends StatelessWidget {
  const ProfileFormFields({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.isFetchingGps,
    required this.onGpsPressed,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final bool isFetchingGps;
  final VoidCallback onGpsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Personal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Número telefónico',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            decoration: InputDecoration(
              labelText: 'Dirección de referencia',
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: isFetchingGps
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Obtener GPS actual',
                      icon: const Icon(Icons.my_location_rounded, color: LivoraColors.forest),
                      onPressed: onGpsPressed,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
