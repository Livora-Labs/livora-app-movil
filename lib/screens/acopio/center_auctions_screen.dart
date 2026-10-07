import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session.dart';
import '../../data/repositories/auctions_repository.dart';
import '../../features/acopio/auctions/view_model/auctions_view_model.dart';
import '../../features/acopio/auctions/views/auctions_view.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';

/// Pantalla de visualización y postulación de subastas para CENTRO_ACOPIO (Clean Architecture MVVM).
class CenterAuctionsScreen extends StatelessWidget {
  const CenterAuctionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AuctionsViewModel(
        repository: AuctionsRepository(ctx.read<LivoraApi>()),
        centerId: ctx.read<SessionController>().user?.id,
        realtime: ctx.read<LivoraRealtime>(),
      ),
      child: const AuctionsView(),
    );
  }
}
