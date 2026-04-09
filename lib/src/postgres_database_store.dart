import 'dart:convert';

import 'package:postgres/postgres.dart';

import 'database_store.dart';

class PostgresDatabaseStore implements DatabaseStore {
  PostgresDatabaseStore({required this.connectionUrl});

  final String connectionUrl;
  Pool<dynamic>? _pool;

  Pool<dynamic> get _db =>
      _pool ?? (throw StateError('PostgreSQL store has not been initialized.'));

  @override
  Future<void> initialize() async {
    _pool ??= Pool.withUrl(connectionUrl);
    await _db.execute('SET TIME ZONE \'UTC\'', ignoreRows: true);
    await _initializeMigrationTable();
    await _runMigrations();
    await purgeExpiredSessions(DateTime.now().toUtc());
    await purgeExpiredPasswordResetTokens(DateTime.now().toUtc());
  }

  @override
  Future<void> ensureBootstrapAdmin({
    required String username,
    required String displayName,
    required String? email,
    required String passwordHash,
    bool forcePasswordSync = false,
  }) async {
    final existing = await getUserByUsername(username);
    if (existing != null) {
      await updateBootstrapAdmin(
        id: existing['id'] as int,
        displayName: displayName,
        email: email,
        passwordHash: forcePasswordSync ? passwordHash : null,
      );
      return;
    }

    await createUser(
      username: username,
      displayName: displayName,
      email: email,
      passwordHash: passwordHash,
      role: 'admin',
      isActive: true,
    );
  }

  @override
  Future<int> createUser({
    required String username,
    required String displayName,
    required String? email,
    required String passwordHash,
    required String role,
    required bool isActive,
    String authProvider = 'local',
    String? externalSubject,
  }) async {
    final result = await _db.execute(
      r'''
      INSERT INTO users (
        username,
        display_name,
        email,
        auth_provider,
        external_subject,
        password_hash,
        role,
        is_active
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id
      ''',
      parameters: [
        username,
        displayName,
        email,
        authProvider,
        externalSubject,
        passwordHash,
        role,
        isActive,
      ],
    );
    return _asInt(result.first[0])!;
  }

