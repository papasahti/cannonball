import 'database.dart';

abstract class DatabaseStore {
  Future<void> initialize();

  Future<void> ensureBootstrapAdmin({
    required String username,
    required String displayName,
    required String? email,
    required String passwordHash,
    bool forcePasswordSync = false,
  });

  Future<int> createUser({
    required String username,
    required String displayName,
    required String? email,
    required String passwordHash,
    required String role,
    required bool isActive,
    String authProvider = 'local',
    String? externalSubject,
  });

  Future<Map<String, Object?>?> getUserByUsername(String username);
  Future<Map<String, Object?>?> getUserById(int id);
  Future<Map<String, Object?>?> getUserByEmail(String email);
  Future<List<Map<String, Object?>>> listUsers();

  Future<void> updateUser({
    required int id,
    required String displayName,
    required String email,
    required String role,
    required bool isActive,
    String? passwordHash,
  });

  Future<void> updateOwnProfile({
    required int id,
    required String displayName,
    required String email,
    String? passwordHash,
  });

  Future<void> updateUserEmail({required int id, required String? email});

  Future<Map<String, Object?>?> getUserByExternalIdentity({
    required String authProvider,
    required String externalSubject,
  });

  Future<void> linkExternalIdentity({
    required int id,
    required String authProvider,
    required String externalSubject,
  });

  Future<int> countActiveAdmins();

  Future<void> insertSession({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  });

  Future<Map<String, Object?>?> getSession(String token);
  Future<void> deleteSession(String token);
  Future<void> purgeExpiredSessions(DateTime now);

  Future<void> insertPasswordResetToken({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  });

  Future<Map<String, Object?>?> getPasswordResetToken(String token);
  Future<void> markPasswordResetTokenUsed(String token);
  Future<void> purgeExpiredPasswordResetTokens(DateTime now);

  Future<Map<String, String>> getSettings();
  Future<void> upsertSettings(Map<String, String?> values);

  Future<bool> hasMattermostDirectoryUsers();
  Future<bool> hasMattermostDirectoryGroups();
  Future<bool> hasMattermostDirectoryChannels();

  Future<void> replaceMattermostDirectoryUsers(List<Map<String, Object?>> users);
  Future<void> replaceMattermostDirectoryGroups(List<Map<String, Object?>> groups);
  Future<void> replaceMattermostDirectoryChannels(
    List<Map<String, Object?>> channels,
  );

  Future<List<Map<String, Object?>>> searchMattermostDirectoryUsers(String query);
  Future<List<Map<String, Object?>>> searchMattermostDirectoryGroups(String query);
  Future<List<Map<String, Object?>>> searchMattermostDirectoryChannels(
    String query,
  );

  Future<int> insertCampaign({
    required DateTime createdAt,
    required String createdBy,
    required String message,
    required List<Map<String, Object?>> users,
    required List<Map<String, Object?>> groups,
    required List<String> channels,
  });

  Future<void> insertDelivery({
    required int campaignId,
    required String targetType,
    required String targetKey,
    required String targetLabel,
    required String status,
    DateTime? sentAt,
    String? errorMessage,
    Map<String, Object?>? responsePayload,
  });

  Future<void> updateCampaignSummary({
    required int campaignId,
    required int sentCount,
    required int failedCount,
  });

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
  });

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
  });

  Future<List<Map<String, Object?>>> listInboundRules();
  Future<Map<String, Object?>?> getInboundRuleById(int id);

  Future<Map<String, Object?>?> getInboundRuleByKey({
    required String source,
    required String ruleKey,
  });

  Future<List<Map<String, Object?>>> listActiveInboundRulesBySource(
    String source,
  );

  Future<int> insertInboundEvent({
    required String source,
    required String eventType,
    required String requestId,
    required String status,
    int? ruleId,
    int? campaignId,
    String? errorMessage,
    Map<String, Object?>? payload,
  });

  Future<Map<String, Object?>?> getInboundEventByRequestId({
    required String source,
    required String requestId,
  });

  Future<List<Map<String, Object?>>> listInboundEvents({
    int limit = 10,
    String? source,
  });

  Future<List<Map<String, Object?>>> listCampaigns({
    int limit = 20,
    String? createdBy,
  });

  Future<void> close();
}

