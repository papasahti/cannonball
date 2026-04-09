import 'audience_service.dart';
import 'settings_service.dart';

class InboundNotificationException implements Exception {
  InboundNotificationException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final String? details;

  @override
  String toString() => message;
}

class InboundEvent {
  InboundEvent({
    required this.source,
    required this.eventType,
    required this.title,
    required this.message,
    required this.users,
    required this.groups,
    required this.channels,
    required this.labels,
    required this.ruleKey,
    required this.requestId,
    required this.rawPayload,
  });

  final String source;
  final String eventType;
  final String title;
  final String message;
  final List<Object?> users;
  final List<Object?> groups;
  final List<String> channels;
  final Map<String, String> labels;
  final String ruleKey;
  final String requestId;
  final Map<String, Object?> rawPayload;
}

class InboundRuleResolution {
  InboundRuleResolution({
    required this.rule,
    required this.message,
    required this.rawUsers,
    required this.rawGroups,
    required this.channels,
  });

  final Map<String, Object?>? rule;
  final String message;
  final List<Map<String, Object?>> rawUsers;
  final List<Map<String, Object?>> rawGroups;
  final List<String> channels;
}

class InboundNotificationService {
  InboundNotificationService({this.audienceService});

  final AudienceService? audienceService;

  InboundEvent normalizeEvent({
    required String source,
    required Map<String, Object?> payload,
  }) {
    final normalizedSource = source.trim().toLowerCase();
    final labels = <String, String>{};
    final rawLabels = payload['labels'];
    if (rawLabels is Map) {
      for (final entry in rawLabels.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty && value.isNotEmpty) {
          labels[key] = value;
        }
      }
    }

    final rawUsers = ((payload['users'] as List<dynamic>?) ?? const [])
        .cast<Object?>()
        .toList(growable: false);
    final rawGroups = ((payload['groups'] as List<dynamic>?) ?? const [])
        .cast<Object?>()
        .toList(growable: false);
    final rawChannels = ((payload['channels'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString().trim().replaceFirst('#', ''))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return InboundEvent(
      source: normalizedSource,
      eventType: (payload['event_type'] as String? ?? '')
          .trim()
          .toLowerCase(),
      title: (payload['title'] as String? ?? '').trim(),
      message: (payload['message'] as String? ?? '').trim(),
      users: rawUsers,
      groups: rawGroups,
      channels: rawChannels,
      labels: labels,
      ruleKey: (payload['rule_key'] as String? ?? '').trim(),
      requestId: (payload['request_id'] as String? ?? '').trim(),
      rawPayload: payload,
    );
  }

  InboundEvent normalizeAlertmanagerEvent(Map<String, Object?> payload) {
    final firstAlert = _firstAlert(payload);
    final labels = <String, String>{};

    void addLabels(Object? raw) {
      if (raw is! Map) {
        return;
      }
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty && value.isNotEmpty) {
          labels[key] = value;
        }
      }
    }

    addLabels(payload['commonLabels']);
    addLabels(firstAlert['labels']);

    final status = (payload['status'] as String? ?? '').trim().toLowerCase();
    final state = (payload['state'] as String? ?? '').trim().toLowerCase();
    if (status.isNotEmpty) {
      labels['status'] = status;
    }
    if (state.isNotEmpty) {
      labels['state'] = state;
    }

    final commonAnnotations =
        Map<String, Object?>.from(payload['commonAnnotations'] as Map? ?? const {});
    final alertAnnotations =
        Map<String, Object?>.from(firstAlert['annotations'] as Map? ?? const {});

    final title =
        (payload['title'] as String? ?? '').trim().isNotEmpty
        ? (payload['title'] as String).trim()
        : (commonAnnotations['summary']?.toString().trim().isNotEmpty == true
              ? commonAnnotations['summary']!.toString().trim()
              : (alertAnnotations['summary']?.toString().trim().isNotEmpty == true
                    ? alertAnnotations['summary']!.toString().trim()
                    : (labels['alertname'] ?? 'Alertmanager event')));

    final messageCandidates = [
      payload['message']?.toString().trim(),
      commonAnnotations['description']?.toString().trim(),
      alertAnnotations['description']?.toString().trim(),
      title,
    ];
    final message = messageCandidates.firstWhere(
      (value) => value != null && value.isNotEmpty,
      orElse: () => title,
    )!;

