import 'package:cannonball/src/postgres_database_store.dart';
import 'package:test/test.dart';

void main() {
  final databaseUrl = const String.fromEnvironment(
    'TEST_POSTGRES_URL',
    defaultValue: '',
  );

  group('PostgresDatabaseStore integration', () {
    if (databaseUrl.isEmpty) {
      test('skipped without TEST_POSTGRES_URL', () {
        expect(true, isTrue);
      }, skip: 'Set TEST_POSTGRES_URL to run PostgreSQL integration tests.');
      return;
    }

    late PostgresDatabaseStore store;

    setUp(() async {
      store = PostgresDatabaseStore(connectionUrl: databaseUrl);
      await store.initialize();
    });

    tearDown(() async {
      await store.close();
    });

    test('can initialize schema and persist bootstrap admin', () async {
      await store.ensureBootstrapAdmin(
        username: 'admin',
        displayName: 'Admin',
        email: 'admin@example.com',
        passwordHash: 'hash-value',
        forcePasswordSync: true,
      );

      final admin = await store.getUserByUsername('admin');
      expect(admin, isNotNull);
      expect(admin!['username'], 'admin');
      expect(admin['role'], 'admin');
      expect(admin['isActive'], true);
    });

    test('can persist settings', () async {
      await store.upsertSettings({
        'mattermostBaseUrl': 'https://mm.example.com',
        'n8nInboundSecret': 'secret',
      });

      final settings = await store.getSettings();
      expect(settings['mattermostBaseUrl'], 'https://mm.example.com');
      expect(settings['n8nInboundSecret'], 'secret');
    });
  });
}
