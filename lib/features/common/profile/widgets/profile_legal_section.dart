import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/legal_texts.dart';
import '../../../../screens/common/complaints_screen.dart';

/// Micro-widget para la sección de cumplimiento normativo (Indecopi y ANPD Perú).
class ProfileLegalSection extends StatelessWidget {
  const ProfileLegalSection({
    super.key,
    required this.marketingAccepted,
    required this.onMarketingChanged,
  });

  final bool marketingAccepted;
  final ValueChanged<bool> onMarketingChanged;

  void _showLegalSheet(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cumplimiento y Privacidad',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Comunicaciones comerciales y promociones',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Autorizo recibir beneficios y descuentos de comercios aliados (Ley 29733).',
              style: TextStyle(fontSize: 11.5),
            ),
            value: marketingAccepted,
            activeColor: LivoraColors.forest,
            onChanged: onMarketingChanged,
          ),
          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, color: LivoraColors.forest),
            title: const Text('Términos y Condiciones de Uso', style: TextStyle(fontSize: 13.5)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showLegalSheet(context, 'Términos y Condiciones', LegalTexts.termsAndConditions),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined, color: LivoraColors.forest),
            title: const Text('Política de Privacidad de Datos', style: TextStyle(fontSize: 13.5)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showLegalSheet(context, 'Política de Privacidad', LegalTexts.privacyPolicy),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_rounded, color: Color(0xFFD97706)),
            title: const Text(
              'Libro de Reclamaciones Virtual',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Conforme a la Ley N° 29571 e Indecopi', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