    final requestIdCandidates = [
      payload['request_id']?.toString().trim(),
      payload['groupKey']?.toString().trim(),
      firstAlert['fingerprint']?.toString().trim(),
    ];
    final requestId = requestIdCandidates.firstWhere(
      (value) => value != null && value.isNotEmpty,
      orElse: () => '',
    )!;

    final rawUsers = ((payload['users'] as List<dynamic>?) ?? const [])
        .cast<Object?>()
        .toList(growable: false);
    final rawGroups = ((payload['groups'] as List<dynamic>?) ?? const [])
        .cast<Object?>()
        .toList(growable: false);
    final rawChannels = ((payload['channels'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString().trim().replaceFirst('#', ''))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return InboundEvent(
      source: 'alertmanager',
      eventType: status.isNotEmpty ? status : state,
      title: title,
      message: message,
      users: rawUsers,
      groups: rawGroups,
      channels: rawChannels,
      labels: labels,
      ruleKey: (payload['rule_key'] as String? ?? '').trim(),
      requestId: requestId,
      rawPayload: payload,
    );
  }

  Future<InboundRuleResolution> resolveDelivery({
    required AppSettings settings,
    required InboundEvent event,
    required List<Map<String, Object?>> activeRules,
  }) async {
    final matchedRule = selectRule(event, activeRules);
    final effectiveMessage = renderMessage(event, matchedRule);
    if (effectiveMessage.isEmpty) {
      throw InboundNotificationException('Во входящем событии нет текста уведомления.');
    }

    final usersSource = matchedRule == null ? event.users : _toObjectList(matchedRule['users']);
    final groupsSource = matchedRule == null ? event.groups : _toObjectList(matchedRule['groups']);
    final channelsSource = matchedRule == null
        ? event.channels
        : _toStringList(matchedRule['channels']);

    final rawUsers = await _resolveUsers(settings: settings, values: usersSource);
    final rawGroups = await _resolveGroups(settings: settings, values: groupsSource);
    final channels = channelsSource
        .map((item) => item.trim().replaceFirst('#', ''))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (rawUsers.isEmpty && rawGroups.isEmpty && channels.isEmpty) {
      throw InboundNotificationException(
        matchedRule == null
            ? 'Во входящем событии не указаны получатели, группы или каналы.'
            : 'Правило не содержит ни одного получателя, группы или канала.',
      );
    }

    return InboundRuleResolution(
      rule: matchedRule,
      message: effectiveMessage,
      rawUsers: rawUsers,
      rawGroups: rawGroups,
      channels: channels,
    );
  }

  Map<String, Object?>? selectRule(
    InboundEvent event,
    List<Map<String, Object?>> activeRules,
  ) {
    if (event.ruleKey.isNotEmpty) {
      for (final rule in activeRules) {
        final candidate = (rule['ruleKey'] as String? ?? '').trim().toLowerCase();
        if (candidate.isNotEmpty && candidate == event.ruleKey.toLowerCase()) {
          return rule;
        }
      }
      throw InboundNotificationException(
        'Активное правило с ключом ${event.ruleKey} не найдено.',
      );
    }

    for (final rule in activeRules) {
      if (_matchesRule(rule, event)) {
        return rule;
      }
    }
    return null;
  }

  bool _matchesRule(Map<String, Object?> rule, InboundEvent event) {
    final source = (rule['source'] as String? ?? '').trim().toLowerCase();
    if (source.isNotEmpty && source != event.source) {
      return false;
    }

    final eventType = (rule['eventType'] as String? ?? '').trim().toLowerCase();
    if (eventType.isNotEmpty && eventType != event.eventType) {
      return false;
    }

    final severity = (rule['severity'] as String? ?? '').trim().toLowerCase();
    if (severity.isNotEmpty &&
        (event.labels['severity'] ?? '').trim().toLowerCase() != severity) {
      return false;
    }

    final containsText = (rule['containsText'] as String? ?? '').trim().toLowerCase();
    if (containsText.isNotEmpty) {
      final text = '${event.title} ${event.message}'.toLowerCase();
      if (!text.contains(containsText)) {
        return false;
      }
    }

    final labelFilters =
        Map<String, Object?>.from(rule['labelFilters'] as Map? ?? const {});
    for (final entry in labelFilters.entries) {
      final expected = entry.value?.toString().trim().toLowerCase() ?? '';
      if (expected.isEmpty) {
        continue;
      }
      final actual = (event.labels[entry.key.toString()] ?? '')
          .trim()
          .toLowerCase();
      if (actual != expected) {
        return false;
      }
    }

    return true;
  }

  String renderMessage(InboundEvent event, Map<String, Object?>? rule) {
    final template = (rule?['messageTemplate'] as String? ?? '').trim();
    if (template.isEmpty) {
      return event.message;
    }
    return template
        .replaceAll('{{message}}', event.message)
        .replaceAll('{{title}}', event.title)
        .replaceAll('{{severity}}', event.labels['severity'] ?? '')
        .trim();
  }

  Future<List<Map<String, Object?>>> _resolveUsers({
    required AppSettings settings,
    required List<Object?> values,
  }) async {
    final service = audienceService;
    if (service == null) {
      throw InboundNotificationException('Сервис каталога аудитории не подключён.');
    }
    final resolved = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final value in values) {
      if (value is Map) {
        final mapped = Map<String, Object?>.from(value);
        final key = mapped['id']?.toString() ?? mapped['username']?.toString() ?? '';
        if (key.isNotEmpty && seen.add(key)) {
          resolved.add(mapped);
        }
        continue;
      }

      final query = value?.toString().trim() ?? '';
      if (query.isEmpty) {
        continue;
      }
      final users = await service.searchUsers(settings: settings, query: query);
      final matched = users.firstWhere(
        (user) => _matchesUser(user, query),
        orElse: () => const <String, Object?>{},
      );
      if (matched.isEmpty) {
        throw InboundNotificationException('Пользователь "$query" не найден в каталоге.');
      }
      final key = matched['id']?.toString() ?? matched['username']?.toString() ?? query;
      if (seen.add(key)) {
        resolved.add(matched);
      }
    }
    return resolved;
  }

