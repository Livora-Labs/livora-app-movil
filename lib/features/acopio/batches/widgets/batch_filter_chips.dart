import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

const _filters = <String?, String>{
  null: 'Todos',
  'IN_TRANSIT': 'En tránsito',
  'FLAGGED_FOR_REVIEW': 'Observados',
  'DISPUTED': 'En disputa',
  'PROCESSING': 'Procesando',
  'RECEIVED': 'Recibidos',
  'CONSOLIDATED': 'Consolidados',
};

/// Micro-widget para la barra de chips de filtro de estado de lotes.
class BatchFilterChips extends StatelessWidget {
  const BatchFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final String? selectedFilter;
  final ValueChanged<String?> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.entries.map((entry) {
          final isSelected = selectedFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(entry.value),
              selectedColor: LivoraColors.mint.withValues(alpha: 0.25),
              checkmarkColor: LivoraColors.forest,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? LivoraColors.forest : Colors.black87,
                fontSize: 13,
              ),
              onSelected: (_) => onFilterSelected(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}
