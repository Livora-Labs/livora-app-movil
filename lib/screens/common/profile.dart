import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';

import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../core/stellar.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_logo.dart';
import '../auth/login_screen.dart';

/// AppBar estándar de la app con acceso al perfil.
AppBar livoraAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
}) {
  return AppBar(
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LivoraLogo(size: 28),
        const SizedBox(width: 10),
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    ),
    actions: [
      ...?actions,
      const ProfileButton(),
      const SizedBox(width: 6),
    ],
  );
}

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final initial =
        user == null || user.email.isEmpty ? '?' : user.email[0].toUpperCase();
    return IconButton(
      tooltip: 'Mi cuenta',
      onPressed: () => _showProfileSheet(context),
      icon: CircleAvatar(
        radius: 15,
        backgroundColor: LivoraColors.forest,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

Future<void> _showProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final session = sheetContext.watch<SessionController>();
      final user = session.user;
      if (user == null) return const SizedBox.shrink();

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: LivoraColors.forest,
                    child: Icon(Roles.icon(user.role), color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusChip(
                          label: Roles.label(user.role),
                          color: LivoraColors.forest,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _CopyTile(
                label: 'ID de usuario',
                value: user.id,
                hint: user.role == Roles.centroAcopio
                    ? 'Compártelo con los recolectores para que envíen sus lotes a tu centro.'
                    : null,
              ),
              if (user.walletAddress != null)
                _CopyTile(
                  label: 'Billetera (${Stellar.networkLabel})',
                  value: user.walletAddress!,
                  hint: 'Compártela para recibir EcoTokens.',
                  explorerUrl: Stellar.isValidAddress(user.walletAddress)
                      ? Stellar.accountUrl(user.walletAddress!)
                      : null,
                ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => showServerSettingsDialog(sheetContext),
                icon: const Icon(Icons.dns_outlined),
                label: const Text('Configurar servidor'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://livora.org/terminos');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Términos', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://livora.org/privacidad');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                    label: const Text('Privacidad', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8C3A3A),
                ),
                onPressed: () async {
                  final confirmed = await confirmDialog(
                    sheetContext,
                    title: 'Cerrar sesión',
                    message: '¿Deseas salir de tu cuenta de Livora?',
                    confirmLabel: 'Salir',
                  );
                  if (!confirmed || !sheetContext.mounted) return;
                  Navigator.of(sheetContext)
                      .popUntil((route) => route.isFirst);
                  await sheetContext.read<SessionController>().logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8C3A3A),
                ),
                onPressed: () => _confirmDeleteAccount(sheetContext),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Eliminar mi cuenta'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Eliminación de cuenta (GDPR): `DELETE /users/me` anonimiza y borra los
/// datos del usuario en el backend. Es irreversible, por eso pedimos una
/// confirmación explícita antes de llamar.
Future<void> _confirmDeleteAccount(BuildContext context) async {
  final confirmed = await confirmDialog(
    context,
    title: 'Eliminar mi cuenta',
    message:
        'Se borrarán tu perfil, tu billetera y tu historial de reciclaje de '
        'forma permanente. Esta acción no se puede deshacer.\n\n'
        '¿Seguro que deseas continuar?',
    confirmLabel: 'Eliminar',
  );
  if (!confirmed || !context.mounted) return;

  final session = context.read<SessionController>();
  final navigator = Navigator.of(context);
  final messengerContext = navigator.context;
  try {
    await session.deleteAccount();
    navigator.popUntil((route) => route.isFirst);
    if (messengerContext.mounted) {
      showAppSnack(messengerContext, 'Tu cuenta fue eliminada');
    }
  } on ApiException catch (error) {
    if (messengerContext.mounted) {
      showAppSnack(messengerContext, error.message, error: true);
    }
  }
}

class _CopyTile extends StatelessWidget {
  const _CopyTile({
    required this.label,
    required this.value,
    this.hint,
    this.explorerUrl,
  });

  final String label;
  final String value;
  final String? hint;
  final Uri? explorerUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: LivoraColors.paper,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: LivoraColors.ink.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: LivoraColors.deep,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 11,
                        color: LivoraColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  showAppSnack(context, '$label copiado al portapapeles');
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
            if (explorerUrl != null)
              IconButton(
                tooltip: 'Ver en Stellar Expert',
                onPressed: () async {
                  final opened = await Stellar.openInExplorer(explorerUrl!);
                  if (!opened && context.mounted) {
                    showAppSnack(
                      context,
                      'No se pudo abrir Stellar Expert',
                      error: true,
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
