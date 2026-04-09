import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'database.dart';

class AuthenticatedUser {
  AuthenticatedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.authProvider,
  });

  final int id;
  final String username;
  final String displayName;
  final String email;
  final String role;
  final bool isActive;
  final String authProvider;

  bool get isAdmin => role == 'admin';

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'email': email,
    'role': role,
    'isActive': isActive,
    'authProvider': authProvider,
  };
}

class AuthService {
  AuthService({
    required AppDatabase database,
    required this.sessionTtl,
    required this.secureCookies,
  }) : _database = database;

  final AppDatabase _database;
  final Duration sessionTtl;
  final bool secureCookies;
  final Duration passwordResetTtl = const Duration(hours: 1);

  AuthenticatedUser? authenticate({
    required String username,
    required String rawPassword,
  }) {
    final user = _database.getUserByUsername(username);
    if (user == null) {
      return null;
    }
    if (user['isActive'] != true) {
      return null;
    }
    final digest = hashPassword(rawPassword);
    if (digest != user['passwordHash']) {
      return null;
    }
    return _mapUser(user);
  }

  String createSession(AuthenticatedUser user) {
    final now = DateTime.now().toUtc();
    _database.purgeExpiredSessions(now);
    final token = _randomToken();
    _database.insertSession(
      token: token,
      userId: user.id,
      createdAt: now,
      expiresAt: now.add(sessionTtl),
    );
    return token;
  }

  AuthenticatedUser? synchronizeExternalUser({
    required String authProvider,
    required String externalSubject,
    required String username,
    required String displayName,
    required String email,
    required bool isAdmin,
  }) {
    final existingExternal = _database.getUserByExternalIdentity(
      authProvider: authProvider,
      externalSubject: externalSubject,
    );
    if (existingExternal != null) {
      if (existingExternal['isActive'] != true) {
        return null;
      }
      _database.updateUser(
        id: existingExternal['id'] as int,
        displayName: displayName,
        email: email,
        role: isAdmin ? 'admin' : (existingExternal['role'] as String),
        isActive: existingExternal['isActive'] as bool,
      );
      return _mapUser(_database.getUserById(existingExternal['id'] as int)!);
    }

    Map<String, Object?>? userToLink;
    if (email.isNotEmpty) {
      userToLink = _database.getUserByEmail(email);
    }
    userToLink ??= _database.getUserByUsername(username);

    if (userToLink != null) {
      if (userToLink['isActive'] != true) {
        return null;
      }
      _database.linkExternalIdentity(
        id: userToLink['id'] as int,
        authProvider: authProvider,
        externalSubject: externalSubject,
      );
      _database.updateUser(
        id: userToLink['id'] as int,
        displayName: displayName,
        email: email,
        role: isAdmin ? 'admin' : (userToLink['role'] as String),
        isActive: userToLink['isActive'] as bool,
      );
      return _mapUser(_database.getUserById(userToLink['id'] as int)!);
    }

    final normalizedUsername = _buildUniqueUsername(username);
    final id = _database.createUser(
      username: normalizedUsername,
      displayName: displayName,
      email: email,
      passwordHash: hashPassword(_randomToken()),
      role: isAdmin ? 'admin' : 'user',
      isActive: true,
      authProvider: authProvider,
      externalSubject: externalSubject,
    );
    return _mapUser(_database.getUserById(id)!);
  }

  AuthenticatedUser? resolveSession(String? cookieToken) {
    if (cookieToken == null || cookieToken.isEmpty) {
      return null;
    }
    final now = DateTime.now().toUtc();
    _database.purgeExpiredSessions(now);
    final session = _database.getSession(cookieToken);
    if (session == null) {
      return null;
    }
    final expiresAt = DateTime.parse(session['expires_at'] as String).toUtc();
    if (!expiresAt.isAfter(now)) {
      _database.deleteSession(cookieToken);
      return null;
    }
    final user = _database.getUserById(session['user_id'] as int);
    if (user == null || user['isActive'] != true) {
      _database.deleteSession(cookieToken);
      return null;
    }
    return _mapUser(user);
  }

  void deleteSession(String token) {
    _database.deleteSession(token);
  }

  String buildSessionCookie(String token) {
    final parts = <String>[
      'cannonball_session=$token',
      'Path=/',
      'HttpOnly',
      'SameSite=Lax',
      'Max-Age=${sessionTtl.inSeconds}',
    ];
    if (secureCookies) {
      parts.add('Secure');
    }
    return parts.join('; ');
  }

  String buildClearSessionCookie() {
    final parts = <String>[
      'cannonball_session=',
      'Path=/',
      'HttpOnly',
      'SameSite=Lax',
      'Max-Age=0',
    ];
    if (secureCookies) {
      parts.add('Secure');
    }
    return parts.join('; ');
  }

  String? readSessionToken(String? cookieHeader) {
    if (cookieHeader == null || cookieHeader.isEmpty) {
      return null;
    }
    final cookies = cookieHeader.split(';');
    for (final cookie in cookies) {
      final trimmed = cookie.trim();
      if (trimmed.startsWith('cannonball_session=')) {
        return trimmed.substring('cannonball_session='.length);
      }
    }
    return null;
  }

  static String hashPassword(String rawPassword) {
    return sha256.convert(utf8.encode(rawPassword)).toString();
  }

  String createPasswordResetToken(int userId) {
    final now = DateTime.now().toUtc();
    _database.purgeExpiredPasswordResetTokens(now);
    final token = _randomToken();
    _database.insertPasswordResetToken(
      token: token,
      userId: userId,
      createdAt: now,
      expiresAt: now.add(passwordResetTtl),
    );
    return token;
  }

  AuthenticatedUser? resolvePasswordResetToken(String token) {
    final now = DateTime.now().toUtc();
    _database.purgeExpiredPasswordResetTokens(now);
    final resetToken = _database.getPasswordResetToken(token);
    if (resetToken == null) {
      return null;
    }
    if (resetToken['usedAt'] != null) {
      return null;
    }
    final expiresAt = DateTime.parse(resetToken['expiresAt'] as String).toUtc();
    if (!expiresAt.isAfter(now)) {
      return null;
    }
    final user = _database.getUserById(resetToken['userId'] as int);
    if (user == null || user['isActive'] != true) {
      return null;
    }
    return _mapUser(user);
  }

  bool consumePasswordResetToken({
    required String token,
    required String newPassword,
  }) {
    final user = resolvePasswordResetToken(token);
    if (user == null) {
      return false;
    }
    _database.updateOwnProfile(
      id: user.id,
      displayName: user.displayName,
      email: user.email,
      passwordHash: hashPassword(newPassword),
    );
    _database.markPasswordResetTokenUsed(token);
    return true;
  }

  AuthenticatedUser _mapUser(Map<String, Object?> user) {
    return AuthenticatedUser(
      id: user['id'] as int,
      username: user['username'] as String,
      displayName: user['displayName'] as String,
      email: (user['email'] as String?) ?? '',
      role: user['role'] as String,
      isActive: user['isActive'] as bool,
      authProvider: (user['authProvider'] as String?) ?? 'local',
    );
  }

  String generateOpaqueToken() => _randomToken();

  String _buildUniqueUsername(String preferredUsername) {
    final base = preferredUsername.trim().toLowerCase().replaceAll(' ', '.');
    var candidate = base.isEmpty ? 'user' : base;
    var suffix = 1;
    while (_database.getUserByUsername(candidate) != null) {
      candidate = '${base.isEmpty ? 'user' : base}.$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64Url.encode(bytes);
  }
}
