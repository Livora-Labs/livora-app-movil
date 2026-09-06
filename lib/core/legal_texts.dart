/// Textos legales oficiales de Livora en cumplimiento de la regulación peruana
/// (Indecopi, Ley N.° 29571 Código de Protección al Consumidor y
/// Ley N.° 29733 Ley de Protección de Datos Personales de la República del Perú).
library;

class LegalTexts {
  LegalTexts._();

  static const String termsAndConditionsTitle = 'Términos y Condiciones de Uso';
  static const String privacyPolicyTitle = 'Política de Privacidad y Tratamiento de Datos';

  static const String termsAndConditions = '''
TÉRMINOS Y CONDICIONES DE USO DE LA PLATAFORMA LIVORA
Versión 2.0.0 (Vigente para la República del Perú)

1. NATURALEZA Y ALCANCE DEL SERVICIO
Livora es una plataforma digital de economía circular operada bajo la legislación peruana. Facilita la conexión entre hogares generadores de residuos aprovechables, recolectores urbanos formalizados, centros de acopio autorizados y comercios aliados de bienes de consumo ecológico y de primera necesidad.

2. MONEDERO WEB3 Y CUSTODIA DE CLAVES PRIVADAS
2.1. Custodia Delegada: Livora crea, administra y custodia las billeteras blockchain en la red descentralizada Stellar/Soroban en nombre de cada usuario registrado. Las claves criptográficas privadas son almacenadas de forma cifrada en servidores seguros (KMS/Vault) bajo un esquema custodial.
2.2. Mandato de Firma Delegada: Al registrarse e interactuar en la plataforma, el usuario otorga a Livora un mandato de delegación irrevocable para firmar transacciones en la blockchain Stellar basadas exclusivamente en las instrucciones explícitas emitidas por el usuario en la interfaz móvil (solicitudes de retiro, recepción de incentivos y canjes QR).
2.3. Límite de Responsabilidad: Livora no se responsabiliza por la pérdida de acceso o fondos derivados del compromiso negligente de las credenciales de autenticación del usuario (contraseña, sesión de dispositivo móvil o correo electrónico).

3. TRANSACCIONES BLOCKCHAIN E IRREVERSIBILIDAD
3.1. Inmutabilidad: Toda transacción validada en la blockchain de Stellar es inmutable y no reversible. Una vez confirmada una transferencia o canje, Livora no puede anular la operación.
3.2. Naturaleza de los Tokens: Los EcoTokens (ECO) constituyen unidades de recompensa e incentivo ecológico interno. No constituyen moneda de curso legal (fiat), valores negociables ni depósitos bancarios garantizados por la SBS, y su canje está limitado exclusivamente al ecosistema de comercios asociados de Livora.
3.3. Asunción de Riesgos Tecnológicos: El usuario asume los riesgos propios de la tecnología blockchain descentralizada, congestión de nodos o fluctuaciones operativas de red.

4. COMERCIO ELECTRÓNICO Y TERCEROS ASOCIADOS
4.1. Rol de Intermediación: Livora opera como intermediario tecnológico en el marketplace de canjes.
4.2. Garantía de Productos: La tienda o comercio aliado seleccionado es el único proveedor directo y responsable ante Indecopi (Ley N.° 29571) por la calidad, idoneidad, inocuidad y entrega efectiva del producto canjeado.

5. JURISDICCIÓN Y LEY APLICABLE
Este acuerdo se rige por las leyes de la República del Perú. Cualquier controversia será sometida a los tribunales competentes de la ciudad de Lima.
''';

  static const String privacyPolicy = '''
POLÍTICA DE PRIVACIDAD Y PROTECCIÓN DE DATOS PERSONALES
Versión 2.0.0 (Ley N.° 29733 de la República del Perú)

1. TITULAR DEL BANCO DE DATOS PERSONALES
En cumplimiento de la Ley N.° 29733 (Ley de Protección de Datos Personales) y su Reglamento (D.S. 003-2013-JUS), se informa que los datos personales recopilados son almacenados en el banco de datos denominado "Usuarios de la Plataforma", de titularidad de la empresa operadora de Livora, registrado ante el Registro Nacional de Protección de Datos Personales de la ANPD.

2. DATOS RECOPILADOS Y FINALIDAD
2.1. Datos Tratados: Nombres, apellidos, documento de identidad (DNI/CE), correo electrónico, número telefónico móvil, dirección domiciliaria, coordenadas geográficas de geolocalización GPS, dirección pública de billetera Stellar y registro histórico de transacciones de reciclaje.
2.2. Finalidades Principales (Necesarias para el servicio):
- Registro y autenticación de usuarios.
- Geolocalización de domicilios para el enrutamiento de recolecciones físicas.
- Trazabilidad y dispersión de saldos de EcoTokens en la blockchain Stellar.
- Emisión de comprobantes y atención del Libro de Reclamaciones.
2.3. Finalidades Opcionales (Publicidad y Promociones):
- Envío de novedades, boletines y promociones de tiendas aliadas. Esta finalidad es estrictamente opcional y puede ser revocada en cualquier momento desde los ajustes de perfil.

3. EJERCICIO DE DERECHOS ARCO (ACCESO, RECTIFICACIÓN, CANCELACIÓN Y OPOSICIÓN)
El titular de los datos personales puede ejercer en cualquier momento sus derechos de Acceso, Rectificación, Cancelación y Oposición previstos en la Ley N.° 29733:
- Canal de Atención: Correo electrónico privacidad@livora.pe o a través del botón "Eliminar cuenta definitivamente" en la sección de seguridad de la aplicación.
- Plazo de Respuesta: Livora atenderá la solicitud en un plazo máximo legal de 10 días hábiles para rectificaciones y cancelaciones, y 20 días para solicitudes de acceso.

4. SEGURIDAD Y TRANSFERENCIA DE DATOS
Livora adopta medidas de seguridad técnicas, organizativas y legales apropiadas para proteger los datos contra accesos no autorizados o pérdidas. No se transfieren datos personales a terceros con fines comerciales ajenos al ecosistema operativo de recolección y canje sin el consentimiento previo y expreso del usuario.
''';
}
