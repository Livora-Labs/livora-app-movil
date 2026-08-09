# Livora — App móvil

App Flutter de la plataforma de reciclaje trazable **Livora**. Da acceso a los
cuatro perfiles de la red: **Hogar**, **Recolector**, **Centro de Acopio** y
**Tienda (Almacén)**, con billetera de EcoTokens (Arbitrum Sepolia),
notificaciones y flujo completo de trazabilidad: solicitud → recolección →
lote → pesaje → consolidación → venta B2B.

## Ejecutar

```bash
flutter pub get
flutter run
```

La app apunta por defecto a la API de producción. Para usar otro servidor
(local o Render), tócale el engranaje ⚙️ en la pantalla de inicio de sesión:

- Emulador Android: `http://10.0.2.2:3000`
- iOS / macOS: `http://localhost:3000`

## Generar APK

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

## Estructura

- `lib/core/` — tema (paleta de marca), cliente HTTP, sesión, formatos
- `lib/services/livora_api.dart` — endpoints tipados del backend NestJS
- `lib/screens/` — módulos por rol (`hogar/`, `recolector/`, `acopio/`, `tienda/`) y pantallas comunes (billetera, notificaciones, perfil)
- `assets/images/livora_icon.svg` — ícono oficial de la marca

Backend: [Livora-api-service](https://github.com/Livora-Labs/Livora-api-service)
