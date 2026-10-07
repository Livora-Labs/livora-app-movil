import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Selector interactivo para el modo de asignación de la recolección:
/// 1. Asignación Rápida Automática (algoritmo despacha al recolector más cercano).
/// 2. Subasta Ecológica Inversa (los centros de acopio pujan por tu lote).
class CreateAssignmentModeSelector extends StatelessWidget {
  const CreateAssignmentModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final String selectedMode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modo de Asignación',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: LivoraColors.deep,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Elige cómo deseas que se asigne y recolecte tu material:',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        _ModeOptionCard(
          title: 'Asignación Rápida Automática',
          subtitle: 'Se publica directamente a tarifa estándar oficial. El primer centro de acopio cercano toma la orden y notifica a los recolectores de la zona.',
          badgeText: 'Recomendado',
          badgeColor: LivoraColors.mint,
          badgeTextColor: LivoraColors.forest,
          icon: Icons.bolt_rounded,
          isSelected: selectedMode == 'AUTOMATIC',
          onTap: () => onModeChanged('AUTOMATIC'),
        ),
        const SizedBox(height: 10),
        _ModeOptionCard(
          title: 'Subasta Ecológica Inversa',
          subtitle: 'Ventana de 15 minutos donde los centros de acopio compiten y pujan por tu lote. Tú eliges la mejor cotización recibida.',
          badgeText: 'Mayor Ganancia',
          badgeColor: const Color(0xFFFEF3C7),
          badgeTextColor: const Color(0xFFB45309),
          icon: Icons.gavel_rounded,
          isSelected: selectedMode == 'AUCTION',
          onTap: () => onModeChanged('AUCTION'),
        ),
      ],
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final Color badgeTextColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? LivoraColors.forest : Colors.grey.shade300;
    final bgColor = isSelected ? LivoraColors.mint.withValues(alpha: 0.12) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: LivoraColors.forest.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? LivoraColors.forest
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? LivoraColors.forest : LivoraColors.deep,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Radio<bool>(
                value: true,
                groupValue: isSelected,
                activeColor: LivoraColors.forest,
                onChanged: (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
