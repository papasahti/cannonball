import 'dart:convert';

import 'config.dart';
import 'database_store.dart';
import 'mattermost_client.dart';

class MattermostBotSettings {
  MattermostBotSettings({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.token,
    required this.teamId,
    required this.teamName,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String token;
  final String teamId;
  final String teamName;

  bool get isConfigured => baseUrl.isNotEmpty && token.isNotEmpty;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'token': token,
    'teamId': teamId,
    'teamName': teamName,
  };

  Map<String, Object?> toPublicJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'teamId': teamId,
    'teamName': teamName,
    'configured': isConfigured,
  };
}

class AppSettings {
  AppSettings({
    required this.appTitle,
    required this.deliveryMode,
    required this.mattermostBots,
    required this.activeMattermostBotId,
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
  final List<MattermostBotSettings> mattermostBots;
  final String activeMattermostBotId;
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

  MattermostBotSettings? get activeMattermostBot {
    if (mattermostBots.isEmpty) {
      return null;
    }
    final byId = mattermostBots.where((item) => item.id == activeMattermostBotId);
    if (byId.isNotEmpty) {
      return byId.first;
    }
    final configured = mattermostBots.where((item) => item.isConfigured);
    if (configured.isNotEmpty) {
      return configured.first;
    }
    return mattermostBots.first;
  }

  bool get isMattermostConfigured =>
      activeMattermostBot?.isConfigured == true;
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
    'mattermostBots': mattermostBots
        .map((item) => item.toPublicJson())
        .toList(growable: false),
    'activeMattermostBotId': activeMattermostBotId,
  };

  Map<String, Object?> toAdminJson() => {
    ...toPublicJson(),
    'mattermostBaseUrl': mattermostBaseUrl,
    'mattermostToken': mattermostToken,
    'mattermostTeamId': mattermostTeamId,
    'mattermostTeamName': mattermostTeamName,
    'mattermostBots': mattermostBots.map((item) => item.toJson()).toList(growable: false),
    'activeMattermostBotId': activeMattermostBotId,
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
  SettingsService({required DatabaseStore database, required AppConfig config})
    : _database = database,
      _config = config;

  final DatabaseStore _database;
  final AppConfig _config;

  Future<Map<String, Object?>> buildUserMattermostAccess({
    required int userId,
    AppSettings? settings,
  }) async {
    final currentSettings = settings ?? await load();
    final stored = await _database.getSettings();
    final allowedBotIds = _decodeStringList(
      stored['user.$userId.mattermost.allowedBots'],
    ).where((id) {
      return currentSettings.mattermostBots.any((bot) => bot.id == id);
    }).toList(growable: false);
    final preferredBotId = (stored['user.$userId.mattermost.preferredBotId'] ?? '')
        .trim();
    final normalizedPreferredBotId = allowedBotIds.contains(preferredBotId)
        ? preferredBotId
        : (allowedBotIds.isNotEmpty ? allowedBotIds.first : '');
    return {
      'allowedBotIds': allowedBotIds,
      'preferredBotId': normalizedPreferredBotId,
    };
  }

  Future<void> saveUserMattermostAccess({
    required int userId,
    required List<String> allowedBotIds,
    required String preferredBotId,
  }) async {
    final settings = await load();
    final validBotIds = allowedBotIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where((id) => settings.mattermostBots.any((bot) => bot.id == id))
        .toSet()
        .toList(growable: false);
    final normalizedPreferredBotId = validBotIds.contains(preferredBotId.trim())
        ? preferredBotId.trim()
        : (validBotIds.isNotEmpty ? validBotIds.first : '');
    await _database.upsertSettings({
      'user.$userId.mattermost.allowedBots': jsonEncode(validBotIds),
      'user.$userId.mattermost.preferredBotId': normalizedPreferredBotId,
    });
  }

  Future<void> clearUserMattermostAccess({required int userId}) async {
    await _database.upsertSettings({
      'user.$userId.mattermost.allowedBots': null,
      'user.$userId.mattermost.preferredBotId': null,
    });
  }

  Future<AppSettings> load() async {
    final stored = await _database.getSettings();

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
    final mattermostBots = _loadMattermostBots(stored);
    final activeMattermostBotId = getValue(
      'mattermost.activeBotId',
      mattermostBots.isNotEmpty ? mattermostBots.first.id : '',
    );
    final activeMattermostBot =
        mattermostBots.where((item) => item.id == activeMattermostBotId).isNotEmpty
        ? mattermostBots.firstWhere((item) => item.id == activeMattermostBotId)
        : (mattermostBots.isNotEmpty ? mattermostBots.first : null);

    return AppSettings(
      appTitle: getValue('app.title', _config.defaultAppTitle),
      deliveryMode: getValue('delivery.mode', _config.defaultDeliveryMode),
      mattermostBots: mattermostBots,
      activeMattermostBotId: activeMattermostBotId,
      mattermostBaseUrl: activeMattermostBot?.baseUrl ?? '',
      mattermostToken: activeMattermostBot?.token ?? '',
      mattermostTeamId: activeMattermostBot?.teamId ?? '',
      mattermostTeamName: activeMattermostBot?.teamName ?? '',
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

  Future<void> updateFromPayload(Map<String, Object?> payload) async {
    final defaultChannels =
        ((payload['defaultChannels'] as List<dynamic>?) ?? const [])
            .map((item) => item.toString().trim().replaceFirst('#', ''))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);

    final mattermostBots = _normalizeMattermostBots(payload['mattermostBots']);
    final activeMattermostBotId =
        (payload['activeMattermostBotId'] as String? ?? '').trim();
    final normalizedActiveMattermostBotId = mattermostBots.where(
      (item) => item.id == activeMattermostBotId,
    ).isNotEmpty
        ? activeMattermostBotId
        : (mattermostBots.isNotEmpty ? mattermostBots.first.id : '');

    await _database.upsertSettings({
      'app.title': (payload['appTitle'] as String? ?? '').trim(),
      'delivery.mode': (payload['deliveryMode'] as String? ?? '').trim(),
      'mattermost.baseUrl': (payload['mattermostBaseUrl'] as String? ?? '')
          .trim(),
      'mattermost.token': (payload['mattermostToken'] as String? ?? '').trim(),
      'mattermost.teamId': (payload['mattermostTeamId'] as String? ?? '')
          .trim(),
      'mattermost.teamName': (payload['mattermostTeamName'] as String? ?? '')
          .trim(),
      'mattermost.bots': jsonEncode(
        mattermostBots.map((item) => item.toJson()).toList(growable: false),
      ),
      'mattermost.activeBotId': normalizedActiveMattermostBotId,
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
    final activeBot = settings.activeMattermostBot;
    return MattermostClient(
      baseUrl: activeBot?.baseUrl ?? settings.mattermostBaseUrl,
      token: activeBot?.token ?? settings.mattermostToken,
      teamId: (activeBot?.teamId ?? settings.mattermostTeamId).isEmpty
          ? null
          : (activeBot?.teamId ?? settings.mattermostTeamId),
      teamName: (activeBot?.teamName ?? settings.mattermostTeamName).isEmpty
          ? null
          : (activeBot?.teamName ?? settings.mattermostTeamName),
      configuredChannels: settings.defaultChannels,
    );
  }

  MattermostClient? buildMattermostClientForBot(
    AppSettings settings,
    String? botId,
  ) {
    if (botId == null || botId.trim().isEmpty) {
      return buildMattermostClient(settings);
    }
    final requested = settings.mattermostBots.where(
      (item) => item.id == botId.trim(),
    );
    if (requested.isEmpty) {
      return null;
    }
    final bot = requested.first;
    return MattermostClient(
      baseUrl: bot.baseUrl,
      token: bot.token,
      teamId: bot.teamId.isEmpty ? null : bot.teamId,
      teamName: bot.teamName.isEmpty ? null : bot.teamName,
      configuredChannels: settings.defaultChannels,
    );
  }

  List<MattermostBotSettings> _loadMattermostBots(Map<String, String> stored) {
    final raw = stored['mattermost.bots']?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        return _normalizeMattermostBots(decoded);
      } catch (_) {}
    }

    final legacyBaseUrl =
        stored['mattermost.baseUrl'] ?? _config.defaultMattermostBaseUrl ?? '';
    final legacyToken =
        stored['mattermost.token'] ?? _config.defaultMattermostToken ?? '';
    final legacyTeamId =
        stored['mattermost.teamId'] ?? _config.defaultMattermostTeamId ?? '';
    final legacyTeamName =
        stored['mattermost.teamName'] ?? _config.defaultMattermostTeamName ?? '';
    final legacyConfigured =
        legacyBaseUrl.trim().isNotEmpty ||
        legacyToken.trim().isNotEmpty ||
        legacyTeamId.trim().isNotEmpty ||
        legacyTeamName.trim().isNotEmpty;
    if (!legacyConfigured) {
      return const <MattermostBotSettings>[];
    }
    return <MattermostBotSettings>[
      MattermostBotSettings(
        id: 'primary',
        name: 'Основной бот',
        baseUrl: legacyBaseUrl.trim(),
        token: legacyToken.trim(),
        teamId: legacyTeamId.trim(),
        teamName: legacyTeamName.trim(),
      ),
    ];
  }

  List<MattermostBotSettings> _normalizeMattermostBots(Object? raw) {
    if (raw is! List) {
      return const <MattermostBotSettings>[];
    }
    final bots = <MattermostBotSettings>[];
    final seenIds = <String>{};
    for (var index = 0; index < raw.length; index += 1) {
      final item = raw[index];
      if (item is! Map) {
        continue;
      }
      final id = (item['id']?.toString().trim().isNotEmpty == true
              ? item['id']!.toString().trim()
              : 'bot-${index + 1}')
          .toLowerCase();
      if (!seenIds.add(id)) {
        continue;
      }
      bots.add(
        MattermostBotSettings(
          id: id,
          name: item['name']?.toString().trim() ?? '',
          baseUrl: item['baseUrl']?.toString().trim() ?? '',
          token: item['token']?.toString().trim() ?? '',
          teamId: item['teamId']?.toString().trim() ?? '',
          teamName: item['teamName']?.toString().trim() ?? '',
        ),
      );
    }
    return List<MattermostBotSettings>.unmodifiable(bots);
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }
}
