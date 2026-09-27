class EnvConfig {
  static const String _envUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    return 'https://api.grupolivoralabs.com';
  }

  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Clave oficial de CARTO Basemaps para estilo Voyager limpio y minimalista
  static const String cartoBasemapsKey = String.fromEnvironment(
    'CARTO_BASEMAPS_KEY',
    defaultValue: 'cb1_3ydr_1_73283c5655b47dc14e17a1d9',
  );

  /// Dominio web y documentos legales oficiales bajo Ley N.° 29733 e Indecopi
  static const String webBaseUrl = 'https://grupolivoralabs.com';
  static String get termsUrl => '$webBaseUrl/terminos';
  static String get privacyUrl => '$webBaseUrl/privacidad';
  static String get claimsBookUrl => '$webBaseUrl/libro-de-reclamaciones';
}
