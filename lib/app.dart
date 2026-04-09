import 'dart:io';

import 'package:shelf/shelf.dart';

import 'src/app_server.dart';
import 'src/auth_service.dart';
import 'src/config.dart';
import 'src/database_factory.dart';
import 'src/database_store.dart';
import 'src/mattermost_directory_sync.dart';
import 'src/settings_service.dart';

class Application {
  Application({
    required this.config,
    required this.handler,
    required this.database,
    this.directorySyncService,
  });

  final AppConfig config;
  final Handler handler;
  final DatabaseStore database;
  final MattermostDirectorySyncService? directorySyncService;

  Future<void> close() async {
    directorySyncService?.close();
    await database.close();
  }
}

void _authLog(AppConfig config, String message) {
  if (!config.authDebugLogging) {
    return;
  }
  stderr.writeln('[cannonball][auth] $message');
}

String resolveBootstrapPasswordHash(AppConfig config) {
  return config.resolveBootstrapPasswordHash();
}

Future<Application> buildApplication() async {
  final config = AppConfig.fromEnvironment();
  final database = DatabaseFactoryRegistry().open(config);
  _authLog(
    config,
    'bootstrap start driver=${config.databaseDriver} username=${config.bootstrapAdminUsername} forceSync=${config.forceBootstrapAdminPasswordSync} passwordProvided=${config.bootstrapAdminPassword != null} passwordHashProvided=${config.bootstrapAdminPasswordHash != null}',
  );
  await database.initialize();
  final bootstrapPasswordHash = config.resolveBootstrapPasswordHash();
  await database.ensureBootstrapAdmin(
    username: config.bootstrapAdminUsername,
    displayName: config.bootstrapAdminDisplayName,
    email: config.bootstrapAdminEmail,
    passwordHash: bootstrapPasswordHash,
    forcePasswordSync: config.forceBootstrapAdminPasswordSync,
  );
  final bootstrapUser = await database.getUserByUsername(
    config.bootstrapAdminUsername,
  );
  _authLog(
    config,
    'bootstrap complete username=${config.bootstrapAdminUsername} exists=${bootstrapUser != null} role=${bootstrapUser?['role']} active=${bootstrapUser?['isActive']} provider=${bootstrapUser?['authProvider']}',
  );

  final authService = AuthService(
    database: database,
    sessionTtl: config.sessionTtl,
    secureCookies: config.secureCookies,
  );
  final settingsService = SettingsService(database: database, config: config);
  final directorySyncService = MattermostDirectorySyncService(
    database: database,
    settingsService: settingsService,
  )..start();

  final webRoot = Directory(config.webRoot);
  final handler = createHandler(
    config: config,
    database: database,
    authService: authService,
    settingsService: settingsService,
    webRoot: webRoot,
  );
  return Application(
    config: config,
    handler: handler,
    database: database,
    directorySyncService: directorySyncService,
  );
}
