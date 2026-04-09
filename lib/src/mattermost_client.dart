import 'dart:convert';

import 'package:http/http.dart' as http;

class MattermostApiException implements Exception {
  MattermostApiException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() => message;
}

class MattermostUser {
  MattermostUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
  });

  final String id;
  final String username;
  final String displayName;
  final String email;

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'email': email,
  };
}

class MattermostChannel {
  MattermostChannel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
  });

  final String id;
  final String name;
  final String displayName;
  final String type;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'displayName': displayName,
    'type': type,
  };
}

class MattermostGroup {
  MattermostGroup({
    required this.id,
    required this.name,
    required this.displayName,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String displayName;
  final int memberCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'displayName': displayName,
    'memberCount': memberCount,
  };
}

class MattermostClient {
  MattermostClient({
    required this.baseUrl,
    required this.token,
    required this.teamId,
    required this.teamName,
    required this.configuredChannels,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String token;
  final String? teamId;
  final String? teamName;
  final List<String> configuredChannels;
  final http.Client _httpClient;

  String? _botUserId;
  String? _resolvedTeamId;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<List<MattermostUser>> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      return listUsers();
    }
    final response = await _post(
      '/api/v4/users/search',
      body: {'term': query.trim(), 'allow_inactive': false},
    );
    final payload = _decodeList(response);
    return payload.map(_parseUser).toList(growable: false);
  }

  Future<List<MattermostUser>> listUsers() async {
    final results = <MattermostUser>[];
    var page = 0;
    while (true) {
      final response = await _get('/api/v4/users?page=$page&per_page=200');
      final payload = _decodeList(response);
      if (payload.isEmpty) {
        break;
      }
      results.addAll(payload.map(_parseUser));
      if (payload.length < 200) {
        break;
      }
      page += 1;
    }
    return results;
  }

  Future<List<MattermostChannel>> listDirectoryChannels() async {
    final results = <MattermostChannel>[];
    final seen = <String>{};
    final resolvedTeamId = await _ensureTeamId();

    for (final channel in configuredChannels) {
      if (seen.add(channel.toLowerCase())) {
        results.add(
          MattermostChannel(
            id: channel,
            name: channel,
            displayName: channel,
            type: '',
          ),
        );
      }
    }

    if (resolvedTeamId == null) {
      return results;
    }

    var page = 0;
    while (true) {
      final response = await _get(
        '/api/v4/teams/$resolvedTeamId/channels?page=$page&per_page=200',
      );
      final payload = _decodeList(response);
      if (payload.isEmpty) {
        break;
      }
      for (final item in payload) {
        final channel = _parseChannel(item);
        if (seen.add(channel.name.toLowerCase())) {
          results.add(channel);
        }
      }
      if (payload.length < 200) {
        break;
      }
      page += 1;
    }

    final memberResponse = await _get(
      '/api/v4/users/me/teams/$resolvedTeamId/channels',
    );
    final memberPayload = _decodeList(memberResponse);
    for (final item in memberPayload) {
      final channel = _parseChannel(item);
      if (seen.add(channel.name.toLowerCase())) {
        results.add(channel);
      }
    }

    return results;
  }

  Future<List<MattermostChannel>> searchChannels(String query) async {
    final normalizedQuery = query.trim().replaceFirst('#', '');
    final results = <MattermostChannel>[];
    final seen = <String>{};

    for (final channel in configuredChannels) {
      if (normalizedQuery.isEmpty ||
          channel.toLowerCase().contains(normalizedQuery.toLowerCase())) {
        if (seen.add(channel.toLowerCase())) {
          results.add(
            MattermostChannel(
              id: channel,
              name: channel,
              displayName: channel,
              type: '',
            ),
          );
        }
      }
    }

    final resolvedTeamId = await _ensureTeamId();
    if (resolvedTeamId == null) {
      return results;
    }

    final response = await _get(
      '/api/v4/teams/$resolvedTeamId/channels?page=0&per_page=100',
    );
    final payload = _decodeList(response);
    for (final item in payload) {
      final channel = _parseChannel(item);
      if (normalizedQuery.isEmpty ||
          channel.name.toLowerCase().contains(normalizedQuery.toLowerCase()) ||
          channel.displayName.toLowerCase().contains(
            normalizedQuery.toLowerCase(),
          )) {
        if (seen.add(channel.name.toLowerCase())) {
          results.add(channel);
        }
      }
    }
    return results;
  }

  Future<List<MattermostGroup>> searchGroups(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    try {
      final response = await _get('/api/v4/groups?page=0&per_page=100');
      final payload = _decodeList(response);
      return payload
          .map(_parseGroup)
          .where((group) {
            if (normalizedQuery.isEmpty) {
              return true;
            }
            return group.name.toLowerCase().contains(normalizedQuery) ||
                group.displayName.toLowerCase().contains(normalizedQuery);
          })
          .toList(growable: false);
    } on MattermostApiException catch (error) {
      if (error.statusCode == 403 ||
          error.statusCode == 404 ||
          error.statusCode == 501) {
        return const <MattermostGroup>[];
      }
      rethrow;
    }
  }

  Future<List<MattermostGroup>> listGroups() async {
    final results = <MattermostGroup>[];
    var page = 0;
    while (true) {
      try {
        final response = await _get('/api/v4/groups?page=$page&per_page=200');
        final payload = _decodeList(response);
        if (payload.isEmpty) {
          break;
        }
        results.addAll(payload.map(_parseGroup));
        if (payload.length < 200) {
          break;
        }
        page += 1;
      } on MattermostApiException catch (error) {
        if (error.statusCode == 403 ||
            error.statusCode == 404 ||
            error.statusCode == 501) {
          return const <MattermostGroup>[];
        }
        rethrow;
      }
    }
    return results;
  }

