import 'dart:io';

import 'package:shelf/shelf.dart';

import 'src/app_server.dart';
import 'src/auth_service.dart';
import 'src/config.dart';
import 'src/database.dart';
import 'src/database_factory.dart';
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
  final AppDatabase database;
  final MattermostDirectorySyncService? directorySyncService;

  void close() {
    directorySyncService?.close();
    database.close();
  }
}

Future<Application> buildApplication() async {
  final config = AppConfig.fromEnvironment();
  final database = DatabaseFactoryRegistry().open(config);
  database.initialize();
  final bootstrapPasswordHash =
      config.bootstrapAdminPasswordHash ??
      AuthService.hashPassword(config.bootstrapAdminPassword!);
  database.ensureBootstrapAdmin(
    username: config.bootstrapAdminUsername,
    displayName: config.bootstrapAdminDisplayName,
    email: config.bootstrapAdminEmail,
    passwordHash: bootstrapPasswordHash,
    forcePasswordSync: config.forceBootstrapAdminPasswordSync,
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
