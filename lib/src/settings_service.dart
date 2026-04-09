import 'config.dart';
import 'database.dart';
import 'mattermost_client.dart';

class AppSettings {
  AppSettings({
    required this.appTitle,
    required this.deliveryMode,
    required this.mattermostBaseUrl,
    required this.mattermostToken,
    required this.mattermostTeamId,
    required this.mattermostTeamName,
    required this.defaultChannels,
    required this.n8nBaseUrl,
    required this.n8nWebhookUrl,
    required this.n8nApiKey,
    required this.n8nWebhookSecret,
    required this.n8nInboundSecret,
    required this.publicBaseUrl,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.smtpFromEmail,
    required this.smtpFromName,
    required this.smtpUseSsl,
    required this.authMode,
    required this.keycloakIssuerUrl,
    required this.keycloakClientId,
    required this.keycloakClientSecret,
    required this.keycloakScopes,
    required this.keycloakAdminRole,
  });

  final String appTitle;
  final String deliveryMode;
  final String mattermostBaseUrl;
  final String mattermostToken;
  final String mattermostTeamId;
  final String mattermostTeamName;
  final List<String> defaultChannels;
  final String n8nBaseUrl;
  final String n8nWebhookUrl;
  final String n8nApiKey;
  final String n8nWebhookSecret;
  final String n8nInboundSecret;
  final String publicBaseUrl;
  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpPassword;
  final String smtpFromEmail;
  final String smtpFromName;
  final bool smtpUseSsl;
  final String authMode;
  final String keycloakIssuerUrl;
  final String keycloakClientId;
  final String keycloakClientSecret;
  final String keycloakScopes;
  final String keycloakAdminRole;

  bool get isMattermostConfigured =>
      mattermostBaseUrl.isNotEmpty && mattermostToken.isNotEmpty;
  bool get isN8nConfigured => n8nWebhookUrl.isNotEmpty;
  bool get isN8nInboundConfigured => n8nInboundSecret.isNotEmpty;
  bool get isEmailConfigured =>
      smtpHost.isNotEmpty &&
      smtpPort > 0 &&
      smtpUsername.isNotEmpty &&
      smtpPassword.isNotEmpty &&
      smtpFromEmail.isNotEmpty &&
      publicBaseUrl.isNotEmpty;
  bool get isLocalAuthEnabled => authMode == 'local' || authMode == 'hybrid';
  bool get isKeycloakAuthEnabled =>
      (authMode == 'keycloak' || authMode == 'hybrid') && isKeycloakConfigured;
  bool get isKeycloakConfigured =>
      keycloakIssuerUrl.isNotEmpty &&
      keycloakClientId.isNotEmpty &&
      keycloakClientSecret.isNotEmpty &&
      publicBaseUrl.isNotEmpty;

  Map<String, Object?> toPublicJson() => {
    'appTitle': appTitle,
    'deliveryMode': deliveryMode,
    'defaultChannels': defaultChannels,
    'auth': {
      'mode': authMode,
      'localEnabled': isLocalAuthEnabled,
      'keycloakEnabled': isKeycloakAuthEnabled,
    },
    'integrations': {
      'mattermostConfigured': isMattermostConfigured,
      'n8nConfigured': isN8nConfigured,
      'n8nInboundConfigured': isN8nInboundConfigured,
      'emailConfigured': isEmailConfigured,
    },
  };

  Map<String, Object?> toAdminJson() => {
    ...toPublicJson(),
    'mattermostBaseUrl': mattermostBaseUrl,
    'mattermostToken': mattermostToken,
    'mattermostTeamId': mattermostTeamId,
    'mattermostTeamName': mattermostTeamName,
    'n8nBaseUrl': n8nBaseUrl,
    'n8nWebhookUrl': n8nWebhookUrl,
    'n8nApiKey': n8nApiKey,
    'n8nWebhookSecret': n8nWebhookSecret,
    'n8nInboundSecret': n8nInboundSecret,
    'publicBaseUrl': publicBaseUrl,
    'smtpHost': smtpHost,
    'smtpPort': smtpPort,
    'smtpUsername': smtpUsername,
    'smtpPassword': smtpPassword,
    'smtpFromEmail': smtpFromEmail,
    'smtpFromName': smtpFromName,
    'smtpUseSsl': smtpUseSsl,
    'authMode': authMode,
    'keycloakIssuerUrl': keycloakIssuerUrl,
    'keycloakClientId': keycloakClientId,
    'keycloakClientSecret': keycloakClientSecret,
    'keycloakScopes': keycloakScopes,
    'keycloakAdminRole': keycloakAdminRole,
  };
}

class SettingsService {
  SettingsService({required AppDatabase database, required AppConfig config})
    : _database = database,
      _config = config;

  final AppDatabase _database;
  final AppConfig _config;

