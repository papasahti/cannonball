import 'dart:io';

import 'package:cannonball/src/config.dart';
import 'package:cannonball/src/database.dart';
import 'package:cannonball/src/settings_service.dart';
import 'package:test/test.dart';

void main() {
  test('integration settings persist in database across service restart', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cannonball-settings-',
    );
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final databasePath = '${tempDir.path}/cannonball.db';
    final firstDatabase = AppDatabase(databasePath: databasePath);
    firstDatabase.initialize();

    final firstService = SettingsService(
      database: firstDatabase,
      config: _testConfig(databasePath: databasePath),
    );

    firstService.updateFromPayload({
      'appTitle': 'cannonball',
      'deliveryMode': 'n8n',
      'defaultChannels': ['alerts', 'ops'],
      'mattermostBaseUrl': 'https://mm.example.com',
      'mattermostToken': 'mm-token',
      'mattermostTeamId': 'team-id',
      'mattermostTeamName': 'devops',
      'n8nBaseUrl': 'https://n8n.example.com',
      'n8nWebhookUrl': 'https://n8n.example.com/webhook/cannonball',
      'n8nApiKey': 'n8n-api-key',
      'n8nWebhookSecret': 'n8n-secret',
      'n8nInboundSecret': 'n8n-inbound-secret',
      'publicBaseUrl': 'https://cannonball.example.com',
      'smtpHost': 'smtp.example.com',
      'smtpPort': '587',
      'smtpUsername': 'mailer',
      'smtpPassword': 'mailer-pass',
      'smtpFromEmail': 'noreply@example.com',
      'smtpFromName': 'cannonball',
      'smtpUseSsl': true,
      'authMode': 'hybrid',
      'keycloakIssuerUrl': 'https://sso.example.com/realms/main',
      'keycloakClientId': 'cannonball',
      'keycloakClientSecret': 'keycloak-secret',
      'keycloakScopes': 'openid profile email',
      'keycloakAdminRole': 'cannonball-admin',
    });

    firstDatabase.close();

    final secondDatabase = AppDatabase(databasePath: databasePath);
    secondDatabase.initialize();
    addTearDown(secondDatabase.close);

    final secondService = SettingsService(
      database: secondDatabase,
      config: _testConfig(databasePath: databasePath),
    );
    final settings = secondService.load();

    expect(settings.deliveryMode, 'n8n');
    expect(settings.defaultChannels, ['alerts', 'ops']);
    expect(settings.mattermostBaseUrl, 'https://mm.example.com');
    expect(settings.mattermostToken, 'mm-token');
    expect(settings.mattermostTeamId, 'team-id');
    expect(settings.mattermostTeamName, 'devops');
    expect(settings.n8nBaseUrl, 'https://n8n.example.com');
    expect(
      settings.n8nWebhookUrl,
      'https://n8n.example.com/webhook/cannonball',
    );
    expect(settings.n8nApiKey, 'n8n-api-key');
    expect(settings.n8nWebhookSecret, 'n8n-secret');
    expect(settings.n8nInboundSecret, 'n8n-inbound-secret');
    expect(settings.publicBaseUrl, 'https://cannonball.example.com');
    expect(settings.smtpHost, 'smtp.example.com');
    expect(settings.smtpPort, 587);
    expect(settings.smtpUsername, 'mailer');
    expect(settings.smtpPassword, 'mailer-pass');
    expect(settings.smtpFromEmail, 'noreply@example.com');
    expect(settings.smtpFromName, 'cannonball');
    expect(settings.smtpUseSsl, isTrue);
    expect(settings.authMode, 'hybrid');
    expect(
      settings.keycloakIssuerUrl,
      'https://sso.example.com/realms/main',
    );
    expect(settings.keycloakClientId, 'cannonball');
    expect(settings.keycloakClientSecret, 'keycloak-secret');
    expect(settings.keycloakScopes, 'openid profile email');
    expect(settings.keycloakAdminRole, 'cannonball-admin');
  });
}

AppConfig _testConfig({required String databasePath}) {
  return AppConfig(
    port: 8080,
    databaseDriver: 'sqlite',
    databasePath: databasePath,
    databaseUrl: null,
    bootstrapAdminUsername: 'admin',
    bootstrapAdminDisplayName: 'Admin',
    bootstrapAdminPassword: 'adminadmin',
    bootstrapAdminPasswordHash: null,
    sessionTtl: const Duration(hours: 12),
    secureCookies: false,
    defaultAppTitle: 'cannonball',
    defaultDeliveryMode: 'mattermost',
    defaultMattermostBaseUrl: null,
    defaultMattermostToken: null,
    defaultMattermostTeamId: null,
    defaultMattermostTeamName: null,
    defaultChannels: const [],
    defaultN8nBaseUrl: null,
    defaultN8nWebhookUrl: null,
    defaultN8nApiKey: null,
    defaultN8nWebhookSecret: null,
    defaultN8nInboundSecret: null,
    bootstrapAdminEmail: 'admin@example.com',
    defaultPublicBaseUrl: null,
    defaultSmtpHost: null,
    defaultSmtpPort: 587,
    defaultSmtpUsername: null,
    defaultSmtpPassword: null,
    defaultSmtpFromEmail: null,
    defaultSmtpFromName: null,
    defaultSmtpUseSsl: false,
    defaultAuthMode: 'local',
    defaultKeycloakIssuerUrl: null,
    defaultKeycloakClientId: null,
    defaultKeycloakClientSecret: null,
    defaultKeycloakScopes: 'openid profile email',
    defaultKeycloakAdminRole: 'cannonball-admin',
    webRoot: 'web',
  );
}