class SqliteDatabaseStore implements DatabaseStore {
  SqliteDatabaseStore(this._database);

  final AppDatabase _database;

  @override
  Future<void> initialize() async => _database.initialize();

  @override
  Future<void> ensureBootstrapAdmin({
    required String username,
    required String displayName,
    required String? email,
    required String passwordHash,
    bool forcePasswordSync = false,
  }) async {
    _database.ensureBootstrapAdmin(
      username: username,
      displayName: displayName,
      email: email,
      passwordHash: passwordHash,
      forcePasswordSync: forcePasswordSync,
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
  }) async => _database.createUser(
    username: username,
    displayName: displayName,
    email: email,
    passwordHash: passwordHash,
    role: role,
    isActive: isActive,
    authProvider: authProvider,
    externalSubject: externalSubject,
  );

  @override
  Future<Map<String, Object?>?> getUserByUsername(String username) async =>
      _database.getUserByUsername(username);

  @override
  Future<Map<String, Object?>?> getUserById(int id) async =>
      _database.getUserById(id);

  @override
  Future<Map<String, Object?>?> getUserByEmail(String email) async =>
      _database.getUserByEmail(email);

  @override
  Future<List<Map<String, Object?>>> listUsers() async => _database.listUsers();

  @override
  Future<void> updateUser({
    required int id,
    required String displayName,
    required String email,
    required String role,
    required bool isActive,
    String? passwordHash,
  }) async {
    _database.updateUser(
      id: id,
      displayName: displayName,
      email: email,
      role: role,
      isActive: isActive,
      passwordHash: passwordHash,
    );
  }

  @override
  Future<void> updateOwnProfile({
    required int id,
    required String displayName,
    required String email,
    String? passwordHash,
  }) async {
    _database.updateOwnProfile(
      id: id,
      displayName: displayName,
      email: email,
      passwordHash: passwordHash,
    );
  }

  @override
  Future<void> updateUserEmail({required int id, required String? email}) async {
    _database.updateUserEmail(id: id, email: email);
  }

  @override
  Future<Map<String, Object?>?> getUserByExternalIdentity({
    required String authProvider,
    required String externalSubject,
  }) async => _database.getUserByExternalIdentity(
    authProvider: authProvider,
    externalSubject: externalSubject,
  );

  @override
  Future<void> linkExternalIdentity({
    required int id,
    required String authProvider,
    required String externalSubject,
  }) async {
    _database.linkExternalIdentity(
      id: id,
      authProvider: authProvider,
      externalSubject: externalSubject,
    );
  }

  @override
  Future<int> countActiveAdmins() async => _database.countActiveAdmins();

