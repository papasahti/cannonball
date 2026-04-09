import 'dart:io';

import 'package:cannonball/src/database.dart';
import 'package:test/test.dart';

void main() {
  test('listCampaigns includes inbound trigger metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cannonball-history-',
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
      messageTemplate: '[n8n] {{message}}',
      enabled: true,
    );

    final manualCampaignId = database.insertCampaign(
      createdAt: DateTime.now().toUtc(),
      createdBy: 'admin',
      message: 'Manual launch',
      users: const [],
      groups: const [],
      channels: const ['ops'],
    );

    final inboundCampaignId = database.insertCampaign(
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
      campaignId: inboundCampaignId,
      payload: const {'message': 'Inbound launch'},
    );

    final items = database.listCampaigns(limit: 10);
    final manual = items.firstWhere((item) => item['id'] == manualCampaignId);
    final inbound = items.firstWhere((item) => item['id'] == inboundCampaignId);

    expect(manual['trigger'], {'kind': 'manual'});
    expect(inbound['trigger'], {
      'kind': 'inbound',
      'source': 'n8n',
      'eventType': 'notification',
      'requestId': 'evt-001',
      'ruleId': ruleId,
      'ruleName': 'Critical incidents',
      'status': 'sent',
      'errorMessage': null,
    });

    database.close();
    await tempDir.delete(recursive: true);
  });
}
