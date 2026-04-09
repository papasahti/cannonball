import 'config.dart';
import 'database.dart';

abstract class DatabaseProviderFactory {
  String get driver;

  AppDatabase open(AppConfig config);
}

class SqliteDatabaseProviderFactory implements DatabaseProviderFactory {
  @override
  String get driver => 'sqlite';

  @override
  AppDatabase open(AppConfig config) {
    return AppDatabase(
      databasePath: config.databasePath,
      driver: driver,
      connectionTarget: config.databaseUrl ?? config.databasePath,
    );
  }
}

class UnsupportedDatabaseDriverError extends StateError {
  UnsupportedDatabaseDriverError(String driver)
    : super(
        'Database driver "$driver" is not available in this build. '
        'cannonball uses a provider-based storage layer, so you can add a new driver factory without rewriting the application core.',
      );
}

class DatabaseFactoryRegistry {
  DatabaseFactoryRegistry({List<DatabaseProviderFactory>? providers})
    : _providers = {
        for (final provider in providers ?? [SqliteDatabaseProviderFactory()])
          provider.driver: provider,
      };

  final Map<String, DatabaseProviderFactory> _providers;

  AppDatabase open(AppConfig config) {
    final provider = _providers[config.databaseDriver];
    if (provider == null) {
      throw UnsupportedDatabaseDriverError(config.databaseDriver);
    }
    return provider.open(config);
  }
}
