import 'auth_service.dart';
import 'mattermost_client.dart';

class MessagingPlatformException implements Exception {
  MessagingPlatformException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final String? details;

  @override
  String toString() => message;
}

class PlatformUser {
  PlatformUser({
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

class PlatformGroup {
  PlatformGroup({
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

class PlatformChannel {
  PlatformChannel({
    required this.id,
    required this.name,
    required this.displayName,
  });

  final String id;
  final String name;
  final String displayName;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'displayName': displayName,
  };
}

abstract class MessagingPlatformAdapter {
  String get key;

  Future<List<PlatformUser>> searchUsers(String query);

  Future<List<PlatformGroup>> searchGroups(String query);

  Future<List<PlatformChannel>> searchChannels(String query);

  Future<List<PlatformUser>> listGroupMembers(String groupId);

  Future<Map<String, Object?>> sendDirectMessage({
    required String userId,
    required String message,
  });

  Future<Map<String, Object?>> sendChannelMessage({
    required String channelName,
    required String message,
  });
}

class MattermostMessagingPlatformAdapter implements MessagingPlatformAdapter {
  MattermostMessagingPlatformAdapter(this._client);

  final MattermostClient _client;

  @override
  String get key => 'mattermost';

  @override
  Future<List<PlatformUser>> listGroupMembers(String groupId) async {
    try {
      final members = await _client.listGroupMembers(groupId);
      return members.map(_mapUser).toList(growable: false);
    } on MattermostApiException catch (error) {
      throw MessagingPlatformException(
        error.message,
        statusCode: error.statusCode,
        details: error.body,
      );
    }
  }

  @override
  Future<List<PlatformChannel>> searchChannels(String query) async {
    try {
      final channels = await _client.searchChannels(query);
      return channels.map(_mapChannel).toList(growable: false);
    } on MattermostApiException catch (error) {
      throw MessagingPlatformException(
        error.message,
        statusCode: error.statusCode,
        details: error.body,
      );
    }
  }

  @override
  Future<List<PlatformGroup>> searchGroups(String query) async {
    try {
      final groups = await _client.searchGroups(query);
      return groups.map(_mapGroup).toList(growable: false);
    } on MattermostApiException catch (error) {
      throw MessagingPlatformException(
        error.message,
        statusCode: error.statusCode,
        details: error.body,
      );
    }
  }

  @override
  Future<List<PlatformUser>> searchUsers(String query) async {
    try {
      final users = await _client.searchUsers(query);
      return users.map(_mapUser).toList(growable: false);
    } on MattermostApiException catch (error) {
      throw MessagingPlatformException(
        error.message,
        statusCode: error.statusCode,
        details: error.body,
      );
    }
  }

  @override
  Future<Map<String, Object?>> sendChannelMessage({
    required String channelName,
    required String message,
  }) async {
    try {
      return await _client.sendChannelMessage(
        channelName: channelName,
        message: message,
      );
    } on MattermostApiException catch (error) {
      throw MessagingPlatformException(
        error.message,
        statusCode: error.statusCode,
        details: error.body,
      );
    }
  }

  @override
  Future<Map<String, Object?>> sendDirectMessage({
    required String userId,
    required String message,
  }) async {
    try {
      return await _client.sendDirectMessage(userId: userId, message: message);
    } on MattermostApiException catch (error) {
      throw MessagingPlatformException(
        error.message,
        statusCode: error.statusCode,
        details: error.body,
      );
    }
  }

  PlatformChannel _mapChannel(MattermostChannel channel) => PlatformChannel(
    id: channel.id,
    name: channel.name,
    displayName: channel.displayName,
  );

  PlatformGroup _mapGroup(MattermostGroup group) => PlatformGroup(
    id: group.id,
    name: group.name,
    displayName: group.displayName,
    memberCount: group.memberCount,
  );

  PlatformUser _mapUser(MattermostUser user) => PlatformUser(
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    email: user.email,
  );
}

abstract class AuthIdentityProvider {
  String get key;

  bool isEnabled();

  Future<AuthenticatedUser?> authenticate({
    required String username,
    required String password,
  });
}
