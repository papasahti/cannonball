import 'dart:convert';
import 'dart:io';

import 'package:cannonball/src/app_server.dart';
import 'package:cannonball/src/auth_service.dart';
import 'package:cannonball/src/config.dart';
import 'package:cannonball/src/database.dart';
import 'package:cannonball/src/settings_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('n8n inbound API', () {
    late _TestHarness harness;
    late HttpServer webhookServer;
    late List<Map<String, Object?>> webhookRequests;

    setUp(() async {
      webhookRequests = [];
      webhookServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      webhookServer.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        webhookRequests.add(jsonDecode(body) as Map<String, Object?>);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'ok': true}));
        await request.response.close();
      });

      harness = await _TestHarness.create(
        webhookUrl:
            'http://127.0.0.1:${webhookServer.port}/n8n-webhook',
      );
    });

    tearDown(() async {
      await webhookServer.close(force: true);
      await harness.close();
    });

    test('rejects request with invalid inbound secret', () async {
      final response = await harness.postInbound(
        payload: {
          'message': 'Smoke',
          'channels': ['alerts'],
        },
        secret: 'wrong-secret',
      );

      expect(response.statusCode, HttpStatus.unauthorized);
      expect(response.body['ok'], false);
    });

    test('rejects payload without message and rule', () async {
      final response = await harness.postInbound(
        payload: {
          'channels': ['alerts'],
          'request_id': 'evt-empty',
        },
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(response.body['error'], contains('message'));
    });

    test('delivers direct inbound event to n8n router', () async {
      final response = await harness.postInbound(
        payload: {
          'message': 'Direct inbound test',
          'channels': ['alerts'],
          'request_id': 'evt-direct',
        },
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body['ok'], true);
      expect(response.body['sent'], 1);
      expect(webhookRequests, hasLength(1));
      expect(webhookRequests.single['message'], 'Direct inbound test');
    });

    test('returns duplicate response for repeated request_id', () async {
      await harness.postInbound(
        payload: {
          'message': 'Duplicate test',
          'channels': ['alerts'],
          'request_id': 'evt-duplicate',
        },
      );

      final secondResponse = await harness.postInbound(
        payload: {
          'message': 'Duplicate test',
          'channels': ['alerts'],
          'request_id': 'evt-duplicate',
        },
      );

      expect(secondResponse.statusCode, HttpStatus.ok);
      expect(secondResponse.body['duplicate'], true);
      expect(webhookRequests, hasLength(1));
    });

    test('delivers event by rule key', () async {
      harness.database.insertInboundRule(
        name: 'Critical incidents',
        source: 'n8n',
        ruleKey: 'incident-critical',
        eventType: 'notification',
        severity: '',
        containsText: '',
        labelFilters: const {},
        users: const [],
        groups: const [],
        channels: const ['alerts'],
        messageTemplate: '[n8n] {{message}}',
        enabled: true,
      );

      final response = await harness.postInbound(
        payload: {
          'rule_key': 'incident-critical',
          'message': 'Billing is down',
          'event_type': 'notification',
          'request_id': 'evt-rule',
        },
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body['ruleName'], 'Critical incidents');
      expect(webhookRequests.single['message'], '[n8n] Billing is down');
    });

    test('returns error when rule is not found', () async {
      final response = await harness.postInbound(
        payload: {
          'rule_key': 'missing-rule',
          'message': 'Billing is down',
          'request_id': 'evt-missing-rule',
        },
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(response.body['ok'], false);
      expect(response.body['error'], contains('не найдено'));
    });

    test('delivers alertmanager event by direct channel', () async {
      final response = await harness.postAlertmanager(
        payload: {
          'status': 'firing',
          'groupKey': 'alert-group-1',
          'title': '[FIRING:1] Billing API',
          'message': 'Billing API is unavailable',
          'commonLabels': {
            'severity': 'critical',
            'service': 'billing',
          },
          'channels': ['alerts'],
          'alerts': [
            {
              'fingerprint': 'fp-1',
              'labels': {'alertname': 'BillingDown'},
              'annotations': {'summary': 'Billing API is unavailable'},
            },
          ],
        },
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body['ok'], true);
      expect(response.body['source'], 'alertmanager');
      expect(webhookRequests.last['message'], 'Billing API is unavailable');
    });
  });
}

