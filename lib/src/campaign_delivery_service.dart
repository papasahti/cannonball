import 'auth_service.dart';
import 'database.dart';
import 'delivery_router.dart';
import 'integration_registry.dart';
import 'messaging_platform.dart';
import 'settings_service.dart';
import 'targeting.dart';

class CampaignDeliveryOutcome {
  CampaignDeliveryOutcome({
    required this.campaignId,
    required this.sent,
    required this.failed,
    required this.deliveryMode,
    required this.deliveries,
  });

  final int campaignId;
  final int sent;
  final int failed;
  final String deliveryMode;
  final List<Map<String, Object?>> deliveries;

  Map<String, Object?> toJson() => {
    'ok': failed == 0,
    'campaignId': campaignId,
    'sent': sent,
    'failed': failed,
    'deliveryMode': deliveryMode,
    'deliveries': deliveries,
  };
}

class CampaignDeliveryService {
  CampaignDeliveryService({
    required this.database,
    required this.registry,
  });

  final AppDatabase database;
  final IntegrationRegistry registry;

  Future<CampaignDeliveryOutcome> sendCampaign({
    required AuthenticatedUser sender,
    required AppSettings settings,
    required String message,
    required List<Map<String, Object?>> rawUsers,
    required List<Map<String, Object?>> rawGroups,
    required List<String> rawChannels,
  }) async {
    final targets = buildTargets(
      rawUsers: rawUsers,
      rawGroups: rawGroups,
      rawChannels: rawChannels,
    );

    final campaignId = database.insertCampaign(
      createdAt: DateTime.now(),
      createdBy: sender.username,
      message: message,
      users: rawUsers,
      groups: rawGroups,
      channels: rawChannels,
    );

    final router = registry.buildDeliveryRouter(settings);
    if (router == null) {
      throw DeliveryRouterException(
        registry.validateDeliveryConfiguration(settings) ??
            'Не удалось собрать маршрут доставки.',
      );
    }

    final deliveries = <Map<String, Object?>>[];
    final deliveredUserIds = <String>{};
    var sentCount = 0;
    var failedCount = 0;

    final platform = registry.buildAudiencePlatform(settings);

    for (final target in targets) {
      if (target.type == 'group' &&
          platform != null &&
          router.key == platform.key &&
          target.groupId != null) {
        final members = await platform.listGroupMembers(target.groupId!);
        for (final member in members) {
          if (!deliveredUserIds.add(member.id)) {
            continue;
          }
          final memberTarget = TargetCandidate(
            type: 'user',
            key: member.id,
            label: member.displayName.isNotEmpty
                ? '${member.displayName} (@${member.username})'
                : '@${member.username}',
            userId: member.id,
            username: member.username,
            displayName: member.displayName,
          );
          final result = await _deliverSingleTarget(
            campaignId: campaignId,
            sender: sender,
            router: router,
            target: memberTarget,
            message: message,
            deliveryTypeOverride: 'group',
            deliveryKeyOverride: '${target.groupId}:${member.id}',
            deliveryLabelOverride:
                '${target.label} → ${member.displayName.isNotEmpty ? member.displayName : '@${member.username}'}',
            responseExtras: {
              'groupId': target.groupId,
              'groupName': target.groupName,
            },
          );
          deliveries.add(result.payload);
          sentCount += result.sentDelta;
          failedCount += result.failedDelta;
        }
        continue;
      }

      if (target.type == 'user' && target.userId != null) {
        if (!deliveredUserIds.add(target.userId!)) {
          continue;
        }
      }

      final result = await _deliverSingleTarget(
        campaignId: campaignId,
        sender: sender,
        router: router,
        target: target,
        message: message,
      );
      deliveries.add(result.payload);
      sentCount += result.sentDelta;
      failedCount += result.failedDelta;
    }

    database.updateCampaignSummary(
      campaignId: campaignId,
      sentCount: sentCount,
      failedCount: failedCount,
    );

    return CampaignDeliveryOutcome(
      campaignId: campaignId,
      sent: sentCount,
      failed: failedCount,
      deliveryMode: settings.deliveryMode,
      deliveries: deliveries,
    );
  }

