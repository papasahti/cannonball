import 'dart:convert';

import 'package:http/http.dart' as http;

class KeycloakException implements Exception {
  KeycloakException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() => message;
}

class KeycloakDiscovery {
  KeycloakDiscovery({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
    required this.endSessionEndpoint,
  });

  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String userInfoEndpoint;
  final String? endSessionEndpoint;
}

class KeycloakProfile {
  KeycloakProfile({
    required this.subject,
    required this.username,
    required this.displayName,
    required this.email,
    required this.roles,
  });

  final String subject;
  final String username;
  final String displayName;
  final String email;
  final List<String> roles;
}

class KeycloakAuthResult {
  KeycloakAuthResult({required this.profile, required this.idToken});

  final KeycloakProfile profile;
  final String? idToken;
}

class KeycloakService {
  KeycloakService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, KeycloakDiscovery> _discoveryCache = {};

  Future<KeycloakDiscovery> discover(String issuerUrl) async {
    final normalizedIssuer = issuerUrl.trim().replaceAll(RegExp(r'/$'), '');
    final cached = _discoveryCache[normalizedIssuer];
    if (cached != null) {
      return cached;
    }

    final response = await _httpClient.get(
      Uri.parse('$normalizedIssuer/.well-known/openid-configuration'),
    );
    if (response.statusCode >= 400) {
      throw KeycloakException(
        'Не удалось получить конфигурацию Keycloak.',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final payload = Map<String, Object?>.from(jsonDecode(response.body) as Map);
    final discovery = KeycloakDiscovery(
      authorizationEndpoint: payload['authorization_endpoint'] as String,
      tokenEndpoint: payload['token_endpoint'] as String,
      userInfoEndpoint: payload['userinfo_endpoint'] as String,
      endSessionEndpoint: payload['end_session_endpoint'] as String?,
    );
    _discoveryCache[normalizedIssuer] = discovery;
    return discovery;
  }

  Uri buildAuthorizationUrl({
    required KeycloakDiscovery discovery,
    required String clientId,
    required String redirectUri,
    required String state,
    required String scopes,
  }) {
    return Uri.parse(discovery.authorizationEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes,
        'state': state,
      },
    );
  }

  Future<KeycloakAuthResult> exchangeCode({
    required KeycloakDiscovery discovery,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    required String code,
  }) async {
    final tokenResponse = await _httpClient.post(
      Uri.parse(discovery.tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'code': code,
      },
    );

    if (tokenResponse.statusCode >= 400) {
      throw KeycloakException(
        'Не удалось обменять код авторизации на токен.',
        statusCode: tokenResponse.statusCode,
        body: tokenResponse.body,
      );
    }

    final tokenPayload = Map<String, Object?>.from(
      jsonDecode(tokenResponse.body) as Map,
    );
    final accessToken = tokenPayload['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw KeycloakException('Keycloak не вернул access_token.');
    }

    final userInfoResponse = await _httpClient.get(
      Uri.parse(discovery.userInfoEndpoint),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (userInfoResponse.statusCode >= 400) {
      throw KeycloakException(
        'Не удалось получить профиль пользователя из Keycloak.',
        statusCode: userInfoResponse.statusCode,
        body: userInfoResponse.body,
      );
    }

    final userInfo = Map<String, Object?>.from(
      jsonDecode(userInfoResponse.body) as Map,
    );
    final claims = _decodeJwtClaims(accessToken);
    return KeycloakAuthResult(
      profile: _mapProfile(userInfo, claims: claims),
      idToken: tokenPayload['id_token'] as String?,
    );
  }

  Uri? buildLogoutUrl({
    required KeycloakDiscovery discovery,
    required String clientId,
    required String postLogoutRedirectUri,
  }) {
    final endpoint = discovery.endSessionEndpoint;
    if (endpoint == null || endpoint.isEmpty) {
      return null;
    }
    return Uri.parse(endpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'post_logout_redirect_uri': postLogoutRedirectUri,
      },
    );
  }

  KeycloakProfile _mapProfile(
    Map<String, Object?> userInfo, {
    required Map<String, Object?> claims,
  }) {
    final username =
        (userInfo['preferred_username'] as String?)?.trim().isNotEmpty == true
        ? (userInfo['preferred_username'] as String).trim()
        : ((userInfo['email'] as String?)?.split('@').first ?? 'user');
    final displayName =
        (userInfo['name'] as String?)?.trim().isNotEmpty == true
        ? (userInfo['name'] as String).trim()
        : [
            (userInfo['given_name'] as String?)?.trim() ?? '',
            (userInfo['family_name'] as String?)?.trim() ?? '',
          ].where((item) => item.isNotEmpty).join(' ').trim();
    return KeycloakProfile(
      subject: (userInfo['sub'] as String?)?.trim() ?? '',
      username: username,
      displayName: displayName.isEmpty ? username : displayName,
      email: (userInfo['email'] as String?)?.trim() ?? '',
      roles: _extractRoles(claims),
    );
  }

  Map<String, Object?> _decodeJwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return <String, Object?>{};
    }
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return Map<String, Object?>.from(jsonDecode(decoded) as Map);
  }

  List<String> _extractRoles(Map<String, Object?> claims) {
    final roles = <String>{};
    final realmAccess = claims['realm_access'];
    if (realmAccess is Map && realmAccess['roles'] is List) {
      roles.addAll((realmAccess['roles'] as List).map((item) => '$item'));
    }
    final resourceAccess = claims['resource_access'];
    if (resourceAccess is Map) {
      for (final value in resourceAccess.values) {
        if (value is Map && value['roles'] is List) {
          roles.addAll((value['roles'] as List).map((item) => '$item'));
        }
      }
    }
    return roles.toList(growable: false);
  }
}