  AppSettings load() {
    final stored = _database.getSettings();

    String getValue(String key, String? fallback) {
      final storedValue = stored[key];
      if (storedValue != null) {
        return storedValue;
      }
      return fallback ?? '';
    }

    final rawChannels = getValue(
      'mattermost.defaultChannels',
      _config.defaultChannels.join(','),
    );

    return AppSettings(
      appTitle: getValue('app.title', _config.defaultAppTitle),
      deliveryMode: getValue('delivery.mode', _config.defaultDeliveryMode),
      mattermostBaseUrl: getValue(
        'mattermost.baseUrl',
        _config.defaultMattermostBaseUrl,
      ),
      mattermostToken: getValue(
        'mattermost.token',
        _config.defaultMattermostToken,
      ),
      mattermostTeamId: getValue(
        'mattermost.teamId',
        _config.defaultMattermostTeamId,
      ),
      mattermostTeamName: getValue(
        'mattermost.teamName',
        _config.defaultMattermostTeamName,
      ),
      defaultChannels: rawChannels
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      n8nBaseUrl: getValue('n8n.baseUrl', _config.defaultN8nBaseUrl),
      n8nWebhookUrl: getValue('n8n.webhookUrl', _config.defaultN8nWebhookUrl),
      n8nApiKey: getValue('n8n.apiKey', _config.defaultN8nApiKey),
      n8nWebhookSecret: getValue(
        'n8n.webhookSecret',
        _config.defaultN8nWebhookSecret,
      ),
      n8nInboundSecret: getValue(
        'n8n.inboundSecret',
        _config.defaultN8nInboundSecret,
      ),
      publicBaseUrl: getValue('app.baseUrl', _config.defaultPublicBaseUrl),
      smtpHost: getValue('smtp.host', _config.defaultSmtpHost),
      smtpPort:
          int.tryParse(getValue('smtp.port', '${_config.defaultSmtpPort}')) ??
          _config.defaultSmtpPort,
      smtpUsername: getValue('smtp.username', _config.defaultSmtpUsername),
      smtpPassword: getValue('smtp.password', _config.defaultSmtpPassword),
      smtpFromEmail: getValue('smtp.fromEmail', _config.defaultSmtpFromEmail),
      smtpFromName: getValue('smtp.fromName', _config.defaultSmtpFromName),
      smtpUseSsl:
          getValue(
            'smtp.useSsl',
            _config.defaultSmtpUseSsl ? 'true' : 'false',
          ).toLowerCase() ==
          'true',
      authMode: getValue('auth.mode', _config.defaultAuthMode),
      keycloakIssuerUrl: getValue(
        'keycloak.issuerUrl',
        _config.defaultKeycloakIssuerUrl,
      ),
      keycloakClientId: getValue(
        'keycloak.clientId',
        _config.defaultKeycloakClientId,
      ),
      keycloakClientSecret: getValue(
        'keycloak.clientSecret',
        _config.defaultKeycloakClientSecret,
      ),
      keycloakScopes: getValue(
        'keycloak.scopes',
        _config.defaultKeycloakScopes,
      ),
      keycloakAdminRole: getValue(
        'keycloak.adminRole',
        _config.defaultKeycloakAdminRole,
      ),
    );
  }

  void updateFromPayload(Map<String, Object?> payload) {
    final defaultChannels =
        ((payload['defaultChannels'] as List<dynamic>?) ?? const [])
            .map((item) => item.toString().trim().replaceFirst('#', ''))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);

    _database.upsertSettings({
      'app.title': (payload['appTitle'] as String? ?? '').trim(),
      'delivery.mode': (payload['deliveryMode'] as String? ?? '').trim(),
      'mattermost.baseUrl': (payload['mattermostBaseUrl'] as String? ?? '')
          .trim(),
      'mattermost.token': (payload['mattermostToken'] as String? ?? '').trim(),
      'mattermost.teamId': (payload['mattermostTeamId'] as String? ?? '')
          .trim(),
      'mattermost.teamName': (payload['mattermostTeamName'] as String? ?? '')
          .trim(),
      'mattermost.defaultChannels': defaultChannels.join(','),
      'n8n.baseUrl': (payload['n8nBaseUrl'] as String? ?? '').trim(),
      'n8n.webhookUrl': (payload['n8nWebhookUrl'] as String? ?? '').trim(),
      'n8n.apiKey': (payload['n8nApiKey'] as String? ?? '').trim(),
      'n8n.webhookSecret': (payload['n8nWebhookSecret'] as String? ?? '')
          .trim(),
      'n8n.inboundSecret': (payload['n8nInboundSecret'] as String? ?? '').trim(),
      'app.baseUrl': (payload['publicBaseUrl'] as String? ?? '').trim(),
      'smtp.host': (payload['smtpHost'] as String? ?? '').trim(),
      'smtp.port': (payload['smtpPort'] as String? ?? '').trim(),
      'smtp.username': (payload['smtpUsername'] as String? ?? '').trim(),
      'smtp.password': (payload['smtpPassword'] as String? ?? '').trim(),
      'smtp.fromEmail': (payload['smtpFromEmail'] as String? ?? '').trim(),
      'smtp.fromName': (payload['smtpFromName'] as String? ?? '').trim(),
      'smtp.useSsl': payload['smtpUseSsl'] == true ? 'true' : 'false',
      'auth.mode': (payload['authMode'] as String? ?? '').trim(),
      'keycloak.issuerUrl': (payload['keycloakIssuerUrl'] as String? ?? '')
          .trim(),
      'keycloak.clientId': (payload['keycloakClientId'] as String? ?? '')
          .trim(),
      'keycloak.clientSecret':
          (payload['keycloakClientSecret'] as String? ?? '').trim(),
      'keycloak.scopes': (payload['keycloakScopes'] as String? ?? '').trim(),
      'keycloak.adminRole': (payload['keycloakAdminRole'] as String? ?? '')
          .trim(),
    });
  }

  MattermostClient buildMattermostClient(AppSettings settings) {
    return MattermostClient(
      baseUrl: settings.mattermostBaseUrl,
      token: settings.mattermostToken,
      teamId: settings.mattermostTeamId.isEmpty
          ? null
          : settings.mattermostTeamId,
      teamName: settings.mattermostTeamName.isEmpty
          ? null
          : settings.mattermostTeamName,
      configuredChannels: settings.defaultChannels,
    );
  }
}
