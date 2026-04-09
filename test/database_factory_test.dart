import 'package:cannonball/src/config.dart';
import 'package:cannonball/src/database_factory.dart';
import 'package:cannonball/src/postgres_database_store.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseFactoryRegistry', () {
    test('opens postgres store when postgres driver is configured', () {
      final registry = DatabaseFactoryRegistry();
      final store = registry.open(_config(
        databaseDriver: 'postgres',
        databaseUrl: 'postgresql://cannonball:cannonball@localhost:5432/cannonball',
      ));

      expect(store, isA<PostgresDatabaseStore>());
    });

    test('throws when postgres driver is configured without database url', () {
      final registry = DatabaseFactoryRegistry();

      expect(
        () => registry.open(_config(databaseDriver: 'postgres')),
        throwsA(isA<StateError>()),
      );
    });

    test('postgres store accepts docker-style url without explicit sslmode', () {
      final store = PostgresDatabaseStore(
        connectionUrl:
            'postgresql://cannonball:cannonball@postgres:5432/cannonball',
      );

      expect(
        store.normalizeForTest(),
        'postgresql://cannonball:cannonball@postgres:5432/cannonball?sslmode=disable',
      );
    });
  });
}

AppConfig _config({
  required String databaseDriver,
  String? databaseUrl,
}) {
  return AppConfig(
    port: 8080,
    databaseDriver: databaseDriver,
    databasePath: '/tmp/cannonball.db',
    databaseUrl: databaseUrl,
    bootstrapAdminUsername: 'admin',
    bootstrapAdminDisplayName: 'Admin',
    bootstrapAdminPassword: 'adminadmin',
    bootstrapAdminPasswordHash: null,
    forceBootstrapAdminPasswordSync: false,
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
