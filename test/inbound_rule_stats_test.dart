import 'dart:io';

import 'package:cannonball/src/database.dart';
import 'package:test/test.dart';

void main() {
  test('listInboundRules returns trigger statistics', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cannonball-rule-stats-',
    );
    final database = AppDatabase(databasePath: '${tempDir.path}/test.db');
    database.initialize();

    final ruleId = database.insertInboundRule(
      name: 'Critical incidents',
      source: 'n8n',
      eventType: 'notification',
      ruleKey: 'incident-critical',
      severity: '',
      containsText: '',
      labelFilters: const {},
      users: const [],
      groups: const [],
      channels: const ['alerts'],
      messageTemplate: '',
      enabled: true,
    );

    final campaignId = database.insertCampaign(
      createdAt: DateTime.now().toUtc(),
      createdBy: 'n8n',
      message: 'Inbound launch',
      users: const [],
      groups: const [],
      channels: const ['alerts'],
    );

    database.insertInboundEvent(
      source: 'n8n',
      eventType: 'notification',
      requestId: 'evt-001',
      status: 'sent',
      ruleId: ruleId,
      campaignId: campaignId,
      payload: const {'message': 'Inbound launch'},
    );
    database.insertInboundEvent(
      source: 'n8n',
      eventType: 'notification',
      requestId: 'evt-002',
      status: 'failed',
      ruleId: ruleId,
      errorMessage: 'Webhook failed',
      payload: const {'message': 'Inbound launch'},
    );

    final rule = database.listInboundRules().single;

    expect(rule['totalRuns'], 2);
    expect(rule['failedRuns'], 1);
    expect(rule['lastTriggeredAt'], isNotNull);

    database.close();
    await tempDir.delete(recursive: true);
  });
}
