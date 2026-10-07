import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/session.dart';
import '../../../../core/stellar.dart';
import '../../../../models/models.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../services/livora_api.dart';
import '../../../../widgets/common.dart';
import '../../../../screens/common/complaints_screen.dart';
import '../../../../screens/hogar/hogar_kyc_screen.dart';
import '../../../../screens/hogar/widgets/hogar_active_address_bar.dart';
import '../view_model/profile_view_model.dart';
import '../views/edit_profile_screen.dart';
import '../widgets/profile_account_danger_zone.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/profile_password_dialog.dart';

/// Vista de Perfil de Usuario rediseñada: experiencia modular y amigable.
/// Evita formularios monolíticos abiertos de golpe y ofrece navegación jerárquica clara.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();

    return ChangeNotifierProvider(
      create: (ctx) => ProfileViewModel(
        repository: ProfileRepository(api: ctx.read<LivoraApi>()),
        initialUser: user,
      ),
      child: const _ProfileViewContent(),
    );
  }
}

class _ProfileViewContent extends StatefulWidget {
  const _ProfileViewContent();

  @override
  State<_ProfileViewContent> createState() => _ProfileViewContentState();
}

class _ProfileViewContentState extends State<_ProfileViewContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileViewModel>().reloadProfile().then((_) {
          if (mounted) {
            final freshUser = context.read<ProfileViewModel>().user;
            context.read<SessionController>().updateUser(freshUser);
          }
        });
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Estás seguro de que deseas salir de tu cuenta?',
      confirmLabel: 'Sí, salir',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      await context.read<SessionController>().logout();
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Eliminar cuenta',
      message: 'Esta acción es irreversible y eliminará todos tus datos. ¿Deseas continuar?',
      confirmLabel: 'Continuar',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final passController = TextEditingController();
    final passConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirma tu contraseña'),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Contraseña actual'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LivoraColors.coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (passConfirmed == true && mounted) {
      final vm = context.read<ProfileViewModel>();
      final ok = await vm.deleteAccount(password: passController.text);
      if (ok && mounted) {
        await context.read<SessionController>().logout();
      } else if (mounted) {
        showAppSnack(context, vm.feedbackMessage ?? 'Error eliminando cuenta', error: true);
      }
    }
  }

  Future<void> _handleEditAddress(AuthUser user) async {
    final api = context.read<LivoraApi>();
    final session = context.read<SessionController>();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddressSelectorBottomSheet(user: user),
    );
    if (result == null || !mounted) return;
    final newAddress = result['address'] as String?;
    final newLat = result['latitude'] as double?;
    final newLng = result['longitude'] as double?;
    if (newAddress != null && newAddress.trim().isNotEmpty) {
      try {
        await api.updateProfile(
          address: newAddress.trim(),
          latitude: newLat,
          longitude: newLng,
        );
        if (session.user != null) {
          await session.updateUser(
            session.user!.copyWith(
              address: newAddress.trim(),
              latitude: newLat,
              longitude: newLng,
            ),
          );
        }
        if (mounted) {
          showAppSnack(context, 'Dirección domiciliaria actualizada: $newAddress');
        }
      } catch (e) {
        if (mounted) {
          showAppSnack(context, 'Error al actualizar dirección: $e', error: true);
        }
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: LivoraColors.forest,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: (iconColor ?? LivoraColors.forest).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? LivoraColors.forest, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final user = vm.user;

    return Scaffold(
      backgroundColor: LivoraColors.paper,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
        children: [
          ProfileHeaderCard(
            user: user,
            onEditProfile: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(viewModel: vm),
                ),
              );
              if (updated == true && mounted) {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 16),

          // Sección Identidad & Documentación Civil (KYC)
          _buildSectionCard(
            title: 'IDENTIDAD Y VERIFICACIÓN (LEY N.° 29733)',
            children: [
              _buildActionTile(
                icon: user.kycStatus == KycStatus.approved
                    ? Icons.verified_user_rounded
                    : Icons.badge_outlined,
                iconColor: user.kycStatus == KycStatus.approved
                    ? LivoraColors.green
                    : user.kycStatus == KycStatus.pending
                        ? const Color(0xFFD97706)
                        : LivoraColors.slate,
                title: user.dniDocumentNumber != null && user.dniDocumentNumber!.isNotEmpty
                    ? 'Documento DNI: ${user.dniDocumentNumber}'
                    : 'Documento Nacional de Identidad',
                subtitle: switch (user.kycStatus) {
                  KycStatus.approved => 'Validado formalmente ante la ANPD y Livora',
                  KycStatus.pending => 'Documentos en revisión por el equipo técnico',
                  KycStatus.rejected => 'Documentación observada (Toca para regularizar)',
                  _ => 'Sin verificar (Toca para habilitar mayores límites)',
                },
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: switch (user.kycStatus) {
                      KycStatus.approved => LivoraColors.green.withValues(alpha: 0.15),
                      KycStatus.pending => const Color(0xFFFEF3C7),
                      KycStatus.rejected => const Color(0xFFFEE2E2),
                      _ => Colors.grey.shade100,
                    },
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    switch (user.kycStatus) {
                      KycStatus.approved => 'APROBADO',
                      KycStatus.pending => 'EN REVISIÓN',
                      KycStatus.rejected => 'OBSERVADO',
                      _ => 'PENDIENTE',
                    },
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: switch (user.kycStatus) {
                        KycStatus.approved => LivoraColors.green,
                        KycStatus.pending => const Color(0xFFD97706),
                        KycStatus.rejected => const Color(0xFFDC2626),
                        _ => Colors.grey.shade700,
                      },
                    ),
                  ),
                ),
                onTap: () {
                  if (user.kycStatus != KycStatus.approved) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HogarKycScreen()),
                    );
                  } else {
                    showAppSnack(context, 'Tu identidad ya fue validada con éxito.');
                  }
                },
              ),
              if (user.address != null && user.address!.isNotEmpty) ...[
                const Divider(height: 1, indent: 60),
                _buildActionTile(
                  icon: Icons.location_on_outlined,
                  title: 'Dirección Domiciliaria Principal',
                  subtitle: user.address!,
                  onTap: () => _handleEditAddress(user),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Sección Billetera Web3 & Stellar
          if (user.walletAddress != null)
            _buildSectionCard(
              title: 'BILLETERA BLOCKCHAIN STELLAR',
              children: [
                _buildActionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Clave Pública Stellar',
                  subtitle: '${user.walletAddress!.substring(0, 8)}...${user.walletAddress!.substring(user.walletAddress!.length - 8)}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Copiar dirección',
                        icon: const Icon(Icons.copy_rounded, size: 18, color: LivoraColors.forest),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: user.walletAddress!));
                          showAppSnack(context, 'Dirección copiada al portapapeles');
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Ver en Stellar Expert',
                        icon: const Icon(Icons.open_in_new_rounded, size: 18, color: LivoraColors.forest),
                        onPressed: () {
                          Stellar.openAccountInExplorer(user.walletAddress);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Sección Legal y Transparencia Indecopi
          _buildSectionCard(
            title: 'TRANSPARENCIA Y ATENCIÓN AL CIUDADANO',
            children: [
              _buildActionTile(
                icon: Icons.menu_book_rounded,
                title: 'Libro de Reclamaciones Virtual',
                subtitle: 'Formulario oficial Indecopi (Ley N.° 29571 / 32495)',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 60),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                secondary: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign_outlined, color: Colors.blue, size: 20),
                ),
                title: const Text('Comunicaciones y Novedades', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Promociones ecológicas y tiendas aliadas', style: TextStyle(fontSize: 12)),
                value: user.marketingAccepted,
                onChanged: (val) {
                  vm.setMarketingConsent(val);
                  context.read<SessionController>().updateUser(user.copyWith(marketingAccepted: val));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Seguridad y Cierre de Sesión
          ProfileAccountDangerZone(
            onChangePassword: () => ProfilePasswordDialog.show(
              context,
              (curr, next) => vm.changePassword(currentPassword: curr, newPassword: next),
            ),
            onLogout: _handleLogout,
            onDeleteAccount: _handleDeleteAccount,
          ),
        ],
      ),
    );
  }
}
