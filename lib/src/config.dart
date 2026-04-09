import 'dart:io';

class AppConfig {
  AppConfig({
    required this.port,
    required this.databaseDriver,
    required this.databasePath,
    required this.databaseUrl,
    required this.bootstrapAdminUsername,
    required this.bootstrapAdminDisplayName,
    required this.bootstrapAdminPassword,
    required this.bootstrapAdminPasswordHash,
    required this.forceBootstrapAdminPasswordSync,
    required this.sessionTtl,
    required this.secureCookies,
    required this.defaultAppTitle,
    required this.defaultDeliveryMode,
    required this.defaultMattermostBaseUrl,
    required this.defaultMattermostToken,
    required this.defaultMattermostTeamId,
    required this.defaultMattermostTeamName,
    required this.defaultChannels,
    required this.defaultN8nBaseUrl,
    required this.defaultN8nWebhookUrl,
    required this.defaultN8nApiKey,
    required this.defaultN8nWebhookSecret,
    required this.defaultN8nInboundSecret,
    required this.bootstrapAdminEmail,
    required this.defaultPublicBaseUrl,
    required this.defaultSmtpHost,
    required this.defaultSmtpPort,
    required this.defaultSmtpUsername,
    required this.defaultSmtpPassword,
    required this.defaultSmtpFromEmail,
    required this.defaultSmtpFromName,
    required this.defaultSmtpUseSsl,
    required this.defaultAuthMode,
    required this.defaultKeycloakIssuerUrl,
    required this.defaultKeycloakClientId,
    required this.defaultKeycloakClientSecret,
    required this.defaultKeycloakScopes,
    required this.defaultKeycloakAdminRole,
    required this.webRoot,
  });

  final int port;
  final String databaseDriver;
  final String databasePath;
  final String? databaseUrl;
  final String bootstrapAdminUsername;
  final String bootstrapAdminDisplayName;
  final String? bootstrapAdminPassword;
  final String? bootstrapAdminPasswordHash;
  final bool forceBootstrapAdminPasswordSync;
  final Duration sessionTtl;
  final bool secureCookies;
  final String defaultAppTitle;
  final String defaultDeliveryMode;
  final String? defaultMattermostBaseUrl;
  final String? defaultMattermostToken;
  final String? defaultMattermostTeamId;
  final String? defaultMattermostTeamName;
  final List<String> defaultChannels;
  final String? defaultN8nBaseUrl;
  final String? defaultN8nWebhookUrl;
  final String? defaultN8nApiKey;
  final String? defaultN8nWebhookSecret;
  final String? defaultN8nInboundSecret;
  final String? bootstrapAdminEmail;
  final String? defaultPublicBaseUrl;
  final String? defaultSmtpHost;
  final int defaultSmtpPort;
  final String? defaultSmtpUsername;
  final String? defaultSmtpPassword;
  final String? defaultSmtpFromEmail;
  final String? defaultSmtpFromName;
  final bool defaultSmtpUseSsl;
  final String defaultAuthMode;
  final String? defaultKeycloakIssuerUrl;
  final String? defaultKeycloakClientId;
  final String? defaultKeycloakClientSecret;
  final String defaultKeycloakScopes;
  final String defaultKeycloakAdminRole;
  final String webRoot;

