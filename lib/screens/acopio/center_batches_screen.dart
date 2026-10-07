import 'package:flutter/material.dart';
import '../../features/acopio/batches/views/center_batches_view.dart';

/// Lotes destinados al centro de acopio: recepción, pesaje y consolidación.
/// Delega de forma transparente en la arquitectura desacoplada [CenterBatchesView] (Clean Architecture MVVM).
class CenterBatchesScreen extends StatelessWidget {
  const CenterBatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CenterBatchesView();
  }
}
