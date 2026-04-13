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

String _localPasswordChangedKey(String username) =>
    'auth.localPasswordChanged.${username.toLowerCase()}';

String _bootstrapPasswordHashKey(String username) =>
    'auth.bootstrapPasswordHash.${username.toLowerCase()}';

Future<Application> buildApplication() async {
  final config = AppConfig.fromEnvironment();
  final database = DatabaseFactoryRegistry().open(config);
  _authLog(
    config,
    'bootstrap start driver=${config.databaseDriver} username=${config.bootstrapAdminUsername} forceSync=${config.forceBootstrapAdminPasswordSync} passwordProvided=${config.bootstrapAdminPassword != null} passwordHashProvided=${config.bootstrapAdminPasswordHash != null}',
  );
  await database.initialize();
  final bootstrapMarkers = await database.getSettings();
  final existingAdmin = await database.getUserByUsername(
    config.bootstrapAdminUsername,
  );
  final bootstrapPasswordHash = config.resolveBootstrapPasswordHash();
  final adminPasswordChanged =
      bootstrapMarkers[_localPasswordChangedKey(
            config.bootstrapAdminUsername,
          )] ==
          'true' ||
      (bootstrapMarkers[_bootstrapPasswordHashKey(
                config.bootstrapAdminUsername,
              )] ==
              bootstrapPasswordHash &&
          existingAdmin?['passwordHash'] != null &&
          existingAdmin?['passwordHash'] != bootstrapPasswordHash);
  final forceAdminPasswordSync =
      config.forceBootstrapAdminPasswordSync && !adminPasswordChanged;
  await database.ensureBootstrapAdmin(
    username: config.bootstrapAdminUsername,
    displayName: config.bootstrapAdminDisplayName,
    email: config.bootstrapAdminEmail,
    passwordHash: bootstrapPasswordHash,
    forcePasswordSync: forceAdminPasswordSync,
  );
  await database.upsertSettings({
    _bootstrapPasswordHashKey(config.bootstrapAdminUsername):
        bootstrapPasswordHash,
  });
  final bootstrapUser = await database.getUserByUsername(
    config.bootstrapAdminUsername,
  );
  _authLog(
    config,
    'bootstrap complete username=${config.bootstrapAdminUsername} exists=${bootstrapUser != null} role=${bootstrapUser?['role']} active=${bootstrapUser?['isActive']} provider=${bootstrapUser?['authProvider']}',
  );
  final bootstrapUserUsername = config.bootstrapUserUsername;
  if (bootstrapUserUsername != null &&
      bootstrapUserUsername.toLowerCase() !=
          config.bootstrapAdminUsername.toLowerCase()) {
    final userPasswordChanged =
        bootstrapMarkers[_localPasswordChangedKey(bootstrapUserUsername)] ==
        'true';
    _authLog(
      config,
      'bootstrap default user start username=$bootstrapUserUsername forceSync=${config.forceBootstrapUserPasswordSync} passwordChangedByUser=$userPasswordChanged passwordProvided=${config.bootstrapUserPassword != null} passwordHashProvided=${config.bootstrapUserPasswordHash != null}',
    );
    final bootstrapUserPasswordHash = config.resolveBootstrapUserPasswordHash();
    if (bootstrapUserPasswordHash != null) {
      final existingDefaultUser = await database.getUserByUsername(
        bootstrapUserUsername,
      );
      final effectiveUserPasswordChanged =
          userPasswordChanged ||
          (bootstrapMarkers[_bootstrapPasswordHashKey(bootstrapUserUsername)] ==
                  bootstrapUserPasswordHash &&
              existingDefaultUser?['passwordHash'] != null &&
              existingDefaultUser?['passwordHash'] !=
                  bootstrapUserPasswordHash);
      await database.ensureBootstrapUser(
        username: bootstrapUserUsername,
        displayName: config.bootstrapUserDisplayName,
        email: config.bootstrapUserEmail,
        passwordHash: bootstrapUserPasswordHash,
        forcePasswordSync:
            config.forceBootstrapUserPasswordSync &&
            !effectiveUserPasswordChanged,
      );
      await database.upsertSettings({
        _bootstrapPasswordHashKey(bootstrapUserUsername):
            bootstrapUserPasswordHash,
      });
      final defaultUser = await database.getUserByUsername(
        bootstrapUserUsername,
      );
      _authLog(
        config,
        'bootstrap default user complete username=$bootstrapUserUsername exists=${defaultUser != null} role=${defaultUser?['role']} active=${defaultUser?['isActive']} provider=${defaultUser?['authProvider']}',
      );
    }
  }

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
