import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';

enum MapListViewMode { list, map }

/// Selector dual interactivo (Lista / Mapa Radar) basado en SegmentedButton
/// con tokens de diseño de LivoraColors y feedback háptico.
class ViewToggleSegmentedButton extends StatelessWidget {
  const ViewToggleSegmentedButton({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    this.mapLabel = 'Mapa Radar',
    this.listLabel = 'Lista',
  });

  final MapListViewMode selectedMode;
  final ValueChanged<MapListViewMode> onChanged;
  final String mapLabel;
  final String listLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SegmentedButton<MapListViewMode>(
        segments: [
          ButtonSegment<MapListViewMode>(
            value: MapListViewMode.list,
            label: Text(
              listLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
          ),
          ButtonSegment<MapListViewMode>(
            value: MapListViewMode.map,
            label: Text(
              mapLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            icon: const Icon(Icons.map_rounded, size: 18),
          ),
        ],
        selected: {selectedMode},
        onSelectionChanged: (newSelection) {
          HapticFeedback.selectionClick();
          onChanged(newSelection.first);
        },
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: LivoraColors.paper,
          selectedBackgroundColor: LivoraColors.forest,
          selectedForegroundColor: Colors.white,
          foregroundColor: LivoraColors.deep,
          side: const BorderSide(color: LivoraColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
