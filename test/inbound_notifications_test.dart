import 'package:cannonball/src/inbound_notifications.dart';
import 'package:test/test.dart';

void main() {
  group('InboundNotificationService', () {
    final service = InboundNotificationService();

    test('normalizeEvent trims source, channels and labels', () {
      final event = service.normalizeEvent(
        source: ' N8N ',
        payload: {
          'event_type': ' notification ',
          'title': ' Billing ',
          'message': ' Service is down ',
          'channels': ['#alerts', ' ops '],
          'labels': {
            'service': ' billing ',
            'severity': ' critical ',
            'empty': '   ',
          },
          'request_id': ' evt-001 ',
        },
      );

      expect(event.source, 'n8n');
      expect(event.eventType, 'notification');
      expect(event.title, 'Billing');
      expect(event.message, 'Service is down');
      expect(event.channels, ['alerts', 'ops']);
      expect(event.labels, {'service': 'billing', 'severity': 'critical'});
      expect(event.requestId, 'evt-001');
    });

    test('selectRule prefers explicit rule key', () {
      final event = service.normalizeEvent(
        source: 'n8n',
        payload: {
          'rule_key': 'incident-critical',
          'message': 'Billing down',
        },
      );

      final rule = service.selectRule(event, [
        {
          'id': 1,
          'source': 'n8n',
          'ruleKey': 'incident-critical',
          'eventType': '',
          'severity': '',
          'containsText': '',
          'labelFilters': const <String, Object?>{},
        },
      ]);

      expect(rule?['id'], 1);
    });

    test('selectRule matches by event type, severity, text and labels', () {
      final event = service.normalizeEvent(
        source: 'n8n',
        payload: {
          'event_type': 'notification',
          'title': 'Billing incident',
          'message': 'Billing API is unavailable',
          'labels': {
            'service': 'billing',
            'severity': 'critical',
            'env': 'prod',
          },
        },
      );

      final rule = service.selectRule(event, [
        {
          'id': 7,
          'source': 'n8n',
          'ruleKey': '',
          'eventType': 'notification',
          'severity': 'critical',
          'containsText': 'billing',
          'labelFilters': {'env': 'prod'},
        },
      ]);

      expect(rule?['id'], 7);
    });

    test('renderMessage applies template variables', () {
      final event = service.normalizeEvent(
        source: 'n8n',
        payload: {
          'title': 'Billing',
          'message': 'Service is down',
          'labels': {'severity': 'critical'},
        },
      );

      final rendered = service.renderMessage(event, {
        'messageTemplate': '[{{severity}}] {{title}}: {{message}}',
      });

      expect(rendered, '[critical] Billing: Service is down');
    });

    test('normalizeAlertmanagerEvent maps common payload fields', () {
      final event = service.normalizeAlertmanagerEvent({
        'status': 'firing',
        'groupKey': '{}:{alertname="HighCPU"}',
        'title': '[FIRING:1] High CPU',
        'message': 'CPU usage is above threshold',
        'commonLabels': {
          'severity': 'critical',
          'service': 'billing',
        },
        'alerts': [
          {
            'fingerprint': 'abc-123',
            'labels': {'alertname': 'HighCPU'},
            'annotations': {'summary': 'Billing CPU is high'},
          },
        ],
      });

      expect(event.source, 'alertmanager');
      expect(event.eventType, 'firing');
      expect(event.title, '[FIRING:1] High CPU');
      expect(event.message, 'CPU usage is above threshold');
      expect(event.requestId, '{}:{alertname="HighCPU"}');
      expect(event.labels['severity'], 'critical');
      expect(event.labels['service'], 'billing');
      expect(event.labels['alertname'], 'HighCPU');
      expect(event.labels['status'], 'firing');
    });
  });
}
