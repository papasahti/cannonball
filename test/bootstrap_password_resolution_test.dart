import 'package:cannonball/app.dart';
import 'package:cannonball/src/auth_service.dart';
import 'package:cannonball/src/config.dart';
import 'package:test/test.dart';

void main() {
  AppConfig buildConfig({
    required String? password,
    required String? passwordHash,
    required bool forceSync,
  }) {
    return AppConfig(
      port: 8080,
      databaseDriver: 'postgres',
      databasePath: '/tmp/cannonball.db',
      databaseUrl: 'postgresql://cannonball:cannonball@localhost:5432/cannonball',
      bootstrapAdminUsername: 'admin',
      bootstrapAdminDisplayName: 'System Administrator',
      bootstrapAdminPassword: password,
      bootstrapAdminPasswordHash: passwordHash,
      forceBootstrapAdminPasswordSync: forceSync,
      authDebugLogging: false,
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

  test(
    'force bootstrap password sync prefers APP_PASSWORD over stale APP_PASSWORD_HASH',
    () {
      final config = buildConfig(
        password: 'adminadmin',
        passwordHash: AuthService.hashPassword('old-password'),
        forceSync: true,
      );

      expect(
        resolveBootstrapPasswordHash(config),
        AuthService.hashPassword('adminadmin'),
      );
    },
  );

  test('uses APP_PASSWORD_HASH when force sync is disabled', () {
    final config = buildConfig(
      password: 'adminadmin',
      passwordHash: AuthService.hashPassword('old-password'),
      forceSync: false,
    );

    expect(
      resolveBootstrapPasswordHash(config),
      AuthService.hashPassword('old-password'),
    );
  });
}
