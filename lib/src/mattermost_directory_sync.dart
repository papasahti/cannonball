import 'dart:async';

import 'database_store.dart';
import 'settings_service.dart';

class MattermostDirectorySyncService {
  MattermostDirectorySyncService({
    required DatabaseStore database,
    required SettingsService settingsService,
    this.interval = const Duration(minutes: 15),
  }) : _database = database,
       _settingsService = settingsService;

  final DatabaseStore _database;
  final SettingsService _settingsService;
  final Duration interval;

  Timer? _timer;
  bool _syncInProgress = false;

  void start() {
    unawaited(syncNow());
    _timer = Timer.periodic(interval, (_) {
      unawaited(syncNow());
    });
  }

  Future<void> syncNow() async {
    if (_syncInProgress) {
      return;
    }

    final settings = await _settingsService.load();
    if (!settings.isMattermostConfigured) {
      return;
    }

    _syncInProgress = true;
    try {
      final client = _settingsService.buildMattermostClient(settings);
      final users = await client.listUsers();
      final groups = await client.listGroups();
      final channels = await client.listDirectoryChannels();

      await _database.replaceMattermostDirectoryUsers(
        users
            .map((user) => {
                  'id': user.id,
                  'username': user.username,
                  'displayName': user.displayName.isNotEmpty
                      ? user.displayName
                      : user.username,
                  'email': user.email,
                })
            .toList(growable: false),
      );
      await _database.replaceMattermostDirectoryGroups(
        groups
            .map((group) => {
                  'id': group.id,
                  'name': group.name,
                  'displayName': group.displayName,
                  'memberCount': group.memberCount,
                })
            .toList(growable: false),
      );
      await _database.replaceMattermostDirectoryChannels(
        channels
            .map((channel) => {
                  'id': channel.id,
                  'name': channel.name,
                  'displayName': channel.displayName,
                  'type': channel.type,
                })
            .toList(growable: false),
      );
    } finally {
      _syncInProgress = false;
    }
  }

  void close() {
    _timer?.cancel();
  }
}
