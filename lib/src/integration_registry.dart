import 'delivery_router.dart';
import 'messaging_platform.dart';
import 'settings_service.dart';

class IntegrationDescriptor {
  IntegrationDescriptor({
    required this.key,
    required this.label,
    required this.kind,
    required this.configured,
    required this.enabled,
    this.description,
  });

  final String key;
  final String label;
  final String kind;
  final bool configured;
  final bool enabled;
  final String? description;

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'kind': kind,
    'configured': configured,
    'enabled': enabled,
    'description': description,
  };
}

class IntegrationRegistry {
  IntegrationRegistry({required this.settingsService});

  final SettingsService settingsService;

  MessagingPlatformAdapter? buildAudiencePlatform(AppSettings settings) {
    if (settings.isMattermostConfigured) {
      return MattermostMessagingPlatformAdapter(
        settingsService.buildMattermostClient(settings),
      );
    }
    return null;
  }

  DeliveryRouter? buildDeliveryRouter(AppSettings settings) {
    if (settings.deliveryMode == 'mattermost') {
      final platform = buildAudiencePlatform(settings);
      if (platform == null) {
        return null;
      }
      return MattermostDeliveryRouter(
        platformKey: platform.key,
        dispatch: ({required target, required message}) {
          if (target.type == 'user') {
            return platform.sendDirectMessage(
              userId: target.userId!,
              message: message,
            );
          }
          if (target.type == 'group') {
            return Future.value({
              'groupId': target.groupId,
              'groupName': target.groupName,
              'message': 'Доставка в группу передана маршруту платформы.',
            });
          }
          return platform.sendChannelMessage(
            channelName: target.key,
            message: message,
          );
        },
      );
    }

    if (settings.deliveryMode == 'n8n' && settings.isN8nConfigured) {
      return N8nDeliveryRouter(settings: settings);
    }

    return null;
  }

  List<IntegrationDescriptor> listIntegrations(AppSettings settings) => [
    IntegrationDescriptor(
      key: 'mattermost',
      label: 'Mattermost',
      kind: 'messaging',
      configured: settings.isMattermostConfigured,
      enabled:
          settings.isMattermostConfigured &&
          (settings.deliveryMode == 'mattermost' || settings.isMattermostConfigured),
      description: 'Каталог аудитории и прямой канал командных сообщений.',
    ),
    IntegrationDescriptor(
      key: 'n8n',
      label: 'n8n',
      kind: 'automation',
      configured: settings.isN8nConfigured,
      enabled: settings.deliveryMode == 'n8n' && settings.isN8nConfigured,
      description: 'Внешняя orchestration-логика и автоматизированные маршруты.',
    ),
    IntegrationDescriptor(
      key: 'keycloak',
      label: 'Keycloak',
      kind: 'identity',
      configured: settings.isKeycloakConfigured,
      enabled: settings.isKeycloakAuthEnabled,
      description: 'Корпоративный SSO и федерация учётных записей.',
    ),
    IntegrationDescriptor(
      key: 'email',
      label: 'Почта',
      kind: 'service',
      configured: settings.isEmailConfigured,
      enabled: settings.isEmailConfigured,
      description: 'SMTP-восстановление доступа и сервисные уведомления.',
    ),
  ];

  String? validateDeliveryConfiguration(AppSettings settings) {
    if (settings.deliveryMode == 'mattermost' && !settings.isMattermostConfigured) {
      return 'Для прямой отправки нужно настроить Mattermost в кабинете администратора.';
    }
    if (settings.deliveryMode == 'n8n' && !settings.isN8nConfigured) {
      return 'Для режима n8n нужно указать webhook в настройках администратора.';
    }
    return null;
  }
}
