import 'dart:io';

import 'package:cannonball/src/database.dart';
import 'package:test/test.dart';

void main() {
  test('listInboundEvents returns recent inbound events with rule names', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cannonball-inbound-events-',
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

    database.insertInboundEvent(
      source: 'n8n',
      eventType: 'notification',
      requestId: 'evt-001',
      status: 'failed',
      ruleId: ruleId,
      errorMessage: 'Webhook failed',
      payload: const {'title': 'Billing', 'message': 'Service is down'},
    );

    final items = database.listInboundEvents(limit: 10, source: 'n8n');

    expect(items, hasLength(1));
    expect(items.single['ruleName'], 'Critical incidents');
    expect(items.single['requestId'], 'evt-001');
    expect(items.single['status'], 'failed');
    expect(items.single['message'], 'Service is down');

    database.close();
    await tempDir.delete(recursive: true);
  });
}