  Future<List<Map<String, Object?>>> _resolveGroups({
    required AppSettings settings,
    required List<Object?> values,
  }) async {
    final service = audienceService;
    if (service == null) {
      throw InboundNotificationException('Сервис каталога аудитории не подключён.');
    }
    final resolved = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final value in values) {
      if (value is Map) {
        final mapped = Map<String, Object?>.from(value);
        final key = mapped['id']?.toString() ?? mapped['name']?.toString() ?? '';
        if (key.isNotEmpty && seen.add(key)) {
          resolved.add(mapped);
        }
        continue;
      }

      final query = value?.toString().trim() ?? '';
      if (query.isEmpty) {
        continue;
      }
      final items = await service.searchAudience(settings: settings, query: query);
      final matched = items.firstWhere(
        (item) => item['kind'] == 'group' && _matchesGroup(item, query),
        orElse: () => const <String, Object?>{},
      );
      if (matched.isEmpty) {
        throw InboundNotificationException('Группа "$query" не найдена в каталоге.');
      }
      final key = matched['id']?.toString() ?? matched['name']?.toString() ?? query;
      if (seen.add(key)) {
        resolved.add(matched);
      }
    }
    return resolved;
  }

  bool _matchesUser(Map<String, Object?> user, String query) {
    final normalized = query.trim().toLowerCase();
    return (user['id']?.toString().toLowerCase() ?? '') == normalized ||
        (user['username']?.toString().toLowerCase() ?? '') == normalized ||
        (user['email']?.toString().toLowerCase() ?? '') == normalized ||
        (user['displayName']?.toString().toLowerCase() ?? '') == normalized;
  }

  bool _matchesGroup(Map<String, Object?> group, String query) {
    final normalized = query.trim().toLowerCase();
    return (group['id']?.toString().toLowerCase() ?? '') == normalized ||
        (group['name']?.toString().toLowerCase() ?? '') == normalized ||
        (group['displayName']?.toString().toLowerCase() ?? '') == normalized;
  }

  List<Object?> _toObjectList(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
  }

  List<String> _toStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, Object?> _firstAlert(Map<String, Object?> payload) {
    final alerts = payload['alerts'];
    if (alerts is List && alerts.isNotEmpty && alerts.first is Map) {
      return Map<String, Object?>.from(alerts.first as Map);
    }
    return const <String, Object?>{};
  }
}