  @override
  Future<Map<String, Object?>?> getUserByUsername(String username) async {
    final rows = await _db.execute(
      r'''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE lower(username) = lower($1)
      LIMIT 1
      ''',
      parameters: [username],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _userRowToMap(rows.first.toColumnMap());
  }

  @override
  Future<Map<String, Object?>?> getUserById(int id) async {
    final rows = await _db.execute(
      r'''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE id = $1
      LIMIT 1
      ''',
      parameters: [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _userRowToMap(rows.first.toColumnMap());
  }

  @override
  Future<Map<String, Object?>?> getUserByEmail(String email) async {
    final rows = await _db.execute(
      r'''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE lower(email) = lower($1)
      LIMIT 1
      ''',
      parameters: [email],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _userRowToMap(rows.first.toColumnMap());
  }

  @override
  Future<List<Map<String, Object?>>> listUsers() async {
    final rows = await _db.execute('''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      ORDER BY role DESC, display_name ASC, username ASC
    ''');
    return rows
        .map((row) => _userRowToMap(row.toColumnMap()))
        .toList(growable: false);
  }

  @override
  Future<void> updateUser({
    required int id,
    required String displayName,
    required String email,
    required String role,
    required bool isActive,
    String? passwordHash,
  }) async {
    if (passwordHash != null && passwordHash.isNotEmpty) {
      await _db.execute(
        r'''
        UPDATE users
        SET display_name = $1, email = $2, role = $3, is_active = $4, password_hash = $5, updated_at = NOW()
        WHERE id = $6
        ''',
        parameters: [displayName, email, role, isActive, passwordHash, id],
        ignoreRows: true,
      );
      return;
    }

    await _db.execute(
      r'''
      UPDATE users
      SET display_name = $1, email = $2, role = $3, is_active = $4, updated_at = NOW()
      WHERE id = $5
      ''',
      parameters: [displayName, email, role, isActive, id],
      ignoreRows: true,
    );
  }

  @override
  Future<void> updateOwnProfile({
    required int id,
    required String displayName,
    required String email,
    String? passwordHash,
  }) async {
    if (passwordHash != null && passwordHash.isNotEmpty) {
      await _db.execute(
        r'''
        UPDATE users
        SET display_name = $1, email = $2, password_hash = $3, updated_at = NOW()
        WHERE id = $4
        ''',
        parameters: [displayName, email, passwordHash, id],
        ignoreRows: true,
      );
      return;
    }

    await _db.execute(
      r'''
      UPDATE users
      SET display_name = $1, email = $2, updated_at = NOW()
      WHERE id = $3
      ''',
      parameters: [displayName, email, id],
      ignoreRows: true,
    );
  }

  @override
  Future<void> updateUserEmail({required int id, required String? email}) async {
    await _db.execute(
      r'UPDATE users SET email = $1, updated_at = NOW() WHERE id = $2',
      parameters: [email, id],
      ignoreRows: true,
    );
  }

  Future<void> updateBootstrapAdmin({
    required int id,
    required String displayName,
    required String? email,
    String? passwordHash,
  }) async {
    final normalizedEmail = email?.trim();
    final effectiveEmail =
        normalizedEmail != null && normalizedEmail.isNotEmpty
            ? normalizedEmail
            : null;

    if (passwordHash != null && passwordHash.isNotEmpty) {
      await _db.execute(
        r'''
        UPDATE users
        SET display_name = $1,
            email = COALESCE($2, email),
            password_hash = $3,
            role = 'admin',
            is_active = TRUE,
            auth_provider = 'local',
            updated_at = NOW()
        WHERE id = $4
        ''',
        parameters: [displayName, effectiveEmail, passwordHash, id],
        ignoreRows: true,
      );
      return;
    }

    await _db.execute(
      r'''
      UPDATE users
      SET display_name = $1,
          email = COALESCE($2, email),
          role = 'admin',
          is_active = TRUE,
          auth_provider = 'local',
          updated_at = NOW()
      WHERE id = $3
      ''',
      parameters: [displayName, effectiveEmail, id],
      ignoreRows: true,
    );
  }

  @override
  Future<Map<String, Object?>?> getUserByExternalIdentity({
    required String authProvider,
    required String externalSubject,
  }) async {
    final rows = await _db.execute(
      r'''
      SELECT id, username, display_name, email, auth_provider, external_subject, password_hash, role, is_active, created_at, updated_at
      FROM users
      WHERE auth_provider = $1 AND external_subject = $2
      LIMIT 1
      ''',
      parameters: [authProvider, externalSubject],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _userRowToMap(rows.first.toColumnMap());
  }

  @override
  Future<void> linkExternalIdentity({
    required int id,
    required String authProvider,
    required String externalSubject,
  }) async {
    await _db.execute(
      r'''
      UPDATE users
      SET auth_provider = $1, external_subject = $2, updated_at = NOW()
      WHERE id = $3
      ''',
      parameters: [authProvider, externalSubject, id],
      ignoreRows: true,
    );
  }

  @override
  Future<int> countActiveAdmins() async {
    final result = await _db.execute(
      r'SELECT COUNT(*) AS total FROM users WHERE role = $1 AND is_active = TRUE',
      parameters: ['admin'],
    );
    return _asInt(result.first.toColumnMap()['total']) ?? 0;
  }

  @override
  Future<void> insertSession({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) async {
    await _db.execute(
      r'''
      INSERT INTO sessions (token, user_id, created_at, expires_at)
      VALUES ($1, $2, $3, $4)
      ''',
      parameters: [token, userId, createdAt.toUtc(), expiresAt.toUtc()],
      ignoreRows: true,
    );
  }

  @override
  Future<Map<String, Object?>?> getSession(String token) async {
    final rows = await _db.execute(
      r'''
      SELECT s.token, s.user_id, s.created_at, s.expires_at,
             u.id, u.username, u.display_name, u.email, u.auth_provider, u.external_subject, u.password_hash, u.role, u.is_active, u.created_at AS user_created_at, u.updated_at AS user_updated_at
      FROM sessions s
      JOIN users u ON u.id = s.user_id
      WHERE s.token = $1 AND s.expires_at > NOW()
      LIMIT 1
      ''',
      parameters: [token],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first.toColumnMap();
    return {
      'token': row['token'],
      'userId': _asInt(row['user_id']),
      'createdAt': _dateIso(row['created_at']),
      'expiresAt': _dateIso(row['expires_at']),
      'user': {
        'id': _asInt(row['id']),
        'username': row['username'],
        'displayName': row['display_name'],
        'email': row['email'],
        'authProvider': row['auth_provider'],
        'externalSubject': row['external_subject'],
        'passwordHash': row['password_hash'],
        'role': row['role'],
        'isActive': _asBool(row['is_active']),
        'createdAt': _dateIso(row['user_created_at']),
        'updatedAt': _dateIso(row['user_updated_at']),
      },
    };
  }

  @override
  Future<void> deleteSession(String token) async {
    await _db.execute(
      r'DELETE FROM sessions WHERE token = $1',
      parameters: [token],
      ignoreRows: true,
    );
  }

  @override
  Future<void> purgeExpiredSessions(DateTime now) async {
    await _db.execute(
      r'DELETE FROM sessions WHERE expires_at <= $1',
      parameters: [now.toUtc()],
      ignoreRows: true,
    );
  }

  @override
  Future<void> insertPasswordResetToken({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) async {
    await _db.execute(
      r'''
      INSERT INTO password_reset_tokens (token, user_id, expires_at, created_at, used_at)
      VALUES ($1, $2, $3, $4, NULL)
      ''',
      parameters: [token, userId, expiresAt.toUtc(), createdAt.toUtc()],
      ignoreRows: true,
    );
  }

  @override
  Future<Map<String, Object?>?> getPasswordResetToken(String token) async {
    final rows = await _db.execute(
      r'''
      SELECT prt.token, prt.user_id, prt.expires_at, prt.created_at, prt.used_at,
             u.id, u.username, u.display_name, u.email, u.auth_provider, u.external_subject, u.password_hash, u.role, u.is_active, u.created_at AS user_created_at, u.updated_at AS user_updated_at
      FROM password_reset_tokens prt
      JOIN users u ON u.id = prt.user_id
      WHERE prt.token = $1 AND prt.used_at IS NULL AND prt.expires_at > NOW()
      LIMIT 1
      ''',
      parameters: [token],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first.toColumnMap();
    return {
      'token': row['token'],
      'userId': _asInt(row['user_id']),
      'expiresAt': _dateIso(row['expires_at']),
      'createdAt': _dateIso(row['created_at']),
      'usedAt': _dateIso(row['used_at']),
      'user': {
        'id': _asInt(row['id']),
        'username': row['username'],
        'displayName': row['display_name'],
        'email': row['email'],
        'authProvider': row['auth_provider'],
        'externalSubject': row['external_subject'],
        'passwordHash': row['password_hash'],
        'role': row['role'],
        'isActive': _asBool(row['is_active']),
        'createdAt': _dateIso(row['user_created_at']),
        'updatedAt': _dateIso(row['user_updated_at']),
      },
    };
  }

  @override
  Future<void> markPasswordResetTokenUsed(String token) async {
    await _db.execute(
      r'UPDATE password_reset_tokens SET used_at = NOW() WHERE token = $1',
      parameters: [token],
      ignoreRows: true,
    );
  }

  @override
  Future<void> purgeExpiredPasswordResetTokens(DateTime now) async {
    await _db.execute(
      r'''
      DELETE FROM password_reset_tokens
      WHERE (expires_at <= $1) OR (used_at IS NOT NULL AND used_at <= $1 - INTERVAL '7 days')
      ''',
      parameters: [now.toUtc()],
      ignoreRows: true,
    );
  }

  @override
  Future<Map<String, String>> getSettings() async {
    final rows = await _db.execute('SELECT key, value FROM settings');
    return {
      for (final row in rows)
        row.toColumnMap()['key'] as String: row.toColumnMap()['value'] as String,
    };
  }

  @override
  Future<void> upsertSettings(Map<String, String?> values) async {
    await _db.runTx((session) async {
      for (final entry in values.entries) {
        if (entry.value == null) {
          await session.execute(
            r'DELETE FROM settings WHERE key = $1',
            parameters: [entry.key],
            ignoreRows: true,
          );
          continue;
        }

        await session.execute(
          r'''
          INSERT INTO settings (key, value, updated_at)
          VALUES ($1, $2, NOW())
          ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
          ''',
          parameters: [entry.key, entry.value],
          ignoreRows: true,
        );
      }
    });
  }

  @override
  Future<bool> hasMattermostDirectoryUsers() => _hasRows(
    'SELECT 1 FROM mattermost_directory_users LIMIT 1',
  );

  @override
  Future<bool> hasMattermostDirectoryGroups() => _hasRows(
    'SELECT 1 FROM mattermost_directory_groups LIMIT 1',
  );

  @override
  Future<bool> hasMattermostDirectoryChannels() => _hasRows(
    'SELECT 1 FROM mattermost_directory_channels LIMIT 1',
  );

  @override
  Future<void> replaceMattermostDirectoryUsers(
    List<Map<String, Object?>> users,
  ) async {
    final now = DateTime.now().toUtc();
    await _db. runTx((session) async {
      await session.execute(
        'DELETE FROM mattermost_directory_users',
        ignoreRows: true,
      );
      final seenIds = <String>{};
      for (final user in users) {
        final id = (user['id'] as String? ?? '').trim();
        if (id.isEmpty || !seenIds.add(id)) {
          continue;
        }
        await session.execute(
          r'''
          INSERT INTO mattermost_directory_users (id, username, display_name, email, updated_at)
          VALUES ($1, $2, $3, $4, $5)
          ''',
          parameters: [
            id,
            (user['username'] as String? ?? '').trim(),
            (user['displayName'] as String? ?? '').trim(),
            (user['email'] as String? ?? '').trim(),
            now,
          ],
          ignoreRows: true,
        );
      }
      await _upsertSettingsSession(
        session,
        {'mattermost.directoryUsersSyncedAt': now.toIso8601String()},
      );
    });
  }

  @override
  Future<void> replaceMattermostDirectoryGroups(
    List<Map<String, Object?>> groups,
  ) async {
    final now = DateTime.now().toUtc();
    await _db. runTx((session) async {
      await session.execute(
        'DELETE FROM mattermost_directory_groups',
        ignoreRows: true,
      );
      final seenIds = <String>{};
      for (final group in groups) {
        final id = (group['id'] as String? ?? '').trim();
        if (id.isEmpty || !seenIds.add(id)) {
          continue;
        }
        await session.execute(
          r'''
          INSERT INTO mattermost_directory_groups (id, name, display_name, member_count, updated_at)
          VALUES ($1, $2, $3, $4, $5)
          ''',
          parameters: [
            id,
            (group['name'] as String? ?? '').trim(),
            (group['displayName'] as String? ?? '').trim(),
            (group['memberCount'] as num?)?.toInt() ?? 0,
            now,
          ],
          ignoreRows: true,
        );
      }
      await _upsertSettingsSession(
        session,
        {'mattermost.directoryGroupsSyncedAt': now.toIso8601String()},
      );
    });
  }

  @override
  Future<void> replaceMattermostDirectoryChannels(
    List<Map<String, Object?>> channels,
  ) async {
    final now = DateTime.now().toUtc();
    await _db. runTx((session) async {
      await session.execute(
        'DELETE FROM mattermost_directory_channels',
        ignoreRows: true,
      );
      final seenIds = <String>{};
      for (final channel in channels) {
        final id = (channel['id'] as String? ?? '').trim();
        if (id.isEmpty || !seenIds.add(id)) {
          continue;
        }
        await session.execute(
          r'''
          INSERT INTO mattermost_directory_channels (id, name, display_name, channel_type, updated_at)
          VALUES ($1, $2, $3, $4, $5)
          ''',
          parameters: [
            id,
            (channel['name'] as String? ?? '').trim(),
            (channel['displayName'] as String? ?? '').trim(),
            (channel['type'] as String? ?? '').trim(),
            now,
          ],
          ignoreRows: true,
        );
      }
      await _upsertSettingsSession(
        session,
        {'mattermost.directoryChannelsSyncedAt': now.toIso8601String()},
      );
    });
  }

  @override
  Future<List<Map<String, Object?>>> searchMattermostDirectoryUsers(
    String query,
  ) async {
    final normalized = '%${query.trim().toLowerCase()}%';
    final rows = query.trim().isEmpty
        ? await _db.execute('''
            SELECT id, username, display_name, email
            FROM mattermost_directory_users
            ORDER BY lower(display_name), lower(username)
            LIMIT 50
          ''')
        : await _db.execute(
            r'''
            SELECT id, username, display_name, email
            FROM mattermost_directory_users
            WHERE lower(username) LIKE $1
               OR lower(display_name) LIKE $2
               OR lower(email) LIKE $3
            ORDER BY
              CASE
                WHEN lower(username) = $4 THEN 0
                WHEN lower(username) LIKE $5 THEN 1
                ELSE 2
              END,
              lower(display_name),
              lower(username)
            LIMIT 50
            ''',
            parameters: [
              normalized,
              normalized,
              normalized,
              query.trim().toLowerCase(),
              normalized,
            ],
          );
    return rows
        .map((row) => row.toColumnMap())
        .map(
          (row) => {
            'id': row['id'],
            'username': row['username'],
            'displayName': row['display_name'],
            'email': row['email'],
          },
        )
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, Object?>>> searchMattermostDirectoryGroups(
    String query,
  ) async {
    final normalized = '%${query.trim().toLowerCase()}%';
    final rows = query.trim().isEmpty
        ? await _db.execute('''
            SELECT id, name, display_name, member_count
            FROM mattermost_directory_groups
            ORDER BY lower(display_name), lower(name)
            LIMIT 50
          ''')
        : await _db.execute(
            r'''
            SELECT id, name, display_name, member_count
            FROM mattermost_directory_groups
            WHERE lower(name) LIKE $1
               OR lower(display_name) LIKE $2
            ORDER BY lower(display_name), lower(name)
            LIMIT 50
            ''',
            parameters: [normalized, normalized],
          );
    return rows
        .map((row) => row.toColumnMap())
        .map(
          (row) => {
            'id': row['id'],
            'name': row['name'],
            'displayName': row['display_name'],
            'memberCount': _asInt(row['member_count']) ?? 0,
          },
        )
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, Object?>>> searchMattermostDirectoryChannels(
    String query,
  ) async {
    final normalized = '%${query.trim().toLowerCase()}%';
    final rows = query.trim().isEmpty
        ? await _db.execute('''
            SELECT id, name, display_name, channel_type
            FROM mattermost_directory_channels
            ORDER BY lower(display_name), lower(name)
            LIMIT 100
          ''')
        : await _db.execute(
            r'''
            SELECT id, name, display_name, channel_type
            FROM mattermost_directory_channels
            WHERE lower(name) LIKE $1
               OR lower(display_name) LIKE $2
            ORDER BY lower(display_name), lower(name)
            LIMIT 100
            ''',
            parameters: [normalized, normalized],
          );
    return rows
        .map((row) => row.toColumnMap())
        .map(
          (row) => {
            'id': row['id'],
            'name': row['name'],
            'displayName': row['display_name'],
            'type': row['channel_type'],
          },
        )
        .toList(growable: false);
  }

  @override
  Future<int> insertCampaign({
    required DateTime createdAt,
    required String createdBy,
    required String message,
    required List<Map<String, Object?>> users,
    required List<Map<String, Object?>> groups,
    required List<String> channels,
  }) async {
    final result = await _db.execute(
      r'''
      INSERT INTO campaigns (
        created_at,
        created_by,
        message,
        users_json,
        groups_json,
        channels_json
      ) VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6::jsonb)
      RETURNING id
      ''',
      parameters: [
        createdAt.toUtc(),
        createdBy,
        message,
        jsonEncode(users),
        jsonEncode(groups),
        jsonEncode(channels),
      ],
    );
    return _asInt(result.first[0])!;
  }

  @override
  Future<void> insertDelivery({
    required int campaignId,
    required String targetType,
    required String targetKey,
    required String targetLabel,
    required String status,
    DateTime? sentAt,
    String? errorMessage,
    Map<String, Object?>? responsePayload,
  }) async {
    await _db.execute(
      r'''
      INSERT INTO deliveries (
        campaign_id,
        target_type,
        target_key,
        target_label,
        status,
        sent_at,
        error_message,
        response_payload
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
      ''',
      parameters: [
        campaignId,
        targetType,
        targetKey,
        targetLabel,
        status,
        sentAt?.toUtc(),
        errorMessage,
        responsePayload == null ? null : jsonEncode(responsePayload),
      ],
      ignoreRows: true,
    );
  }

  @override
  Future<void> updateCampaignSummary({
    required int campaignId,
    required int sentCount,
    required int failedCount,
  }) async {
    await _db.execute(
      r'''
      UPDATE campaigns
      SET sent_count = $1, failed_count = $2
      WHERE id = $3
      ''',
      parameters: [sentCount, failedCount, campaignId],
      ignoreRows: true,
    );
  }

  @override
  Future<int> insertInboundRule({
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
  }) async {
    final result = await _db.execute(
      r'''
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
        enabled
      ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, $11, $12)
      RETURNING id
      ''',
      parameters: [
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
        enabled,
      ],
    );
    return _asInt(result.first[0])!;
  }

  @override
  Future<void> updateInboundRule({
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
  }) async {
    await _db.execute(
      r'''
      UPDATE inbound_rules
      SET name = $1,
          source = $2,
          event_type = $3,
          rule_key = $4,
          severity = $5,
          contains_text = $6,
          label_filters_json = $7::jsonb,
          users_json = $8::jsonb,
          groups_json = $9::jsonb,
          channels_json = $10::jsonb,
          message_template = $11,
          enabled = $12,
          updated_at = NOW()
      WHERE id = $13
      ''',
      parameters: [
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
        enabled,
        id,
      ],
      ignoreRows: true,
    );
  }

  @override
  Future<List<Map<String, Object?>>> listInboundRules() async {
    final rows = await _db.execute(_inboundRuleListQuery);
    return rows
        .map((row) => _inboundRuleRowToMap(row.toColumnMap()))
        .toList(growable: false);
  }

  @override
  Future<Map<String, Object?>?> getInboundRuleById(int id) async {
    final rows = await _db.execute(
      '$_inboundRuleListQuery WHERE ir.id = \$1 LIMIT 1',
      parameters: [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _inboundRuleRowToMap(rows.first.toColumnMap());
  }

  @override
  Future<Map<String, Object?>?> getInboundRuleByKey({
    required String source,
    required String ruleKey,
  }) async {
    final rows = await _db.execute(
      r'''
      $_inboundRuleListQuery
      WHERE lower(ir.source) = lower($1) AND lower(ir.rule_key) = lower($2) AND ir.enabled = TRUE
      LIMIT 1
      ''',
      parameters: [source, ruleKey],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _inboundRuleRowToMap(rows.first.toColumnMap());
  }

  @override
  Future<List<Map<String, Object?>>> listActiveInboundRulesBySource(
    String source,
  ) async {
    final rows = await _db.execute(
      r'''
      $_inboundRuleListQuery
      WHERE lower(ir.source) = lower($1) AND ir.enabled = TRUE
      ORDER BY ir.updated_at DESC, ir.id DESC
      ''',
      parameters: [source],
    );
    return rows
        .map((row) => _inboundRuleRowToMap(row.toColumnMap()))
        .toList(growable: false);
  }

  @override
  Future<int> insertInboundEvent({
    required String source,
    required String eventType,
    required String requestId,
    required String status,
    int? ruleId,
    int? campaignId,
    String? errorMessage,
    Map<String, Object?>? payload,
  }) async {
    final result = await _db.execute(
      r'''
      INSERT INTO inbound_events (
        source,
        event_type,
        request_id,
        rule_id,
        campaign_id,
        status,
        error_message,
        payload_json
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
      RETURNING id
      ''',
      parameters: [
        source,
        eventType,
        requestId,
        ruleId,
        campaignId,
        status,
        errorMessage,
        payload == null ? null : jsonEncode(payload),
      ],
    );
    return _asInt(result.first[0])!;
  }

  @override
  Future<Map<String, Object?>?> getInboundEventByRequestId({
    required String source,
    required String requestId,
  }) async {
    final rows = await _db.execute(
      r'''
      SELECT id, source, event_type, request_id, rule_id, campaign_id, status, error_message, payload_json, created_at, updated_at
      FROM inbound_events
      WHERE lower(source) = lower($1) AND request_id = $2
      LIMIT 1
      ''',
      parameters: [source, requestId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first.toColumnMap();
    return {
      'id': _asInt(row['id']),
      'source': row['source'],
      'eventType': row['event_type'],
      'requestId': row['request_id'],
      'ruleId': _asInt(row['rule_id']),
      'campaignId': _asInt(row['campaign_id']),
      'status': row['status'],
      'errorMessage': row['error_message'],
      'payload': _decodeJson(row['payload_json']),
      'createdAt': _dateIso(row['created_at']),
      'updatedAt': _dateIso(row['updated_at']),
    };
  }

  @override
  Future<List<Map<String, Object?>>> listInboundEvents({
    int limit = 10,
    String? source,
  }) async {
    final filterBySource = source != null && source.trim().isNotEmpty;
    final rows = await _db.execute(
      r'''
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
      ${filterBySource ? 'WHERE lower(ie.source) = lower($1)' : ''}
      ORDER BY ie.id DESC
      LIMIT \$${filterBySource ? 2 : 1}
      ''',
      parameters: filterBySource
          ? [source.trim(), limit.clamp(1, 100)]
          : [limit.clamp(1, 100)],
    );
    return rows.map((row) {
      final mapped = row.toColumnMap();
      final payload = _decodeJson(mapped['payload_json']);
      final payloadMap = payload is Map
          ? Map<String, Object?>.from(payload)
          : <String, Object?>{};
      return {
        'id': _asInt(mapped['id']),
        'source': mapped['source'],
        'eventType': mapped['event_type'],
        'requestId': mapped['request_id'],
        'ruleId': _asInt(mapped['rule_id']),
        'ruleName': mapped['rule_name'],
        'campaignId': _asInt(mapped['campaign_id']),
        'status': mapped['status'],
        'errorMessage': mapped['error_message'],
        'title': payloadMap['title'],
        'message': payloadMap['message'],
        'createdAt': _dateIso(mapped['created_at']),
        'updatedAt': _dateIso(mapped['updated_at']),
      };
    }).toList(growable: false);
  }

  @override
  Future<List<Map<String, Object?>>> listCampaigns({
    int limit = 20,
    String? createdBy,
  }) async {
    final hasCreatedBy = createdBy != null && createdBy.isNotEmpty;
    final campaigns = await _db.execute(
      r'''
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
      ${hasCreatedBy ? 'WHERE created_by = \$1' : ''}
      ORDER BY id DESC
      LIMIT \$${hasCreatedBy ? 2 : 1}
      ''',
      parameters: hasCreatedBy ? [createdBy, limit] : [limit],
    );

    final deliveries = await _db.execute('''
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
      final mapped = row.toColumnMap();
      final campaignId = _asInt(mapped['campaign_id'])!;
      deliveriesByCampaign.putIfAbsent(campaignId, () => []).add({
        'id': _asInt(mapped['id']),
        'targetType': mapped['target_type'],
        'targetKey': mapped['target_key'],
        'targetLabel': mapped['target_label'],
        'status': mapped['status'],
        'sentAt': _dateIso(mapped['sent_at']),
        'errorMessage': mapped['error_message'],
        'responsePayload': _decodeJson(mapped['response_payload']),
      });
    }

    final inboundEvents = await _db.execute('''
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
      final mapped = row.toColumnMap();
      final campaignId = _asInt(mapped['campaign_id']);
      if (campaignId == null || inboundByCampaign.containsKey(campaignId)) {
        continue;
      }
      inboundByCampaign[campaignId] = {
        'kind': 'inbound',
        'source': mapped['source'],
        'eventType': mapped['event_type'],
        'requestId': mapped['request_id'],
        'ruleId': _asInt(mapped['rule_id']),
        'ruleName': mapped['rule_name'],
        'status': mapped['status'],
        'errorMessage': mapped['error_message'],
      };
    }

    return campaigns.map((row) {
      final mapped = row.toColumnMap();
      final id = _asInt(mapped['id'])!;
      return {
        'id': id,
        'createdAt': _dateIso(mapped['created_at']),
        'createdBy': mapped['created_by'],
        'message': mapped['message'],
        'trigger': inboundByCampaign[id] ?? <String, Object?>{'kind': 'manual'},
        'users': _decodeJson(mapped['users_json']) ?? const <Object?>[],
        'groups': _decodeJson(mapped['groups_json']) ?? const <Object?>[],
        'channels': _decodeJson(mapped['channels_json']) ?? const <Object?>[],
        'sentCount': _asInt(mapped['sent_count']) ?? 0,
        'failedCount': _asInt(mapped['failed_count']) ?? 0,
        'deliveries':
            deliveriesByCampaign[id] ?? <Map<String, Object?>>[],
      };
    }).toList(growable: false);
  }

  @override
  Future<void> close() async {
    final pool = _pool;
    _pool = null;
    if (pool != null) {
      await pool.close();
    }
  }

  Future<void> _initializeMigrationTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        executed_at TIMESTAMPTZ NOT NULL
      )
    ''', ignoreRows: true);
  }

  Future<void> _runMigrations() async {
    final appliedRows = await _db.execute('SELECT version FROM schema_migrations');
    final applied = appliedRows
        .map((row) => row.toColumnMap()['version'] as String)
        .toSet();

    for (final migration in _migrations) {
      if (applied.contains(migration.version)) {
        continue;
      }
      await migration.apply(this);
      await _db.execute(
        r'''
        INSERT INTO schema_migrations (version, description, executed_at)
        VALUES ($1, $2, NOW())
        ''',
        parameters: [migration.version, migration.description],
        ignoreRows: true,
      );
    }
  }

  Future<void> _createFullSchema() async {
    await _db. runTx((session) async {
      await session.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id BIGSERIAL PRIMARY KEY,
          username TEXT NOT NULL UNIQUE,
          display_name TEXT NOT NULL,
          email TEXT,
          auth_provider TEXT NOT NULL DEFAULT 'local',
          external_subject TEXT,
          password_hash TEXT NOT NULL,
          role TEXT NOT NULL,
          is_active BOOLEAN NOT NULL DEFAULT TRUE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          token TEXT PRIMARY KEY,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          created_at TIMESTAMPTZ NOT NULL,
          expires_at TIMESTAMPTZ NOT NULL
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS campaigns (
          id BIGSERIAL PRIMARY KEY,
          created_at TIMESTAMPTZ NOT NULL,
          created_by TEXT NOT NULL,
          message TEXT NOT NULL,
          users_json JSONB NOT NULL DEFAULT '[]'::jsonb,
          groups_json JSONB NOT NULL DEFAULT '[]'::jsonb,
          channels_json JSONB NOT NULL DEFAULT '[]'::jsonb,
          sent_count INTEGER NOT NULL DEFAULT 0,
          failed_count INTEGER NOT NULL DEFAULT 0
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS deliveries (
          id BIGSERIAL PRIMARY KEY,
          campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
          target_type TEXT NOT NULL,
          target_key TEXT NOT NULL,
          target_label TEXT NOT NULL,
          status TEXT NOT NULL,
          sent_at TIMESTAMPTZ,
          error_message TEXT,
          response_payload JSONB
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS password_reset_tokens (
          token TEXT PRIMARY KEY,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          expires_at TIMESTAMPTZ NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          used_at TIMESTAMPTZ
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS mattermost_directory_users (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL,
          display_name TEXT NOT NULL,
          email TEXT NOT NULL DEFAULT '',
          updated_at TIMESTAMPTZ NOT NULL
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS mattermost_directory_groups (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          display_name TEXT NOT NULL,
          member_count INTEGER NOT NULL DEFAULT 0,
          updated_at TIMESTAMPTZ NOT NULL
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS mattermost_directory_channels (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          display_name TEXT NOT NULL,
          channel_type TEXT NOT NULL DEFAULT '',
          updated_at TIMESTAMPTZ NOT NULL
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS inbound_rules (
          id BIGSERIAL PRIMARY KEY,
          name TEXT NOT NULL,
          source TEXT NOT NULL,
          event_type TEXT NOT NULL DEFAULT '',
          rule_key TEXT NOT NULL DEFAULT '',
          severity TEXT NOT NULL DEFAULT '',
          contains_text TEXT NOT NULL DEFAULT '',
          label_filters_json JSONB NOT NULL DEFAULT '{}'::jsonb,
          users_json JSONB NOT NULL DEFAULT '[]'::jsonb,
          groups_json JSONB NOT NULL DEFAULT '[]'::jsonb,
          channels_json JSONB NOT NULL DEFAULT '[]'::jsonb,
          message_template TEXT NOT NULL DEFAULT '',
          enabled BOOLEAN NOT NULL DEFAULT TRUE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      ''', ignoreRows: true);

      await session.execute('''
        CREATE TABLE IF NOT EXISTS inbound_events (
          id BIGSERIAL PRIMARY KEY,
          source TEXT NOT NULL,
          event_type TEXT NOT NULL DEFAULT '',
          request_id TEXT NOT NULL,
          rule_id BIGINT REFERENCES inbound_rules(id) ON DELETE SET NULL,
          campaign_id BIGINT REFERENCES campaigns(id) ON DELETE SET NULL,
          status TEXT NOT NULL,
          error_message TEXT,
          payload_json JSONB,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE(source, request_id)
        )
      ''', ignoreRows: true);

      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_users_username ON mattermost_directory_users(username)',
        ignoreRows: true,
      );
      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_users_display_name ON mattermost_directory_users(display_name)',
        ignoreRows: true,
      );
      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_groups_name ON mattermost_directory_groups(name)',
        ignoreRows: true,
      );
      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_mattermost_directory_channels_name ON mattermost_directory_channels(name)',
        ignoreRows: true,
      );
      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at)',
        ignoreRows: true,
      );
      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires_at ON password_reset_tokens(expires_at)',
        ignoreRows: true,
      );
      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_inbound_events_campaign_id ON inbound_events(campaign_id)',
        ignoreRows: true,
      );
      await session.execute(
        'CREATE INDEX IF NOT EXISTS idx_inbound_events_rule_id ON inbound_events(rule_id)',
        ignoreRows: true,
      );
    });
  }

  Future<void> _upsertSettingsSession(
    Session session,
    Map<String, String?> values,
  ) async {
    for (final entry in values.entries) {
      if (entry.value == null) {
        await session.execute(
          r'DELETE FROM settings WHERE key = $1',
          parameters: [entry.key],
          ignoreRows: true,
        );
        continue;
      }
      await session.execute(
        r'''
        INSERT INTO settings (key, value, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
        ''',
        parameters: [entry.key, entry.value],
        ignoreRows: true,
      );
    }
  }

  Future<bool> _hasRows(String query) async {
    final rows = await _db.execute(query);
    return rows.isNotEmpty;
  }

  Map<String, Object?> _userRowToMap(Map<String, dynamic> row) {
    return {
      'id': _asInt(row['id']),
      'username': row['username'],
      'displayName': row['display_name'],
      'email': row['email'],
      'authProvider': row['auth_provider'],
      'externalSubject': row['external_subject'],
      'passwordHash': row['password_hash'],
      'role': row['role'],
      'isActive': _asBool(row['is_active']),
      'createdAt': _dateIso(row['created_at']),
      'updatedAt': _dateIso(row['updated_at']),
    };
  }

  Map<String, Object?> _inboundRuleRowToMap(Map<String, dynamic> row) {
    return {
      'id': _asInt(row['id']),
      'name': row['name'],
      'source': row['source'],
      'eventType': row['event_type'],
      'ruleKey': row['rule_key'],
      'severity': row['severity'],
      'containsText': row['contains_text'],
      'labelFilters': _decodeJson(row['label_filters_json']) == null
          ? <String, Object?>{}
          : Map<String, Object?>.from(_decodeJson(row['label_filters_json']) as Map),
      'users': _decodeJson(row['users_json']) ?? const <Object?>[],
      'groups': _decodeJson(row['groups_json']) ?? const <Object?>[],
      'channels': _decodeJson(row['channels_json']) ?? const <Object?>[],
      'messageTemplate': row['message_template'],
      'enabled': _asBool(row['enabled']),
      'totalRuns': _asInt(row['total_runs']) ?? 0,
      'failedRuns': _asInt(row['failed_runs']) ?? 0,
      'lastTriggeredAt': _dateIso(row['last_triggered_at']),
      'createdAt': _dateIso(row['created_at']),
      'updatedAt': _dateIso(row['updated_at']),
    };
  }

  Object? _decodeJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map || value is List) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return jsonDecode(value);
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is BigInt) {
      return value.toInt();
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 't';
    }
    return false;
  }

  String? _dateIso(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    return value.toString();
  }

  List<_PostgresMigration> get _migrations => [
    _PostgresMigration(
      version: '001_postgres_full_schema',
      description: 'Create core PostgreSQL schema for cannonball.',
      apply: (store) => store._createFullSchema(),
    ),
  ];
}

const String _inboundRuleListQuery = '''
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
''';

class _PostgresMigration {
  _PostgresMigration({
    required this.version,
    required this.description,
    required this.apply,
  });

  final String version;
  final String description;
  final Future<void> Function(PostgresDatabaseStore store) apply;
}
