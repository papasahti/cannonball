import 'database.dart';
import 'integration_registry.dart';
import 'messaging_platform.dart';
import 'settings_service.dart';

class AudienceService {
  AudienceService({required this.registry, required this.database});

  final IntegrationRegistry registry;
  final AppDatabase database;

  MessagingPlatformAdapter _requirePlatform(AppSettings settings) {
    final platform = registry.buildAudiencePlatform(settings);
    if (platform == null) {
      throw MessagingPlatformException(
        'Каталог аудитории недоступен: ни одна платформа сообщений не настроена.',
      );
    }
    return platform;
  }

  Future<List<Map<String, Object?>>> searchAudience({
    required AppSettings settings,
    required String query,
  }) async {
    final platform = _requirePlatform(settings);
    if (platform.key == 'mattermost') {
      final cachedUsers = database.searchMattermostDirectoryUsers(query);
      final cachedGroups = database.searchMattermostDirectoryGroups(query);
      if (cachedUsers.isNotEmpty ||
          cachedGroups.isNotEmpty ||
          database.hasMattermostDirectoryUsers() ||
          database.hasMattermostDirectoryGroups()) {
        return [
          ...cachedUsers.map((user) => {'kind': 'user', ...user}),
          ...cachedGroups.map((group) => {'kind': 'group', ...group}),
        ];
      }
    }

    final users = await platform.searchUsers(query);
    final groups = await platform.searchGroups(query);
    return [
      ...users.map((user) => {'kind': 'user', ...user.toJson()}),
      ...groups.map((group) => {'kind': 'group', ...group.toJson()}),
    ];
  }

  Future<List<Map<String, Object?>>> searchChannels({
    required AppSettings settings,
    required String query,
  }) async {
    final platform = _requirePlatform(settings);
    if (platform.key == 'mattermost') {
      final cachedChannels = database.searchMattermostDirectoryChannels(query);
      if (cachedChannels.isNotEmpty || database.hasMattermostDirectoryChannels()) {
        return cachedChannels;
      }
    }
    final channels = await platform.searchChannels(query);
    return channels.map((channel) => channel.toJson()).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> searchUsers({
    required AppSettings settings,
    required String query,
  }) async {
    final platform = _requirePlatform(settings);
    if (platform.key == 'mattermost') {
      final cachedUsers = database.searchMattermostDirectoryUsers(query);
      if (cachedUsers.isNotEmpty || database.hasMattermostDirectoryUsers()) {
        return cachedUsers;
      }
    }
    final users = await platform.searchUsers(query);
    return users.map((user) => user.toJson()).toList(growable: false);
  }
}
