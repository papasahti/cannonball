import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  AppDatabase({
    required this.databasePath,
    this.driver = 'sqlite',
    String? connectionTarget,
  }) : connectionTarget = connectionTarget ?? databasePath;

  final String driver;
  final String databasePath;
  final String connectionTarget;
  Database? _database;

  Database get db => _database ??= sqlite3.open(connectionTarget);

  void initialize() {
    final directory = Directory(p.dirname(databasePath));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = FULL;');
    db.execute('PRAGMA busy_timeout = 5000;');
    db.execute('PRAGMA temp_store = MEMORY;');
    db.execute('PRAGMA foreign_keys = ON;');
    _initializeMigrationTable();
    _runMigrations();
    purgeExpiredSessions(DateTime.now().toUtc());
    purgeExpiredPasswordResetTokens(DateTime.now().toUtc());
  }

  void ensureBootstrapAdmin({
    required String username,
    required String displayName,
    required String? email,
    required String passwordHash,
  }) {
    final existing = getUserByUsername(username);
    if (existing != null) {
      updateBootstrapAdmin(
        id: existing['id'] as int,
        displayName: displayName,
        email: email,
      );
      return;
    }
    createUser(
      username: username,
      displayName: displayName,
      email: email,
      passwordHash: passwordHash,
      role: 'admin',
      isActive: true,
    );
  }

  int createUser({
    required String username,
    required String displayName,
    required String? email,
    required String passwordHash,
    required String role,
    required bool isActive,
    String authProvider = 'local',
    String? externalSubject,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    db.execute(
      '''
      INSERT INTO users (
        username,
        display_name,
        email,
        auth_provider,
        external_subject,
        password_hash,
        role,
        is_active,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        username,
        displayName,
        email,
        authProvider,
        externalSubject,
        passwordHash,
        role,
        isActive ? 1 : 0,
        now,
        now,
      ],
    );
    return db.lastInsertRowId;
  }

  Map<String, Object?>? getUserByUsername(String username) {
    final result = db.select(
      '''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE lower(username) = lower(?)
      LIMIT 1
      ''',
      [username],
    );
    if (result.isEmpty) {
      return null;
    }
    return _userRowToMap(result.first);
  }

  Map<String, Object?>? getUserById(int id) {
    final result = db.select(
      '''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE id = ?
      LIMIT 1
      ''',
      [id],
    );
    if (result.isEmpty) {
      return null;
    }
    return _userRowToMap(result.first);
  }

  Map<String, Object?>? getUserByEmail(String email) {
    final result = db.select(
      '''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE lower(email) = lower(?)
      LIMIT 1
      ''',
      [email],
    );
    if (result.isEmpty) {
      return null;
    }
    return _userRowToMap(result.first);
  }

  List<Map<String, Object?>> listUsers() {
    final rows = db.select('''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      ORDER BY role DESC, display_name ASC, username ASC
    ''');
    return rows.map(_userRowToMap).toList(growable: false);
  }

  void updateUser({
    required int id,
    required String displayName,
    required String email,
    required String role,
    required bool isActive,
    String? passwordHash,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    if (passwordHash != null && passwordHash.isNotEmpty) {
      db.execute(
        '''
        UPDATE users
        SET display_name = ?, email = ?, role = ?, is_active = ?, password_hash = ?, updated_at = ?
        WHERE id = ?
        ''',
        [displayName, email, role, isActive ? 1 : 0, passwordHash, now, id],
      );
      return;
    }

    db.execute(
      '''
      UPDATE users
      SET display_name = ?, email = ?, role = ?, is_active = ?, updated_at = ?
      WHERE id = ?
      ''',
      [displayName, email, role, isActive ? 1 : 0, now, id],
    );
  }

  void updateOwnProfile({
    required int id,
    required String displayName,
    required String email,
    String? passwordHash,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    if (passwordHash != null && passwordHash.isNotEmpty) {
      db.execute(
        '''
        UPDATE users
        SET display_name = ?, email = ?, password_hash = ?, updated_at = ?
        WHERE id = ?
        ''',
        [displayName, email, passwordHash, now, id],
      );
      return;
    }

    db.execute(
      '''
      UPDATE users
      SET display_name = ?, email = ?, updated_at = ?
      WHERE id = ?
      ''',
      [displayName, email, now, id],
    );
  }

  void updateUserEmail({required int id, required String? email}) {
    db.execute('UPDATE users SET email = ?, updated_at = ? WHERE id = ?', [
      email,
      DateTime.now().toUtc().toIso8601String(),
      id,
    ]);
  }

  void updateBootstrapAdmin({
    required int id,
    required String displayName,
    required String? email,
  }) {
    final normalizedEmail = email?.trim();
    db.execute(
      '''
      UPDATE users
      SET display_name = ?,
          email = COALESCE(?, email),
          role = 'admin',
          is_active = 1,
          auth_provider = 'local',
          updated_at = ?
      WHERE id = ?
      ''',
      [
        displayName,
        normalizedEmail != null && normalizedEmail.isNotEmpty
            ? normalizedEmail
            : null,
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  Map<String, Object?>? getUserByExternalIdentity({
    required String authProvider,
    required String externalSubject,
  }) {
    final result = db.select(
      '''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE auth_provider = ? AND external_subject = ?
      LIMIT 1
      ''',
      [authProvider, externalSubject],
    );
    if (result.isEmpty) {
      return null;
    }
    return _userRowToMap(result.first);
  }

  void linkExternalIdentity({
    required int id,
    required String authProvider,
    required String externalSubject,
  }) {
    db.execute(
      '''
      UPDATE users
      SET auth_provider = ?, external_subject = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        authProvider,
        externalSubject,
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  int countActiveAdmins() {
    final result = db.select(
      'SELECT COUNT(*) AS total FROM users WHERE role = ? AND is_active = 1',
      ['admin'],
    );
    return result.first['total'] as int;
  }

  void insertSession({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) {
    db.execute(
      '''
      INSERT INTO sessions (token, user_id, created_at, expires_at)
      VALUES (?, ?, ?, ?)
      ''',
      [
        token,
        userId,
        createdAt.toUtc().toIso8601String(),
        expiresAt.toUtc().toIso8601String(),
      ],
    );
  }

  Map<String, Object?>? getSession(String token) {
    final result = db.select(
      '''
      SELECT token, user_id, created_at, expires_at
      FROM sessions
      WHERE token = ?
      LIMIT 1
      ''',
      [token],
    );
    if (result.isEmpty) {
      return null;
    }
    final row = result.first;
    return {
      'token': row['token'],
      'user_id': row['user_id'],
      'created_at': row['created_at'],
      'expires_at': row['expires_at'],
    };
  }

  void deleteSession(String token) {
    db.execute('DELETE FROM sessions WHERE token = ?', [token]);
  }

  void purgeExpiredSessions(DateTime now) {
    db.execute('DELETE FROM sessions WHERE expires_at <= ?', [
      now.toUtc().toIso8601String(),
    ]);
  }

  void insertPasswordResetToken({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) {
    db.execute(
      '''
      INSERT INTO password_reset_tokens (token, user_id, expires_at, created_at)
      VALUES (?, ?, ?, ?)
      ''',
      [
        token,
        userId,
        expiresAt.toUtc().toIso8601String(),
        createdAt.toUtc().toIso8601String(),
      ],
    );
  }

  Map<String, Object?>? getPasswordResetToken(String token) {
    final result = db.select(
      '''
      SELECT token, user_id, expires_at, created_at, used_at
      FROM password_reset_tokens
      WHERE token = ?
      LIMIT 1
      ''',
      [token],
    );
    if (result.isEmpty) {
      return null;
    }
    final row = result.first;
    return {
      'token': row['token'],
      'userId': row['user_id'],
      'expiresAt': row['expires_at'],
      'createdAt': row['created_at'],
      'usedAt': row['used_at'],
    };
  }

  void markPasswordResetTokenUsed(String token) {
    db.execute('UPDATE password_reset_tokens SET used_at = ? WHERE token = ?', [
      DateTime.now().toUtc().toIso8601String(),
      token,
    ]);
  }

  void purgeExpiredPasswordResetTokens(DateTime now) {
    db.execute(
      'DELETE FROM password_reset_tokens WHERE expires_at <= ? OR used_at IS NOT NULL',
      [now.toUtc().toIso8601String()],
    );
  }

  Map<String, String> getSettings() {
    final rows = db.select('SELECT key, value FROM settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  void upsertSettings(Map<String, String?> values) {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in values.entries) {
      if (entry.value == null) {
        db.execute('DELETE FROM settings WHERE key = ?', [entry.key]);
        continue;
      }
      db.execute(
        '''
        INSERT INTO settings (key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
        ''',
        [entry.key, entry.value, now],
      );
    }
  }

  bool hasMattermostDirectoryUsers() {
    final result = db.select(
      'SELECT 1 FROM mattermost_directory_users LIMIT 1',
    );
    return result.isNotEmpty;
  }

  bool hasMattermostDirectoryGroups() {
    final result = db.select(
      'SELECT 1 FROM mattermost_directory_groups LIMIT 1',
    );
    return result.isNotEmpty;
  }

  bool hasMattermostDirectoryChannels() {
    final result = db.select(
      'SELECT 1 FROM mattermost_directory_channels LIMIT 1',
    );
    return result.isNotEmpty;
  }

  void replaceMattermostDirectoryUsers(List<Map<String, Object?>> users) {
    final now = DateTime.now().toUtc().toIso8601String();
    db.execute('BEGIN');
    try {
      final seenIds = <String>{};
      for (final user in users) {
        final id = (user['id'] as String? ?? '').trim();
        if (id.isEmpty || !seenIds.add(id)) {
          continue;
        }
        db.execute(
          '''
          INSERT INTO mattermost_directory_users (
            id, username, display_name, email, updated_at
          ) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            username = excluded.username,
            display_name = excluded.display_name,
            email = excluded.email,
            updated_at = excluded.updated_at
          ''',
          [
            id,
            (user['username'] as String? ?? '').trim(),
            (user['displayName'] as String? ?? '').trim(),
            (user['email'] as String? ?? '').trim(),
            now,
          ],
        );
      }

      if (seenIds.isEmpty) {
        db.execute('DELETE FROM mattermost_directory_users');
      } else {
        final placeholders = List.filled(seenIds.length, '?').join(', ');
        db.execute(
          'DELETE FROM mattermost_directory_users WHERE id NOT IN ($placeholders)',
          seenIds.toList(growable: false),
        );
      }
      upsertSettings({'mattermost.directoryUsersSyncedAt': now});
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void replaceMattermostDirectoryGroups(List<Map<String, Object?>> groups) {
    final now = DateTime.now().toUtc().toIso8601String();
    db.execute('BEGIN');
    try {
      final seenIds = <String>{};
      for (final group in groups) {
        final id = (group['id'] as String? ?? '').trim();
        if (id.isEmpty || !seenIds.add(id)) {
          continue;
        }
        db.execute(
          '''
          INSERT INTO mattermost_directory_groups (
            id, name, display_name, member_count, updated_at
          ) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            display_name = excluded.display_name,
            member_count = excluded.member_count,
            updated_at = excluded.updated_at
          ''',
          [
            id,
            (group['name'] as String? ?? '').trim(),
            (group['displayName'] as String? ?? '').trim(),
            (group['memberCount'] as num?)?.toInt() ?? 0,
            now,
          ],
        );
      }

      if (seenIds.isEmpty) {
        db.execute('DELETE FROM mattermost_directory_groups');
      } else {
        final placeholders = List.filled(seenIds.length, '?').join(', ');
        db.execute(
          'DELETE FROM mattermost_directory_groups WHERE id NOT IN ($placeholders)',
          seenIds.toList(growable: false),
        );
      }
      upsertSettings({'mattermost.directoryGroupsSyncedAt': now});
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void replaceMattermostDirectoryChannels(List<Map<String, Object?>> channels) {
    final now = DateTime.now().toUtc().toIso8601String();
    db.execute('BEGIN');
    try {
      final seenIds = <String>{};
      for (final channel in channels) {
        final id = (channel['id'] as String? ?? '').trim();
        if (id.isEmpty || !seenIds.add(id)) {
          continue;
        }
        db.execute(
          '''
          INSERT INTO mattermost_directory_channels (
            id, name, display_name, channel_type, updated_at
          ) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            display_name = excluded.display_name,
            channel_type = excluded.channel_type,
            updated_at = excluded.updated_at
          ''',
          [
            id,
            (channel['name'] as String? ?? '').trim(),
            (channel['displayName'] as String? ?? '').trim(),
            (channel['type'] as String? ?? '').trim(),
            now,
          ],
        );
      }

      if (seenIds.isEmpty) {
        db.execute('DELETE FROM mattermost_directory_channels');
      } else {
        final placeholders = List.filled(seenIds.length, '?').join(', ');
        db.execute(
          'DELETE FROM mattermost_directory_channels WHERE id NOT IN ($placeholders)',
          seenIds.toList(growable: false),
        );
      }
      upsertSettings({'mattermost.directoryChannelsSyncedAt': now});
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<Map<String, Object?>> searchMattermostDirectoryUsers(String query) {
    final normalized = '%${query.trim().toLowerCase()}%';
    final rows = query.trim().isEmpty
        ? db.select(
            '''
            SELECT id, username, display_name, email
            FROM mattermost_directory_users
            ORDER BY lower(display_name), lower(username)
            LIMIT 50
            ''',
          )
        : db.select(
            '''
            SELECT id, username, display_name, email
            FROM mattermost_directory_users
            WHERE lower(username) LIKE ?
               OR lower(display_name) LIKE ?
               OR lower(email) LIKE ?
            ORDER BY
              CASE
                WHEN lower(username) = ? THEN 0
                WHEN lower(username) LIKE ? THEN 1
                ELSE 2
              END,
              lower(display_name),
              lower(username)
            LIMIT 50
            ''',
            [normalized, normalized, normalized, query.trim().toLowerCase(), normalized],
          );
    return rows
        .map((row) => {
              'id': row['id'],
              'username': row['username'],
              'displayName': row['display_name'],
              'email': row['email'],
            })
        .toList(growable: false);
  }

  List<Map<String, Object?>> searchMattermostDirectoryGroups(String query) {
    final normalized = '%${query.trim().toLowerCase()}%';
    final rows = query.trim().isEmpty
        ? db.select(
            '''
            SELECT id, name, display_name, member_count
            FROM mattermost_directory_groups
            ORDER BY lower(display_name), lower(name)
            LIMIT 50
            ''',
          )
        : db.select(
            '''
            SELECT id, name, display_name, member_count
            FROM mattermost_directory_groups
            WHERE lower(name) LIKE ?
               OR lower(display_name) LIKE ?
            ORDER BY lower(display_name), lower(name)
            LIMIT 50
            ''',
            [normalized, normalized],
          );
    return rows
        .map((row) => {
              'id': row['id'],
              'name': row['name'],
              'displayName': row['display_name'],
              'memberCount': row['member_count'],
            })
        .toList(growable: false);
  }

  List<Map<String, Object?>> searchMattermostDirectoryChannels(String query) {
    final normalized = '%${query.trim().toLowerCase()}%';
    final rows = query.trim().isEmpty
        ? db.select(
            '''
            SELECT id, name, display_name, channel_type
            FROM mattermost_directory_channels
            ORDER BY lower(display_name), lower(name)
            LIMIT 100
            ''',
          )
        : db.select(
            '''
            SELECT id, name, display_name, channel_type
            FROM mattermost_directory_channels
            WHERE lower(name) LIKE ?
               OR lower(display_name) LIKE ?
            ORDER BY lower(display_name), lower(name)
            LIMIT 100
            ''',
            [normalized, normalized],
          );
    return rows
        .map((row) => {
              'id': row['id'],
              'name': row['name'],
              'displayName': row['display_name'],
              'type': row['channel_type'],
            })
        .toList(growable: false);
  }

  int insertCampaign({
    required DateTime createdAt,
    required String createdBy,
    required String message,
    required List<Map<String, Object?>> users,
    required List<Map<String, Object?>> groups,
    required List<String> channels,
  }) {
    db.execute(
      '''
      INSERT INTO campaigns (
        created_at,
        created_by,
        message,
        users_json,
        groups_json,
        channels_json
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        createdAt.toUtc().toIso8601String(),
        createdBy,
        message,
        jsonEncode(users),
        jsonEncode(groups),
        jsonEncode(channels),
      ],
    );
    return db.lastInsertRowId;
  }

  void insertDelivery({
    required int campaignId,
    required String targetType,
    required String targetKey,
    required String targetLabel,
    required String status,
    DateTime? sentAt,
    String? errorMessage,
    Map<String, Object?>? responsePayload,
  }) {
    db.execute(
      '''
      INSERT INTO deliveries (
        campaign_id,
        target_type,
        target_key,
        target_label,
        status,
        sent_at,
        error_message,
        response_payload
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        campaignId,
        targetType,
        targetKey,
        targetLabel,
        status,
        sentAt?.toUtc().toIso8601String(),
        errorMessage,
        responsePayload == null ? null : jsonEncode(responsePayload),
      ],
    );
  }

  void updateCampaignSummary({
    required int campaignId,
    required int sentCount,
    required int failedCount,
  }) {
    db.execute(
      '''
      UPDATE campaigns
      SET sent_count = ?, failed_count = ?
      WHERE id = ?
      ''',
      [sentCount, failedCount, campaignId],
    );
  }

  int insertInboundRule({
    required String name,
    required String source,
    required String eventType,
    required String ruleKey,
    required String severity,
    required String containsText,
    required Map<String, String> labelFilters,
    required List<String> users,
    required List<String> groups,
    required List<String> channels,
    required String messageTemplate,
    required bool enabled,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    db.execute(
      '''
      INSERT INTO inbound_rules (
        name,
        source,
        event_type,
        rule_key,
        severity,
        contains_text,
        label_filters_json,
        users_json,
        groups_json,
        channels_json,
        message_template,
        enabled,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        name,
        source,
        eventType,
        ruleKey,
        severity,
        containsText,
        jsonEncode(labelFilters),
        jsonEncode(users),
        jsonEncode(groups),
        jsonEncode(channels),
        messageTemplate,
        enabled ? 1 : 0,
        now,
        now,
      ],
    );
    return db.lastInsertRowId;
  }

  void updateInboundRule({
    required int id,
    required String name,
    required String source,
    required String eventType,
    required String ruleKey,
    required String severity,
    required String containsText,
    required Map<String, String> labelFilters,
    required List<String> users,
    required List<String> groups,
    required List<String> channels,
    required String messageTemplate,
    required bool enabled,
  }) {
    db.execute(
      '''
      UPDATE inbound_rules
      SET name = ?,
          source = ?,
          event_type = ?,
          rule_key = ?,
          severity = ?,
          contains_text = ?,
          label_filters_json = ?,
          users_json = ?,
          groups_json = ?,
          channels_json = ?,
          message_template = ?,
          enabled = ?,
          updated_at = ?
      WHERE id = ?
      ''',
      [
        name,
        source,
        eventType,
        ruleKey,
        severity,
        containsText,
        jsonEncode(labelFilters),
        jsonEncode(users),
        jsonEncode(groups),
        jsonEncode(channels),
        messageTemplate,
        enabled ? 1 : 0,
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  List<Map<String, Object?>> listInboundRules() {
    final rows = db.select('''
      SELECT
        ir.id,
        ir.name,
        ir.source,
        ir.event_type,
        ir.rule_key,
        ir.severity,
        ir.contains_text,
        ir.label_filters_json,
        ir.users_json,
        ir.groups_json,
        ir.channels_json,
        ir.message_template,
        ir.enabled,
        ir.created_at,
        ir.updated_at,
        COALESCE(stats.total_runs, 0) AS total_runs,
        COALESCE(stats.failed_runs, 0) AS failed_runs,
        stats.last_triggered_at
      FROM inbound_rules ir
      LEFT JOIN (
        SELECT
          rule_id,
          COUNT(*) AS total_runs,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_runs,
          MAX(created_at) AS last_triggered_at
        FROM inbound_events
        WHERE rule_id IS NOT NULL
        GROUP BY rule_id
      ) stats ON stats.rule_id = ir.id
      ORDER BY enabled DESC, updated_at DESC, id DESC
    ''');
    return rows.map(_inboundRuleRowToMap).toList(growable: false);
  }

  Map<String, Object?>? getInboundRuleById(int id) {
    final rows = db.select('''
      SELECT
        ir.id,
        ir.name,
        ir.source,
        ir.event_type,
        ir.rule_key,
        ir.severity,
        ir.contains_text,
        ir.label_filters_json,
        ir.users_json,
        ir.groups_json,
        ir.channels_json,
        ir.message_template,
        ir.enabled,
        ir.created_at,
        ir.updated_at,
        COALESCE(stats.total_runs, 0) AS total_runs,
        COALESCE(stats.failed_runs, 0) AS failed_runs,
        stats.last_triggered_at
      FROM inbound_rules ir
      LEFT JOIN (
        SELECT
          rule_id,
          COUNT(*) AS total_runs,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_runs,
          MAX(created_at) AS last_triggered_at
        FROM inbound_events
        WHERE rule_id IS NOT NULL
        GROUP BY rule_id
      ) stats ON stats.rule_id = ir.id
      WHERE ir.id = ?
      LIMIT 1
    ''', [id]);
    if (rows.isEmpty) {
      return null;
    }
    return _inboundRuleRowToMap(rows.first);
  }

  Map<String, Object?>? getInboundRuleByKey({
    required String source,
    required String ruleKey,
  }) {
    final rows = db.select('''
      SELECT
        ir.id,
        ir.name,
        ir.source,
        ir.event_type,
        ir.rule_key,
        ir.severity,
        ir.contains_text,
        ir.label_filters_json,
        ir.users_json,
        ir.groups_json,
        ir.channels_json,
        ir.message_template,
        ir.enabled,
        ir.created_at,
        ir.updated_at,
        COALESCE(stats.total_runs, 0) AS total_runs,
        COALESCE(stats.failed_runs, 0) AS failed_runs,
        stats.last_triggered_at
      FROM inbound_rules ir
      LEFT JOIN (
        SELECT
          rule_id,
          COUNT(*) AS total_runs,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_runs,
          MAX(created_at) AS last_triggered_at
        FROM inbound_events
        WHERE rule_id IS NOT NULL
        GROUP BY rule_id
      ) stats ON stats.rule_id = ir.id
      WHERE lower(ir.source) = lower(?) AND lower(ir.rule_key) = lower(?) AND ir.enabled = 1
      LIMIT 1
    ''', [source, ruleKey]);
    if (rows.isEmpty) {
      return null;
    }
    return _inboundRuleRowToMap(rows.first);
  }

  List<Map<String, Object?>> listActiveInboundRulesBySource(String source) {
    final rows = db.select('''
      SELECT
        ir.id,
        ir.name,
        ir.source,
        ir.event_type,
        ir.rule_key,
        ir.severity,
        ir.contains_text,
        ir.label_filters_json,
        ir.users_json,
        ir.groups_json,
        ir.channels_json,
        ir.message_template,
        ir.enabled,
        ir.created_at,
        ir.updated_at,
        COALESCE(stats.total_runs, 0) AS total_runs,
        COALESCE(stats.failed_runs, 0) AS failed_runs,
        stats.last_triggered_at
      FROM inbound_rules ir
      LEFT JOIN (
        SELECT
          rule_id,
          COUNT(*) AS total_runs,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_runs,
          MAX(created_at) AS last_triggered_at
        FROM inbound_events
        WHERE rule_id IS NOT NULL
        GROUP BY rule_id
      ) stats ON stats.rule_id = ir.id
      WHERE lower(ir.source) = lower(?) AND ir.enabled = 1
      ORDER BY ir.updated_at DESC, ir.id DESC
    ''', [source]);
    return rows.map(_inboundRuleRowToMap).toList(growable: false);
  }

  int insertInboundEvent({
    required String source,
    required String eventType,
    required String requestId,
    required String status,
    int? ruleId,
    int? campaignId,
    String? errorMessage,
    Map<String, Object?>? payload,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    db.execute(
      '''
      INSERT INTO inbound_events (
        source,
        event_type,
        request_id,
        rule_id,
        campaign_id,
        status,
        error_message,
        payload_json,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        source,
        eventType,
        requestId,
        ruleId,
        campaignId,
        status,
        errorMessage,
        payload == null ? null : jsonEncode(payload),
        now,
        now,
      ],
    );
    return db.lastInsertRowId;
  }

  Map<String, Object?>? getInboundEventByRequestId({
    required String source,
    required String requestId,
  }) {
    final rows = db.select('''
      SELECT id, source, event_type, request_id, rule_id, campaign_id, status, error_message, payload_json, created_at, updated_at
      FROM inbound_events
      WHERE lower(source) = lower(?) AND request_id = ?
      LIMIT 1
    ''', [source, requestId]);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return {
      'id': row['id'],
      'source': row['source'],
      'eventType': row['event_type'],
      'requestId': row['request_id'],
      'ruleId': row['rule_id'],
      'campaignId': row['campaign_id'],
      'status': row['status'],
      'errorMessage': row['error_message'],
      'payload': row['payload_json'] == null
          ? null
          : jsonDecode(row['payload_json'] as String),
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  List<Map<String, Object?>> listInboundEvents({
    int limit = 10,
    String? source,
  }) {
    final queryBuffer = StringBuffer('''
      SELECT
        ie.id,
        ie.source,
        ie.event_type,
        ie.request_id,
        ie.rule_id,
        ie.campaign_id,
        ie.status,
        ie.error_message,
        ie.payload_json,
        ie.created_at,
        ie.updated_at,
        ir.name AS rule_name
      FROM inbound_events ie
      LEFT JOIN inbound_rules ir ON ir.id = ie.rule_id
    ''');
    final params = <Object?>[];

    if (source != null && source.trim().isNotEmpty) {
      queryBuffer.write(' WHERE lower(ie.source) = lower(?)');
      params.add(source.trim());
    }

    queryBuffer.write(' ORDER BY ie.id DESC LIMIT ?');
    params.add(limit.clamp(1, 100));

    final rows = db.select(queryBuffer.toString(), params);
    return rows.map((row) {
      final rawPayload = row['payload_json'] == null
          ? null
          : jsonDecode(row['payload_json'] as String);
      final payload = rawPayload is Map
          ? Map<String, Object?>.from(rawPayload)
          : <String, Object?>{};
      return {
        'id': row['id'],
        'source': row['source'],
        'eventType': row['event_type'],
        'requestId': row['request_id'],
        'ruleId': row['rule_id'],
        'ruleName': row['rule_name'],
        'campaignId': row['campaign_id'],
        'status': row['status'],
        'errorMessage': row['error_message'],
        'title': payload['title'],
        'message': payload['message'],
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'],
      };
    }).toList(growable: false);
  }

  List<Map<String, Object?>> listCampaigns({
    int limit = 20,
    String? createdBy,
  }) {
    final queryBuffer = StringBuffer('''
      SELECT
        id,
        created_at,
        created_by,
        message,
        users_json,
        groups_json,
        channels_json,
        sent_count,
        failed_count
      FROM campaigns
    ''');
    final params = <Object?>[];

    if (createdBy != null && createdBy.isNotEmpty) {
      queryBuffer.write(' WHERE created_by = ?');
      params.add(createdBy);
    }

    queryBuffer.write(' ORDER BY id DESC LIMIT ?');
    params.add(limit);

    final campaigns = db.select(queryBuffer.toString(), params);
    final deliveries = db.select('''
      SELECT
        id,
        campaign_id,
        target_type,
        target_key,
        target_label,
        status,
        sent_at,
        error_message,
        response_payload
      FROM deliveries
      ORDER BY id DESC
    ''');

    final deliveriesByCampaign = <int, List<Map<String, Object?>>>{};
    for (final row in deliveries) {
      final campaignId = row['campaign_id'] as int;
      deliveriesByCampaign.putIfAbsent(campaignId, () => []).add({
        'id': row['id'],
        'targetType': row['target_type'],
        'targetKey': row['target_key'],
        'targetLabel': row['target_label'],
        'status': row['status'],
        'sentAt': row['sent_at'],
        'errorMessage': row['error_message'],
        'responsePayload': row['response_payload'] == null
            ? null
            : jsonDecode(row['response_payload'] as String),
      });
    }

    final inboundEvents = db.select('''
      SELECT
        ie.campaign_id,
        ie.source,
        ie.event_type,
        ie.request_id,
        ie.rule_id,
        ie.status,
        ie.error_message,
        ir.name AS rule_name
      FROM inbound_events ie
      LEFT JOIN inbound_rules ir ON ir.id = ie.rule_id
      WHERE ie.campaign_id IS NOT NULL
      ORDER BY ie.id DESC
    ''');

    final inboundByCampaign = <int, Map<String, Object?>>{};
    for (final row in inboundEvents) {
      final campaignId = row['campaign_id'] as int?;
      if (campaignId == null || inboundByCampaign.containsKey(campaignId)) {
        continue;
      }
      inboundByCampaign[campaignId] = {
        'kind': 'inbound',
        'source': row['source'],
        'eventType': row['event_type'],
        'requestId': row['request_id'],
        'ruleId': row['rule_id'],
        'ruleName': row['rule_name'],
        'status': row['status'],
        'errorMessage': row['error_message'],
      };
    }

    return campaigns
        .map(
          (row) => {
            'id': row['id'],
            'createdAt': row['created_at'],
            'createdBy': row['created_by'],
            'message': row['message'],
            'trigger':
                inboundByCampaign[row['id'] as int] ??
                <String, Object?>{'kind': 'manual'},
            'users': jsonDecode(row['users_json'] as String),
            'groups': jsonDecode(row['groups_json'] as String),
            'channels': jsonDecode(row['channels_json'] as String),
            'sentCount': row['sent_count'],
            'failedCount': row['failed_count'],
            'deliveries':
                deliveriesByCampaign[row['id'] as int] ??
                <Map<String, Object?>>[],
          },
        )
        .toList(growable: false);
  }

  Map<String, Object?> _userRowToMap(Row row) {
    return {
      'id': row['id'],
      'username': row['username'],
      'displayName': row['display_name'],
      'email': row['email'],
      'authProvider': row['auth_provider'],
      'externalSubject': row['external_subject'],
      'passwordHash': row['password_hash'],
      'role': row['role'],
      'isActive': (row['is_active'] as int) == 1,
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  Map<String, Object?> _inboundRuleRowToMap(Row row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'source': row['source'],
      'eventType': row['event_type'],
      'ruleKey': row['rule_key'],
      'severity': row['severity'],
      'containsText': row['contains_text'],
      'labelFilters': row['label_filters_json'] == null
          ? <String, Object?>{}
          : Map<String, Object?>.from(
              jsonDecode(row['label_filters_json'] as String) as Map,
            ),
      'users': row['users_json'] == null
          ? <Object?>[]
          : (jsonDecode(row['users_json'] as String) as List<dynamic>),
      'groups': row['groups_json'] == null
          ? <Object?>[]
          : (jsonDecode(row['groups_json'] as String) as List<dynamic>),
      'channels': row['channels_json'] == null
          ? <Object?>[]
          : (jsonDecode(row['channels_json'] as String) as List<dynamic>),
      'messageTemplate': row['message_template'],
      'enabled': (row['enabled'] as int) == 1,
      'totalRuns': row['total_runs'] ?? 0,
      'failedRuns': row['failed_runs'] ?? 0,
      'lastTriggeredAt': row['last_triggered_at'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  void close() {
    _database?.dispose();
  }

  void _initializeMigrationTable() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        executed_at TEXT NOT NULL
      );
    ''');
  }

  void _runMigrations() {
    final applied = db
        .select('SELECT version FROM schema_migrations')
        .map((row) => row['version'] as String)
        .toSet();

    for (final migration in _migrations) {
      if (applied.contains(migration.version)) {
        continue;
      }
      migration.apply(this);
      db.execute(
        '''
        INSERT INTO schema_migrations (version, description, executed_at)
        VALUES (?, ?, ?)
        ''',
        [
          migration.version,
          migration.description,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
    }
  }

  List<_DatabaseMigration> get _migrations => [
    _DatabaseMigration(
      version: '001_initial_schema',
      description: 'Create core application tables.',
      apply: (database) {
        database.db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            display_name TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS sessions (
            token TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS campaigns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            created_by TEXT NOT NULL,
            message TEXT NOT NULL,
            users_json TEXT NOT NULL,
            channels_json TEXT NOT NULL,
            sent_count INTEGER NOT NULL DEFAULT 0,
            failed_count INTEGER NOT NULL DEFAULT 0
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS deliveries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            campaign_id INTEGER NOT NULL,
            target_type TEXT NOT NULL,
            target_key TEXT NOT NULL,
            target_label TEXT NOT NULL,
            status TEXT NOT NULL,
            sent_at TEXT,
            error_message TEXT,
            response_payload TEXT,
            FOREIGN KEY (campaign_id) REFERENCES campaigns(id)
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS password_reset_tokens (
            token TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            expires_at TEXT NOT NULL,
            created_at TEXT NOT NULL,
            used_at TEXT,
            FOREIGN KEY (user_id) REFERENCES users(id)
          );
        ''');
      },
    ),
    _DatabaseMigration(
      version: '010_mattermost_directory_cache',
      description: 'Create Mattermost directory cache tables.',
      apply: (database) {
        database.db.execute('''
          CREATE TABLE IF NOT EXISTS mattermost_directory_users (
            id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            display_name TEXT NOT NULL,
            email TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS mattermost_directory_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            display_name TEXT NOT NULL,
            member_count INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS mattermost_directory_channels (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            display_name TEXT NOT NULL,
            channel_type TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL
          );
        ''');

        database.db.execute(
          'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_users_username ON mattermost_directory_users(username)',
        );
        database.db.execute(
          'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_users_display_name ON mattermost_directory_users(display_name)',
        );
        database.db.execute(
          'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_groups_name ON mattermost_directory_groups(name)',
        );
        database.db.execute(
          'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_channels_name ON mattermost_directory_channels(name)',
        );
      },
    ),
    _DatabaseMigration(
      version: '002_users_email',
      description: 'Add user email column.',
      apply: (database) {
        database._ensureColumn(table: 'users', column: 'email', definition: 'TEXT');
      },
    ),
    _DatabaseMigration(
      version: '003_external_identity',
      description: 'Add external identity support for SSO providers.',
      apply: (database) {
        database._ensureColumn(
          table: 'users',
          column: 'auth_provider',
          definition: "TEXT NOT NULL DEFAULT 'local'",
        );
        database._ensureColumn(
          table: 'users',
          column: 'external_subject',
          definition: 'TEXT',
        );
        database.db.execute("""
          UPDATE users
          SET auth_provider = 'local'
          WHERE auth_provider IS NULL OR trim(auth_provider) = ''
        """);
      },
    ),
    _DatabaseMigration(
      version: '004_campaign_groups',
      description: 'Add groups payload to campaigns.',
      apply: (database) {
        database._ensureColumn(
          table: 'campaigns',
          column: 'groups_json',
          definition: "TEXT NOT NULL DEFAULT '[]'",
        );
      },
    ),
    _DatabaseMigration(
      version: '005_normalize_user_data',
      description: 'Normalize user records for current schema.',
      apply: (database) {
        database.db.execute("""
          UPDATE users
          SET email = lower(trim(email))
          WHERE email IS NOT NULL AND trim(email) != ''
        """);
        database.db.execute("""
          UPDATE users
          SET username = lower(trim(username)),
              display_name = trim(display_name),
              updated_at = CASE
                WHEN updated_at IS NULL OR trim(updated_at) = '' THEN datetime('now')
                ELSE updated_at
              END
          WHERE trim(username) != '' OR trim(display_name) != ''
        """);
      },
    ),
    _DatabaseMigration(
      version: '006_inbound_notifications',
      description: 'Add inbound notification rules and deduplication events.',
      apply: (database) {
        database.db.execute('''
          CREATE TABLE IF NOT EXISTS inbound_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            source TEXT NOT NULL,
            event_type TEXT NOT NULL DEFAULT '',
            rule_key TEXT NOT NULL DEFAULT '',
            severity TEXT NOT NULL DEFAULT '',
            contains_text TEXT NOT NULL DEFAULT '',
            label_filters_json TEXT NOT NULL DEFAULT '{}',
            users_json TEXT NOT NULL DEFAULT '[]',
            groups_json TEXT NOT NULL DEFAULT '[]',
            channels_json TEXT NOT NULL DEFAULT '[]',
            message_template TEXT NOT NULL DEFAULT '',
            enabled INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        database.db.execute('''
          CREATE TABLE IF NOT EXISTS inbound_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT NOT NULL,
            event_type TEXT NOT NULL DEFAULT '',
            request_id TEXT NOT NULL,
            rule_id INTEGER,
            campaign_id INTEGER,
            status TEXT NOT NULL,
            error_message TEXT,
            payload_json TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (rule_id) REFERENCES inbound_rules(id),
            FOREIGN KEY (campaign_id) REFERENCES campaigns(id),
            UNIQUE(source, request_id)
          );
        ''');
      },
    ),
  ];

  void _ensureColumn({
    required String table,
    required String column,
    required String definition,
  }) {
    final columns = db.select('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}

class _DatabaseMigration {
  _DatabaseMigration({
    required this.version,
    required this.description,
    required this.apply,
  });

  final String version;
  final String description;
  final void Function(AppDatabase database) apply;
}