  Future<List<MattermostUser>> listGroupMembers(String groupId) async {
    try {
      final response = await _get('/api/v4/groups/$groupId/members');
      final payload = _decodeList(response);
      return payload.map(_parseUser).toList(growable: false);
    } on MattermostApiException catch (error) {
      if (error.statusCode == 403 ||
          error.statusCode == 404 ||
          error.statusCode == 501) {
        return const <MattermostUser>[];
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> sendDirectMessage({
    required String userId,
    required String message,
  }) async {
    final botUserId = await _ensureBotUserId();
    final channelResponse = await _post(
      '/api/v4/channels/direct',
      body: [botUserId, userId],
    );
    final channel = _decodeMap(channelResponse);
    final post = await _createPost(
      channelId: channel['id'] as String,
      message: message,
    );
    return {'channelId': channel['id'], 'postId': post['id']};
  }

  Future<Map<String, Object?>> sendChannelMessage({
    required String channelName,
    required String message,
  }) async {
    final channelId = await resolveChannelId(channelName);
    final post = await _createPost(channelId: channelId, message: message);
    return {'channelId': channelId, 'postId': post['id']};
  }

  Future<String> resolveChannelId(String channelName) async {
    final normalized = channelName.trim().replaceFirst('#', '');
    final resolvedTeamId = await _ensureTeamId();
    if (resolvedTeamId == null) {
      throw MattermostApiException(
        'MATTERMOST_TEAM_ID or MATTERMOST_TEAM_NAME is required for channel delivery.',
      );
    }
    final response = await _get(
      '/api/v4/teams/$resolvedTeamId/channels/name/$normalized',
    );
    final payload = _decodeMap(response);
    final id = payload['id'] as String?;
    if (id == null || id.isEmpty) {
      throw MattermostApiException('Channel $normalized not found.');
    }
    return id;
  }

  Future<String> _ensureBotUserId() async {
    if (_botUserId != null) {
      return _botUserId!;
    }
    final response = await _get('/api/v4/users/me');
    final payload = _decodeMap(response);
    final id = payload['id'] as String?;
    if (id == null || id.isEmpty) {
      throw MattermostApiException('Unable to resolve bot user id.');
    }
    _botUserId = id;
    return id;
  }

  Future<String?> _ensureTeamId() async {
    if (_resolvedTeamId != null) {
      return _resolvedTeamId;
    }
    if (teamId != null && teamId!.isNotEmpty) {
      _resolvedTeamId = teamId;
      return _resolvedTeamId;
    }
    if (teamName == null || teamName!.isEmpty) {
      return null;
    }
    final response = await _get('/api/v4/teams/name/$teamName');
    final payload = _decodeMap(response);
    _resolvedTeamId = payload['id'] as String?;
    return _resolvedTeamId;
  }

  Future<Map<String, Object?>> _createPost({
    required String channelId,
    required String message,
  }) async {
    final response = await _post(
      '/api/v4/posts',
      body: {'channel_id': channelId, 'message': message},
    );
    return _decodeMap(response);
  }

  Future<http.Response> _get(String path) async {
    _ensureConfigured();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.get(uri, headers: _headers);
    _throwIfNeeded(response);
    return response;
  }

  Future<http.Response> _post(String path, {required Object body}) async {
    _ensureConfigured();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    _throwIfNeeded(response);
    return response;
  }

  void _throwIfNeeded(http.Response response) {
    if (response.statusCode >= 400) {
      throw MattermostApiException(
        'Mattermost API request failed.',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  void _ensureConfigured() {
    if (baseUrl.trim().isEmpty || token.trim().isEmpty) {
      throw MattermostApiException(
        'Mattermost integration is not configured in the admin console.',
      );
    }
  }

  List<Map<String, Object?>> _decodeList(http.Response response) {
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList(growable: false);
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    return Map<String, Object?>.from(jsonDecode(response.body) as Map);
  }

  MattermostUser _parseUser(Map<String, Object?> item) {
    final firstName = (item['first_name'] as String?)?.trim() ?? '';
    final lastName = (item['last_name'] as String?)?.trim() ?? '';
    final displayName = [
      firstName,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ').trim();
    return MattermostUser(
      id: item['id'] as String,
      username: item['username'] as String,
      displayName: displayName.isEmpty
          ? ((item['nickname'] as String?)?.trim().isNotEmpty == true
                ? (item['nickname'] as String).trim()
                : item['username'] as String)
          : displayName,
      email: (item['email'] as String?)?.trim() ?? '',
    );
  }

  MattermostChannel _parseChannel(Map<String, Object?> item) {
    return MattermostChannel(
      id: item['id'] as String,
      name: item['name'] as String,
      displayName: (item['display_name'] as String?)?.trim().isNotEmpty == true
          ? item['display_name'] as String
          : item['name'] as String,
      type: (item['type'] as String? ?? '').trim(),
    );
  }

  MattermostGroup _parseGroup(Map<String, Object?> item) {
    final name = (item['name'] as String?)?.trim() ?? '';
    final displayName = (item['display_name'] as String?)?.trim() ?? '';
    return MattermostGroup(
      id: item['id'] as String,
      name: name,
      displayName: displayName.isNotEmpty ? displayName : name,
      memberCount: (item['member_count'] as num?)?.toInt() ?? 0,
    );
  }
}