  @override
  Future<void> insertSession({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) async {
    _database.insertSession(
      token: token,
      userId: userId,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<Map<String, Object?>?> getSession(String token) async =>
      _database.getSession(token);

  @override
  Future<void> deleteSession(String token) async => _database.deleteSession(token);

  @override
  Future<void> purgeExpiredSessions(DateTime now) async =>
      _database.purgeExpiredSessions(now);

  @override
  Future<void> insertPasswordResetToken({
    required String token,
    required int userId,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) async {
    _database.insertPasswordResetToken(
      token: token,
      userId: userId,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<Map<String, Object?>?> getPasswordResetToken(String token) async =>
      _database.getPasswordResetToken(token);

  @override
  Future<void> markPasswordResetTokenUsed(String token) async =>
      _database.markPasswordResetTokenUsed(token);

  @override
  Future<void> purgeExpiredPasswordResetTokens(DateTime now) async =>
      _database.purgeExpiredPasswordResetTokens(now);

  @override
  Future<Map<String, String>> getSettings() async => _database.getSettings();

  @override
  Future<void> upsertSettings(Map<String, String?> values) async =>
      _database.upsertSettings(values);

  @override
  Future<bool> hasMattermostDirectoryUsers() async =>
      _database.hasMattermostDirectoryUsers();

  @override
  Future<bool> hasMattermostDirectoryGroups() async =>
      _database.hasMattermostDirectoryGroups();

  @override
  Future<bool> hasMattermostDirectoryChannels() async =>
      _database.hasMattermostDirectoryChannels();

  @override
  Future<void> replaceMattermostDirectoryUsers(
    List<Map<String, Object?>> users,
  ) async => _database.replaceMattermostDirectoryUsers(users);

  @override
  Future<void> replaceMattermostDirectoryGroups(
    List<Map<String, Object?>> groups,
  ) async => _database.replaceMattermostDirectoryGroups(groups);

  @override
  Future<void> replaceMattermostDirectoryChannels(
    List<Map<String, Object?>> channels,
  ) async => _database.replaceMattermostDirectoryChannels(channels);

  @override
  Future<List<Map<String, Object?>>> searchMattermostDirectoryUsers(
    String query,
  ) async => _database.searchMattermostDirectoryUsers(query);

  @override
  Future<List<Map<String, Object?>>> searchMattermostDirectoryGroups(
    String query,
  ) async => _database.searchMattermostDirectoryGroups(query);

  @override
  Future<List<Map<String, Object?>>> searchMattermostDirectoryChannels(
    String query,
  ) async => _database.searchMattermostDirectoryChannels(query);

  @override
  Future<int> insertCampaign({
    required DateTime createdAt,
    required String createdBy,
    required String message,
    required List<Map<String, Object?>> users,
    required List<Map<String, Object?>> groups,
    required List<String> channels,
  }) async => _database.insertCampaign(
    createdAt: createdAt,
    createdBy: createdBy,
    message: message,
    users: users,
    groups: groups,
    channels: channels,
  );

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
    _database.insertDelivery(
      campaignId: campaignId,
      targetType: targetType,
      targetKey: targetKey,
      targetLabel: targetLabel,
      status: status,
      sentAt: sentAt,
      errorMessage: errorMessage,
      responsePayload: responsePayload,
    );
  }

  @override
  Future<void> updateCampaignSummary({
    required int campaignId,
    required int sentCount,
    required int failedCount,
  }) async => _database.updateCampaignSummary(
    campaignId: campaignId,
    sentCount: sentCount,
    failedCount: failedCount,
  );

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
  }) async => _database.insertInboundRule(
    name: name,
    source: source,
    eventType: eventType,
    ruleKey: ruleKey,
    severity: severity,
    containsText: containsText,
    labelFilters: labelFilters,
    users: users,
    groups: groups,
    channels: channels,
    messageTemplate: messageTemplate,
    enabled: enabled,
  );

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
    _database.updateInboundRule(
      id: id,
      name: name,
      source: source,
      eventType: eventType,
      ruleKey: ruleKey,
      severity: severity,
      containsText: containsText,
      labelFilters: labelFilters,
      users: users,
      groups: groups,
      channels: channels,
      messageTemplate: messageTemplate,
      enabled: enabled,
    );
  }

  @override
  Future<List<Map<String, Object?>>> listInboundRules() async =>
      _database.listInboundRules();

  @override
  Future<Map<String, Object?>?> getInboundRuleById(int id) async =>
      _database.getInboundRuleById(id);

  @override
  Future<Map<String, Object?>?> getInboundRuleByKey({
    required String source,
    required String ruleKey,
  }) async => _database.getInboundRuleByKey(source: source, ruleKey: ruleKey);

  @override
  Future<List<Map<String, Object?>>> listActiveInboundRulesBySource(
    String source,
  ) async => _database.listActiveInboundRulesBySource(source);

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
  }) async => _database.insertInboundEvent(
    source: source,
    eventType: eventType,
    requestId: requestId,
    status: status,
    ruleId: ruleId,
    campaignId: campaignId,
    errorMessage: errorMessage,
    payload: payload,
  );

  @override
  Future<Map<String, Object?>?> getInboundEventByRequestId({
    required String source,
    required String requestId,
  }) async =>
      _database.getInboundEventByRequestId(source: source, requestId: requestId);

  @override
  Future<List<Map<String, Object?>>> listInboundEvents({
    int limit = 10,
    String? source,
  }) async => _database.listInboundEvents(limit: limit, source: source);

  @override
  Future<List<Map<String, Object?>>> listCampaigns({
    int limit = 20,
    String? createdBy,
  }) async => _database.listCampaigns(limit: limit, createdBy: createdBy);

  @override
  Future<void> close() async => _database.close();
}
