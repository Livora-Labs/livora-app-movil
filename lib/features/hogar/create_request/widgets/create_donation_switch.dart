import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Componente modular para el toggle de Donación Solidaria.
/// Permite al hogar donar el 100% del valor de su reciclaje al recolector ambiental.
class CreateDonationSwitch extends StatelessWidget {
  const CreateDonationSwitch({
    super.key,
    required this.isDonation,
    required this.onChanged,
  });

  final bool isDonation;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDonation ? const Color(0xFFFDF2F8) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDonation ? const Color(0xFFF472B6) : Colors.grey.shade300,
          width: isDonation ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDonation
                  ? const Color(0xFFEC4899)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.volunteer_activism_rounded,
              size: 22,
              color: isDonation ? Colors.white : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Donación Solidaria',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isDonation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBCFE8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '100% donado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9D174D),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isDonation
                      ? 'El 100% del valor económico del reciclaje se transfiere como apoyo directo al recolector.'
                      : 'Activa si deseas ceder la recompensa en LIVOs como donación al recolector.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDonation,
            activeColor: const Color(0xFFEC4899),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