class _InboundResponse {
  _InboundResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, Object?> body;
}

class _TestHarness {
  _TestHarness({
    required this.tempDir,
    required this.database,
    required this.handler,
    required this.secret,
  });

  final Directory tempDir;
  final AppDatabase database;
  final Handler handler;
  final String secret;

  static Future<_TestHarness> create({
    required String webhookUrl,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('cannonball-inbound-');
    final webRoot = Directory('${tempDir.path}/web')..createSync(recursive: true);
    File('${webRoot.path}/index.html').writeAsStringSync('<!doctype html><html></html>');

    final database = AppDatabase(databasePath: '${tempDir.path}/cannonball.db');
    database.initialize();
    database.ensureBootstrapAdmin(
      username: 'admin',
      displayName: 'Admin',
      email: 'admin@example.com',
      passwordHash: AuthService.hashPassword('testpass123'),
    );

    const inboundSecret = 'test-inbound-secret';
    final config = AppConfig(
      port: 8080,
      databaseDriver: 'sqlite',
      databasePath: '${tempDir.path}/cannonball.db',
      databaseUrl: null,
      bootstrapAdminUsername: 'admin',
      bootstrapAdminDisplayName: 'Admin',
      bootstrapAdminPassword: 'testpass123',
      bootstrapAdminPasswordHash: null,
      forceBootstrapAdminPasswordSync: false,
      sessionTtl: const Duration(hours: 12),
      secureCookies: false,
      defaultAppTitle: 'cannonball',
      defaultDeliveryMode: 'n8n',
      defaultMattermostBaseUrl: null,
      defaultMattermostToken: null,
      defaultMattermostTeamId: null,
      defaultMattermostTeamName: null,
      defaultChannels: const [],
      defaultN8nBaseUrl: null,
      defaultN8nWebhookUrl: webhookUrl,
      defaultN8nApiKey: null,
      defaultN8nWebhookSecret: null,
      defaultN8nInboundSecret: inboundSecret,
      bootstrapAdminEmail: 'admin@example.com',
      defaultPublicBaseUrl: 'http://127.0.0.1:8080',
      defaultSmtpHost: null,
      defaultSmtpPort: 587,
      defaultSmtpUsername: null,
      defaultSmtpPassword: null,
      defaultSmtpFromEmail: null,
      defaultSmtpFromName: null,
      defaultSmtpUseSsl: false,
      defaultAuthMode: 'local',
      defaultKeycloakIssuerUrl: null,
      defaultKeycloakClientId: null,
      defaultKeycloakClientSecret: null,
      defaultKeycloakScopes: 'openid profile email',
      defaultKeycloakAdminRole: 'cannonball-admin',
      webRoot: webRoot.path,
    );

    final authService = AuthService(
      database: database,
      sessionTtl: const Duration(hours: 12),
      secureCookies: false,
    );
    final settingsService = SettingsService(database: database, config: config);
    settingsService.updateFromPayload({
      'deliveryMode': 'n8n',
      'n8nWebhookUrl': webhookUrl,
      'n8nInboundSecret': inboundSecret,
    });

    final handler = createHandler(
      config: config,
      database: database,
      authService: authService,
      settingsService: settingsService,
      webRoot: webRoot,
    );

    return _TestHarness(
      tempDir: tempDir,
      database: database,
      handler: handler,
      secret: inboundSecret,
    );
  }

  Future<_InboundResponse> postInbound({
    required Map<String, Object?> payload,
    String? secret,
  }) async {
    return _postJson(
      path: '/api/incoming/n8n',
      payload: payload,
      secret: secret,
    );
  }

  Future<_InboundResponse> postAlertmanager({
    required Map<String, Object?> payload,
    String? secret,
  }) async {
    return _postJson(
      path: '/api/incoming/alertmanager',
      payload: payload,
      secret: secret,
    );
  }

  Future<_InboundResponse> _postJson({
    required String path,
    required Map<String, Object?> payload,
    String? secret,
  }) async {
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost$path'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer ${secret ?? this.secret}',
        },
        body: jsonEncode(payload),
      ),
    );

    return _InboundResponse(
      statusCode: response.statusCode,
      body: jsonDecode(await response.readAsString()) as Map<String, Object?>,
    );
  }

  Future<void> close() async {
    database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}
