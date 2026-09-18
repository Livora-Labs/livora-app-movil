import 'package:flutter/foundation.dart';

class EnvConfig {
  static const String _envUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    return kReleaseMode
        ? 'https://api.grupolivoralabs.com'
        : 'http://10.0.2.2:3000';
  }

  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
}
