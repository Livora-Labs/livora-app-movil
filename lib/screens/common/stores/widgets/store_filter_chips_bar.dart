import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Barra horizontal de chips de filtrado para categorías de tiendas aliadas.
class StoreFilterChipsBar extends StatelessWidget {
  const StoreFilterChipsBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = selectedCategory == cat;
          return ChoiceChip(
            label: Text(cat),
            selected: selected,
            selectedColor: LivoraColors.forest,
            backgroundColor: LivoraColors.paper,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : LivoraColors.deep,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: selected ? LivoraColors.forest : LivoraColors.border,
              ),
            ),
            onSelected: (val) {
              if (val) onSelected(cat);
            },
          );
        },
      ),
    );
  }
}