  Future<_DeliveryAttemptResult> _deliverSingleTarget({
    required int campaignId,
    required AuthenticatedUser sender,
    required DeliveryRouter router,
    required TargetCandidate target,
    required String message,
    String? deliveryTypeOverride,
    String? deliveryKeyOverride,
    String? deliveryLabelOverride,
    Map<String, Object?> responseExtras = const {},
  }) async {
    try {
      final responsePayload = await router.deliverTarget(
        sender: sender,
        target: target,
        message: message,
      );
      final mergedResponse = {...responseExtras, ...responsePayload};
      database.insertDelivery(
        campaignId: campaignId,
        targetType: deliveryTypeOverride ?? target.type,
        targetKey: deliveryKeyOverride ?? target.key,
        targetLabel: deliveryLabelOverride ?? target.label,
        status: 'sent',
        sentAt: DateTime.now(),
        responsePayload: mergedResponse,
      );
      return _DeliveryAttemptResult(
        sentDelta: 1,
        failedDelta: 0,
        payload: {
          'target': target.toJson(),
          if (responseExtras.isNotEmpty) 'context': responseExtras,
          'status': 'sent',
          'response': mergedResponse,
        },
      );
    } on MessagingPlatformException catch (error) {
      database.insertDelivery(
        campaignId: campaignId,
        targetType: deliveryTypeOverride ?? target.type,
        targetKey: deliveryKeyOverride ?? target.key,
        targetLabel: deliveryLabelOverride ?? target.label,
        status: 'failed',
        errorMessage: error.details ?? error.message,
        responsePayload: {
          ...responseExtras,
          'statusCode': error.statusCode,
        },
      );
      return _DeliveryAttemptResult(
        sentDelta: 0,
        failedDelta: 1,
        payload: {
          'target': target.toJson(),
          if (responseExtras.isNotEmpty) 'context': responseExtras,
          'status': 'failed',
          'error': error.message,
          'details': error.details,
          'statusCode': error.statusCode,
        },
      );
    } on DeliveryRouterException catch (error) {
      database.insertDelivery(
        campaignId: campaignId,
        targetType: deliveryTypeOverride ?? target.type,
        targetKey: deliveryKeyOverride ?? target.key,
        targetLabel: deliveryLabelOverride ?? target.label,
        status: 'failed',
        errorMessage: error.details ?? error.message,
        responsePayload: {
          ...responseExtras,
          'statusCode': error.statusCode,
        },
      );
      return _DeliveryAttemptResult(
        sentDelta: 0,
        failedDelta: 1,
        payload: {
          'target': target.toJson(),
          if (responseExtras.isNotEmpty) 'context': responseExtras,
          'status': 'failed',
          'error': error.message,
          'details': error.details,
          'statusCode': error.statusCode,
        },
      );
    } catch (error) {
      database.insertDelivery(
        campaignId: campaignId,
        targetType: deliveryTypeOverride ?? target.type,
        targetKey: deliveryKeyOverride ?? target.key,
        targetLabel: deliveryLabelOverride ?? target.label,
        status: 'failed',
        errorMessage: error.toString(),
        responsePayload: responseExtras,
      );
      return _DeliveryAttemptResult(
        sentDelta: 0,
        failedDelta: 1,
        payload: {
          'target': target.toJson(),
          if (responseExtras.isNotEmpty) 'context': responseExtras,
          'status': 'failed',
          'error': error.toString(),
        },
      );
    }
  }
}

class _DeliveryAttemptResult {
  _DeliveryAttemptResult({
    required this.sentDelta,
    required this.failedDelta,
    required this.payload,
  });

  final int sentDelta;
  final int failedDelta;
  final Map<String, Object?> payload;
}
