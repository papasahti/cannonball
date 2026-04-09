import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'settings_service.dart';
import 'targeting.dart';

class DeliveryRouterException implements Exception {
  DeliveryRouterException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final String? details;

  @override
  String toString() => message;
}

abstract class DeliveryRouter {
  String get key;

  Future<Map<String, Object?>> deliverTarget({
    required AuthenticatedUser sender,
    required TargetCandidate target,
    required String message,
  });
}

class MattermostDeliveryRouter implements DeliveryRouter {
  MattermostDeliveryRouter({required this.platformKey, required this.dispatch});

  final String platformKey;
  final Future<Map<String, Object?>> Function({
    required TargetCandidate target,
    required String message,
  })
  dispatch;

  @override
  String get key => platformKey;

  @override
  Future<Map<String, Object?>> deliverTarget({
    required AuthenticatedUser sender,
    required TargetCandidate target,
    required String message,
  }) {
    return dispatch(target: target, message: message);
  }
}

class N8nDeliveryRouter implements DeliveryRouter {
  N8nDeliveryRouter({required this.settings, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final AppSettings settings;
  final http.Client _httpClient;

  @override
  String get key => 'n8n';

  @override
  Future<Map<String, Object?>> deliverTarget({
    required AuthenticatedUser sender,
    required TargetCandidate target,
    required String message,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (settings.n8nApiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.n8nApiKey}';
    }
    if (settings.n8nWebhookSecret.isNotEmpty) {
      headers['X-Webhook-Secret'] = settings.n8nWebhookSecret;
    }

    final response = await _httpClient.post(
      Uri.parse(settings.n8nWebhookUrl),
      headers: headers,
      body: jsonEncode({
        'message': message,
        'target': target.toJson(),
        'sender': sender.toJson(),
        'source': 'cannonball',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeliveryRouterException(
        'n8n webhook failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    return {
      'statusCode': response.statusCode,
      'response': _decodeResponseBody(response.body),
    };
  }
}

Object? _decodeResponseBody(String body) {
  if (body.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(body);
  } catch (_) {
    return body;
  }
}
