import 'config.dart';
import 'database.dart';
import 'database_store.dart';
import 'postgres_database_store.dart';

abstract class DatabaseProviderFactory {
  String get driver;

  DatabaseStore open(AppConfig config);
}

class SqliteDatabaseProviderFactory implements DatabaseProviderFactory {
  @override
  String get driver => 'sqlite';

  @override
  DatabaseStore open(AppConfig config) {
    return SqliteDatabaseStore(
      AppDatabase(
        databasePath: config.databasePath,
        driver: driver,
        connectionTarget: config.databaseUrl ?? config.databasePath,
      ),
    );
  }
}

class PostgresDatabaseProviderFactory implements DatabaseProviderFactory {
  @override
  String get driver => 'postgres';

  @override
  DatabaseStore open(AppConfig config) {
    final databaseUrl = config.databaseUrl?.trim();
    if (databaseUrl == null || databaseUrl.isEmpty) {
      throw StateError(
        'DATABASE_URL must be provided when DATABASE_DRIVER=postgres.',
      );
    }
    return PostgresDatabaseStore(connectionUrl: databaseUrl);
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
        for (final provider in
            providers ??
                [
                  SqliteDatabaseProviderFactory(),
                  PostgresDatabaseProviderFactory(),
                ])
          provider.driver: provider,
      };

  final Map<String, DatabaseProviderFactory> _providers;

  DatabaseStore open(AppConfig config) {
    final provider = _providers[config.databaseDriver];
    if (provider == null) {
      throw UnsupportedDatabaseDriverError(config.databaseDriver);
    }
    return provider.open(config);
  }
}
