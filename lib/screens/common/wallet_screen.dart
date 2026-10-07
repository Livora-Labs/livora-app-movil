import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../features/common/wallet/view_model/wallet_view_model.dart';
import '../../features/common/wallet/views/wallet_view.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';

/// Contenedor de Billetera LIVOs y Web3 refactorizado a Clean Architecture MVVM.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => WalletViewModel(
        repository: WalletRepository(
          ctx.read<LivoraApi>(),
          ctx.read<SessionController>(),
        ),
        realtime: ctx.read<LivoraRealtime>(),
      ),
      child: const WalletView(),
    );
  }
}
