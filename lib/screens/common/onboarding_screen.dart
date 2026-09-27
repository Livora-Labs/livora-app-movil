import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../services/location_service.dart';

/// Pantalla de bienvenida / Onboarding interactivo para usuarios nuevos.
/// Cumple con los estándares de Google Play y Apple App Store para explicación previa de permisos.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String badge;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingItem> _pages = [
    _OnboardingItem(
      badge: 'PASO 1 · SEPARA EN CASA',
      title: 'Clasifica tus materiales reciclables',
      subtitle:
          'Separa botellas PET, cajas de cartón, latas de aluminio y envases limpios. Cada kilogramo entregado suma a tu impacto ambiental.',
      icon: Icons.recycling_rounded,
      accentColor: LivoraColors.green,
    ),
    _OnboardingItem(
      badge: 'PASO 2 · SERVICIO A DOMICILIO',
      title: 'Recolección y pesaje en tu puerta',
      subtitle:
          'Un recolector certificado acude a tu domicilio, pesa tus materiales con balanza digital y valida la entrega mediante tu PIN de seguridad personal.',
      icon: Icons.delivery_dining_rounded,
      accentColor: LivoraColors.blue,
    ),
    _OnboardingItem(
      badge: 'PASO 3 · BENEFICIOS REALES',
      title: 'Gana recompensas en tokens LIVO',
      subtitle:
          'Recibe LIVOs directamente en tu billetera digital. Canjéalos por productos y descuentos escaneando códigos QR en comercios aliados.',
      icon: Icons.toll_rounded,
      accentColor: LivoraColors.forest,
    ),
  ];

  Future<void> _finishOnboarding() async {
    HapticFeedback.lightImpact();
    // Explicación previa de permisos exigida por App Store y Google Play
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (dlgContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LivoraColors.forest.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: LivoraColors.forest,
              size: 36,
            ),
          ),
          title: const Text(
            'Ubicación para tus recolecciones',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: const Text(
            'Livora necesita acceder a tu ubicación para fijar la dirección de recojo y permitirte seguir al recolector en el mapa en tiempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: LivoraColors.slate),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(dlgContext);
                await LocationService.requestPermission();
              },
              child: const Text('Permitir ubicación'),
            ),
          ],
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: _finishOnboarding,
              child: const Text(
                'Saltar',
                style: TextStyle(
                  color: LivoraColors.slate,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ilustración / Icono Central
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: item.accentColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: item.accentColor.withValues(alpha: 0.25),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            item.icon,
                            size: 68,
                            color: item.accentColor,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Badge superior
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: item.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: item.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Título
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: LivoraColors.deep,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Subtítulo
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: LivoraColors.ink.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicadores de página (Dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final active = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? LivoraColors.forest : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Botón de avance
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LivoraColors.deep,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: isLastPage
                      ? _finishOnboarding
                      : () {
                          HapticFeedback.lightImpact();
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        },
                  child: Text(
                    isLastPage ? '¡Comenzar ahora!' : 'Continuar',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