  static AppConfig fromEnvironment() {
    final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
    final databaseDriver =
        _nullableEnv('DATABASE_DRIVER')?.toLowerCase() ?? 'sqlite';
    final databasePath =
        Platform.environment['DATABASE_PATH'] ?? '/data/cannonball.db';
    final databaseUrl = _nullableEnv('DATABASE_URL');
    final webRoot = _nullableEnv('APP_WEB_ROOT') ?? 'web';
    final bootstrapAdminUsername =
        Platform.environment['APP_USERNAME']?.trim().isNotEmpty == true
        ? Platform.environment['APP_USERNAME']!.trim()
        : 'admin';
    final bootstrapAdminDisplayName =
        Platform.environment['APP_ADMIN_DISPLAY_NAME']?.trim().isNotEmpty ==
            true
        ? Platform.environment['APP_ADMIN_DISPLAY_NAME']!.trim()
        : 'System Administrator';
    final bootstrapAdminPassword = _nullableEnv('APP_PASSWORD');
    final bootstrapAdminPasswordHash = _nullableEnv('APP_PASSWORD_HASH');
    if (bootstrapAdminPassword == null && bootstrapAdminPasswordHash == null) {
      throw StateError('APP_PASSWORD or APP_PASSWORD_HASH must be provided.');
    }

    final sessionHours =
        int.tryParse(Platform.environment['SESSION_TTL_HOURS'] ?? '') ?? 12;
    final allowInsecure =
        (Platform.environment['ALLOW_INSECURE_COOKIE'] ?? 'false')
            .toLowerCase() ==
        'true';
    final forceBootstrapAdminPasswordSync =
        (Platform.environment['APP_FORCE_BOOTSTRAP_PASSWORD_SYNC'] ?? 'false')
            .toLowerCase() ==
        'true';

    return AppConfig(
      port: port,
      databaseDriver: databaseDriver,
      databasePath: databasePath,
      databaseUrl: databaseUrl,
      bootstrapAdminUsername: bootstrapAdminUsername,
      bootstrapAdminDisplayName: bootstrapAdminDisplayName,
      bootstrapAdminPassword: bootstrapAdminPassword,
      bootstrapAdminPasswordHash: bootstrapAdminPasswordHash,
      forceBootstrapAdminPasswordSync: forceBootstrapAdminPasswordSync,
      sessionTtl: Duration(hours: sessionHours),
      secureCookies: !allowInsecure,
      defaultAppTitle: _nullableEnv('APP_TITLE') ?? 'cannonball',
      defaultDeliveryMode: _nullableEnv('DELIVERY_MODE') ?? 'mattermost',
      defaultMattermostBaseUrl: _nullableEnv('MATTERMOST_BASE_URL'),
      defaultMattermostToken: _nullableEnv('MATTERMOST_TOKEN'),
      defaultMattermostTeamId: _nullableEnv('MATTERMOST_TEAM_ID'),
      defaultMattermostTeamName: _nullableEnv('MATTERMOST_TEAM_NAME'),
      defaultChannels: (_nullableEnv('MATTERMOST_CHANNELS') ?? '')
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      defaultN8nBaseUrl: _nullableEnv('N8N_BASE_URL'),
      defaultN8nWebhookUrl: _nullableEnv('N8N_WEBHOOK_URL'),
      defaultN8nApiKey: _nullableEnv('N8N_API_KEY'),
      defaultN8nWebhookSecret: _nullableEnv('N8N_WEBHOOK_SECRET'),
      defaultN8nInboundSecret: _nullableEnv('N8N_INBOUND_SECRET'),
      bootstrapAdminEmail: _nullableEnv('APP_ADMIN_EMAIL'),
      defaultPublicBaseUrl: _nullableEnv('APP_BASE_URL'),
      defaultSmtpHost: _nullableEnv('SMTP_HOST'),
      defaultSmtpPort:
          int.tryParse(Platform.environment['SMTP_PORT'] ?? '') ?? 587,
      defaultSmtpUsername: _nullableEnv('SMTP_USERNAME'),
      defaultSmtpPassword: _nullableEnv('SMTP_PASSWORD'),
      defaultSmtpFromEmail: _nullableEnv('SMTP_FROM_EMAIL'),
      defaultSmtpFromName: _nullableEnv('SMTP_FROM_NAME'),
      defaultSmtpUseSsl:
          (Platform.environment['SMTP_USE_SSL'] ?? 'false').toLowerCase() ==
          'true',
      defaultAuthMode: _nullableEnv('AUTH_MODE') ?? 'local',
      defaultKeycloakIssuerUrl: _nullableEnv('KEYCLOAK_ISSUER_URL'),
      defaultKeycloakClientId: _nullableEnv('KEYCLOAK_CLIENT_ID'),
      defaultKeycloakClientSecret: _nullableEnv('KEYCLOAK_CLIENT_SECRET'),
      defaultKeycloakScopes:
          _nullableEnv('KEYCLOAK_SCOPES') ?? 'openid profile email',
      defaultKeycloakAdminRole:
          _nullableEnv('KEYCLOAK_ADMIN_ROLE') ?? 'cannonball-admin',
      webRoot: webRoot,
    );
  }

  static String? _nullableEnv(String key) {
    final value = Platform.environment[key]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
