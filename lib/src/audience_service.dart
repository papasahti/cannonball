import 'integration_registry.dart';
import 'messaging_platform.dart';
import 'settings_service.dart';

class AudienceService {
  AudienceService({required this.registry});

  final IntegrationRegistry registry;

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
    final channels = await platform.searchChannels(query);
    return channels.map((channel) => channel.toJson()).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> searchUsers({
    required AppSettings settings,
    required String query,
  }) async {
    final platform = _requirePlatform(settings);
    final users = await platform.searchUsers(query);
    return users.map((user) => user.toJson()).toList(growable: false);
  }
}
