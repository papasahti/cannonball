import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'database_store.dart';

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
    required DatabaseStore database,
    required this.sessionTtl,
    required this.secureCookies,
  }) : _database = database;

  final DatabaseStore _database;
  final Duration sessionTtl;
  final bool secureCookies;
  final Duration passwordResetTtl = const Duration(hours: 1);

  Future<AuthenticatedUser?> authenticate({
    required String username,
    required String rawPassword,
  }) async {
    final user = await _database.getUserByUsername(username);
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

  Future<String> createSession(AuthenticatedUser user) async {
    final now = DateTime.now().toUtc();
    await _database.purgeExpiredSessions(now);
    final token = _randomToken();
    await _database.insertSession(
      token: token,
      userId: user.id,
      createdAt: now,
      expiresAt: now.add(sessionTtl),
    );
    return token;
  }

  Future<AuthenticatedUser?> synchronizeExternalUser({
    required String authProvider,
    required String externalSubject,
    required String username,
    required String displayName,
    required String email,
    required bool isAdmin,
  }) async {
    final existingExternal = await _database.getUserByExternalIdentity(
      authProvider: authProvider,
      externalSubject: externalSubject,
    );
    if (existingExternal != null) {
      if (existingExternal['isActive'] != true) {
        return null;
      }
      await _database.updateUser(
        id: existingExternal['id'] as int,
        displayName: displayName,
        email: email,
        role: isAdmin ? 'admin' : (existingExternal['role'] as String),
        isActive: existingExternal['isActive'] as bool,
      );
      return _mapUser(
        (await _database.getUserById(existingExternal['id'] as int))!,
      );
    }

    Map<String, Object?>? userToLink;
    if (email.isNotEmpty) {
      userToLink = await _database.getUserByEmail(email);
    }
    userToLink ??= await _database.getUserByUsername(username);

    if (userToLink != null) {
      if (userToLink['isActive'] != true) {
        return null;
      }
      await _database.linkExternalIdentity(
        id: userToLink['id'] as int,
        authProvider: authProvider,
        externalSubject: externalSubject,
      );
      await _database.updateUser(
        id: userToLink['id'] as int,
        displayName: displayName,
        email: email,
        role: isAdmin ? 'admin' : (userToLink['role'] as String),
        isActive: userToLink['isActive'] as bool,
      );
      return _mapUser(
        (await _database.getUserById(userToLink['id'] as int))!,
      );
    }

    final normalizedUsername = await _buildUniqueUsername(username);
    final id = await _database.createUser(
      username: normalizedUsername,
      displayName: displayName,
      email: email,
      passwordHash: hashPassword(_randomToken()),
      role: isAdmin ? 'admin' : 'user',
      isActive: true,
      authProvider: authProvider,
      externalSubject: externalSubject,
    );
    return _mapUser((await _database.getUserById(id))!);
  }

  Future<AuthenticatedUser?> resolveSession(String? cookieToken) async {
    if (cookieToken == null || cookieToken.isEmpty) {
      return null;
    }
    final now = DateTime.now().toUtc();
    await _database.purgeExpiredSessions(now);
    final session = await _database.getSession(cookieToken);
    if (session == null) {
      return null;
    }
    final expiresAt = DateTime.parse(session['expires_at'] as String).toUtc();
    if (!expiresAt.isAfter(now)) {
      await _database.deleteSession(cookieToken);
      return null;
    }
    final user = await _database.getUserById(session['user_id'] as int);
    if (user == null || user['isActive'] != true) {
      await _database.deleteSession(cookieToken);
      return null;
    }
    return _mapUser(user);
  }

  Future<void> deleteSession(String token) async {
    await _database.deleteSession(token);
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

  Future<String> createPasswordResetToken(int userId) async {
    final now = DateTime.now().toUtc();
    await _database.purgeExpiredPasswordResetTokens(now);
    final token = _randomToken();
    await _database.insertPasswordResetToken(
      token: token,
      userId: userId,
      createdAt: now,
      expiresAt: now.add(passwordResetTtl),
    );
    return token;
  }

  Future<AuthenticatedUser?> resolvePasswordResetToken(String token) async {
    final now = DateTime.now().toUtc();
    await _database.purgeExpiredPasswordResetTokens(now);
    final resetToken = await _database.getPasswordResetToken(token);
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
    final user = await _database.getUserById(resetToken['userId'] as int);
    if (user == null || user['isActive'] != true) {
      return null;
    }
    return _mapUser(user);
  }

  Future<bool> consumePasswordResetToken({
    required String token,
    required String newPassword,
  }) async {
    final user = await resolvePasswordResetToken(token);
    if (user == null) {
      return false;
    }
    await _database.updateOwnProfile(
      id: user.id,
      displayName: user.displayName,
      email: user.email,
      passwordHash: hashPassword(newPassword),
    );
    await _database.markPasswordResetTokenUsed(token);
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

  Future<String> _buildUniqueUsername(String preferredUsername) async {
    final base = preferredUsername.trim().toLowerCase().replaceAll(' ', '.');
    var candidate = base.isEmpty ? 'user' : base;
    var suffix = 1;
    while (await _database.getUserByUsername(candidate) != null) {
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
