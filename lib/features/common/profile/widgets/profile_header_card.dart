import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';

/// Hero Card mejorado para el perfil con avatar, nombre, correo, rol y botón táctil 'Editar perfil >'.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.user,
    this.onEditProfile,
  });

  final AuthUser user;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final roleName = Roles.label(user.role);
    final initial = (user.name != null && user.name!.trim().isNotEmpty)
        ? user.name!.trim()[0].toUpperCase()
        : user.email.isNotEmpty
            ? user.email[0].toUpperCase()
            : 'U';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                backgroundImage: (user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty)
                    ? NetworkImage(user.profilePhotoUrl!)
                    : null,
                child: (user.profilePhotoUrl == null || user.profilePhotoUrl!.isEmpty)
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.forest,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name ?? 'Vecino Livora',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: LivoraColors.mint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roleName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ),
                        if (user.kycStatus == KycStatus.approved) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: LivoraColors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 12, color: LivoraColors.green),
                                SizedBox(width: 3),
                                Text(
                                  'Verificado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: LivoraColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onEditProfile != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onEditProfile,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 17, color: LivoraColors.forest),
                        SizedBox(width: 8),
                        Text(
                          'Editar datos de perfil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: LivoraColors.forest,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
