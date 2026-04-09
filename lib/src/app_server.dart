import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'audience_service.dart';
import 'auth_service.dart';
import 'campaign_delivery_service.dart';
import 'config.dart';
import 'database_store.dart';
import 'delivery_router.dart';
import 'email_service.dart';
import 'inbound_notifications.dart';
import 'integration_registry.dart';
import 'keycloak_service.dart';
import 'messaging_platform.dart';
import 'settings_service.dart';

void _authLog(AppConfig config, String message) {
  if (!config.authDebugLogging) {
    return;
  }
  stderr.writeln('[cannonball][auth] $message');
}

Handler createHandler({
  required AppConfig config,
  required DatabaseStore database,
  required AuthService authService,
  required SettingsService settingsService,
  required Directory webRoot,
}) {
  final router = Router();
  final emailService = EmailService();
  final keycloakService = KeycloakService();
  final integrationRegistry = IntegrationRegistry(settingsService: settingsService);
  final audienceService = AudienceService(
    registry: integrationRegistry,
    database: database,
  );
  final inboundNotificationService = InboundNotificationService(
    audienceService: audienceService,
  );
  final campaignDeliveryService = CampaignDeliveryService(
    database: database,
    registry: integrationRegistry,
  );
  final staticHandler = createStaticHandler(
    webRoot.path,
    defaultDocument: 'index.html',
  );

  router.get('/health', (Request request) {
    return _jsonResponse(HttpStatus.ok, {'ok': true, 'service': 'cannonball'});
  });

  router.get('/api/public-config', (Request request) async {
    final settings = await settingsService.load();
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'settings': _buildSettingsPayload(
        settings,
        registry: integrationRegistry,
      ),
    });
  });

  router.post('/api/login', (Request request) async {
    final settings = await settingsService.load();
    if (!settings.isLocalAuthEnabled) {
      _authLog(config, 'login denied: local auth disabled');
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Локальный вход отключён. Используй корпоративный вход через Keycloak.',
      });
    }
    final payload = await _readJsonBody(request);
    final username = (payload['username'] as String? ?? '').trim();
    final password = (payload['password'] as String? ?? '').trim();
    if (username == config.bootstrapAdminUsername) {
      _authLog(config, 'login bootstrap sync requested for username=$username');
      await database.ensureBootstrapAdmin(
        username: config.bootstrapAdminUsername,
        displayName: config.bootstrapAdminDisplayName,
        email: config.bootstrapAdminEmail,
        passwordHash: config.resolveBootstrapPasswordHash(),
        forcePasswordSync: config.forceBootstrapAdminPasswordSync,
      );
    }
    _authLog(
      config,
      'login attempt username=$username passwordProvided=${password.isNotEmpty}',
    );
    final user = await authService.authenticate(
      username: username,
      rawPassword: password,
    );
    if (user == null) {
      final existing = username.isEmpty
          ? null
          : await database.getUserByUsername(username);
      if (existing == null) {
        _authLog(config, 'login failed username=$username reason=user-not-found');
      } else if (existing['isActive'] != true) {
        _authLog(
          config,
          'login failed username=$username reason=user-inactive role=${existing['role']} provider=${existing['authProvider']}',
        );
      } else if ((existing['authProvider'] as String?) != 'local') {
        _authLog(
          config,
          'login failed username=$username reason=external-auth-provider provider=${existing['authProvider']}',
        );
      } else {
        _authLog(
          config,
          'login failed username=$username reason=password-mismatch role=${existing['role']} provider=${existing['authProvider']}',
        );
      }
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Неверный логин или пароль.',
      });
    }

    final token = await authService.createSession(user);
    _authLog(
      config,
      'login success username=${user.username} role=${user.role} provider=${user.authProvider}',
    );
    return _jsonResponse(
      HttpStatus.ok,
      {'ok': true, 'user': user.toJson()},
      headers: {
        HttpHeaders.setCookieHeader: authService.buildSessionCookie(token),
      },
    );
  });

  router.post('/api/logout', (Request request) async {
    final token = authService.readSessionToken(
      request.headers[HttpHeaders.cookieHeader],
    );
    if (token != null) {
      await authService.deleteSession(token);
    }
    return _jsonResponse(
      HttpStatus.ok,
      {'ok': true},
      headers: {
        HttpHeaders.setCookieHeader: authService.buildClearSessionCookie(),
      },
    );
  });

  router.get('/api/auth/keycloak/start', (Request request) async {
    final settings = await settingsService.load();
    if (!settings.isKeycloakAuthEnabled) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Корпоративный вход через Keycloak сейчас не настроен.',
      });
    }

    try {
      final discovery = await keycloakService.discover(settings.keycloakIssuerUrl);
      final state = authService.generateOpaqueToken();
      final redirectUri = _buildKeycloakRedirectUri(request, settings);
      final authUrl = keycloakService.buildAuthorizationUrl(
        discovery: discovery,
        clientId: settings.keycloakClientId,
        redirectUri: redirectUri,
        state: state,
        scopes: settings.keycloakScopes,
      );
      return Response.found(
        authUrl.toString(),
        headers: {
          HttpHeaders.setCookieHeader: _buildCookie(
            name: 'cannonball_oidc_state',
            value: state,
            secureCookies: config.secureCookies,
            maxAgeSeconds: 600,
          ),
        },
      );
    } on KeycloakException catch (error) {
      return Response.found(
        '/?login_error=${Uri.encodeComponent(error.message)}',
      );
    }
  });

  router.get('/api/auth/keycloak/callback', (Request request) async {
    final settings = await settingsService.load();
    final code = request.requestedUri.queryParameters['code'] ?? '';
    final state = request.requestedUri.queryParameters['state'] ?? '';
    final error = request.requestedUri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      return Response.found(
        '/?login_error=${Uri.encodeComponent('Keycloak вернул ошибку авторизации: $error')}',
      );
    }
    final expectedState = _readCookie(
      request.headers[HttpHeaders.cookieHeader],
      'cannonball_oidc_state',
    );
    if (code.isEmpty || state.isEmpty || expectedState == null || expectedState != state) {
      return Response.found(
        '/?login_error=${Uri.encodeComponent('Не удалось подтвердить вход через Keycloak. Попробуй ещё раз.')}',
        headers: {
          HttpHeaders.setCookieHeader: _clearCookie(
            name: 'cannonball_oidc_state',
            secureCookies: config.secureCookies,
          ),
        },
      );
    }

    try {
      final discovery = await keycloakService.discover(settings.keycloakIssuerUrl);
      final redirectUri = _buildKeycloakRedirectUri(request, settings);
      final authResult = await keycloakService.exchangeCode(
        discovery: discovery,
        clientId: settings.keycloakClientId,
        clientSecret: settings.keycloakClientSecret,
        redirectUri: redirectUri,
        code: code,
      );
      final profile = authResult.profile;
      final user = await authService.synchronizeExternalUser(
        authProvider: 'keycloak',
        externalSubject: profile.subject,
        username: profile.username,
        displayName: profile.displayName,
        email: profile.email,
        isAdmin: profile.roles.contains(settings.keycloakAdminRole),
      );
      if (user == null) {
        return Response.found(
          '/?login_error=${Uri.encodeComponent('Учётная запись отключена или не может быть связана с Keycloak.')}',
          headers: {
            HttpHeaders.setCookieHeader: _clearCookie(
              name: 'cannonball_oidc_state',
              secureCookies: config.secureCookies,
            ),
          },
        );
      }
      final token = await authService.createSession(user);
      return Response.found(
        '/',
        headers: {
          HttpHeaders.setCookieHeader: authService.buildSessionCookie(token),
        },
      );
    } on KeycloakException catch (error) {
      return Response.found(
        '/?login_error=${Uri.encodeComponent(error.message)}',
        headers: {
          HttpHeaders.setCookieHeader: _clearCookie(
            name: 'cannonball_oidc_state',
            secureCookies: config.secureCookies,
          ),
        },
      );
    }
  });

  router.post('/api/password/forgot', (Request request) async {
    final payload = await _readJsonBody(request);
    final login = (payload['login'] as String? ?? '').trim();
    final settings = await settingsService.load();
    if (!settings.isLocalAuthEnabled) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Восстановление локального пароля недоступно, когда вход работает только через Keycloak.',
      });
    }

    if (login.isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Укажи логин или email.',
      });
    }

    final user = await _findUserForPasswordReset(database, login);
    if (user != null &&
        (user['email'] as String?)?.isNotEmpty == true &&
        settings.isEmailConfigured) {
      final token = await authService.createPasswordResetToken(user['id'] as int);
      final resetLink = _buildPasswordResetLink(
        request: request,
        settings: settings,
        token: token,
      );
      await emailService.sendPasswordReset(
        settings: settings,
        recipientEmail: user['email'] as String,
        recipientName: user['displayName'] as String,
        resetLink: resetLink,
      );
    }

    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'message':
          'Если аккаунт найден и почта настроена, письмо для восстановления уже отправлено.',
    });
  });

  router.post('/api/password/reset', (Request request) async {
    final payload = await _readJsonBody(request);
    final token = (payload['token'] as String? ?? '').trim();
    final newPassword = (payload['newPassword'] as String? ?? '').trim();
    final settings = await settingsService.load();
    if (!settings.isLocalAuthEnabled) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Смена локального пароля недоступна при режиме входа через Keycloak.',
      });
    }
    if (token.isEmpty || newPassword.isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Нужны reset token и новый пароль.',
      });
    }
    if (newPassword.length < 8) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Новый пароль должен быть не короче 8 символов.',
      });
    }
    final success = await authService.consumePasswordResetToken(
      token: token,
      newPassword: newPassword,
    );
    if (!success) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Ссылка восстановления недействительна или уже использована.',
      });
    }
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'message': 'Пароль обновлён. Теперь можно войти с новым паролем.',
    });
  });

  router.get('/api/password/reset/<token>', (Request request, String token) async {
    final user = await authService.resolvePasswordResetToken(token);
    if (user == null) {
      return _jsonResponse(HttpStatus.notFound, {
        'ok': false,
        'valid': false,
        'error': 'Ссылка восстановления недействительна или уже истекла.',
      });
    }
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'valid': true,
      'user': user.toJson(),
    });
  });

  router.get('/api/me', (Request request) async {
    final user = await _requireUser(request, authService);
    if (user == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'authenticated': false,
      });
    }

    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'authenticated': true,
      'user': user.toJson(),
    });
  });

  router.get('/api/config', (Request request) async {
    final user = await _requireUser(request, authService);
    if (user == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final settings = await settingsService.load();
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'user': user.toJson(),
      'settings': _buildSettingsPayload(
        settings,
        registry: integrationRegistry,
      ),
    });
  });

  router.get('/api/integrations', (Request request) async {
    if (await _requireUser(request, authService) == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final settings = await settingsService.load();
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'items': integrationRegistry
          .listIntegrations(settings)
          .map((item) => item.toJson())
          .toList(growable: false),
      'delivery': {
        'mode': settings.deliveryMode,
        'router': integrationRegistry.buildDeliveryRouter(settings)?.key,
      },
    });
  });

  router.patch('/api/profile', (Request request) async {
    final user = await _requireUser(request, authService);
    if (user == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final payload = await _readJsonBody(request);
    final displayName = (payload['displayName'] as String? ?? '').trim();
    final email = (payload['email'] as String? ?? '').trim().toLowerCase();
    final currentPassword = (payload['currentPassword'] as String? ?? '')
        .trim();
    final newPassword = (payload['newPassword'] as String? ?? '').trim();

    if (displayName.isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Нужно указать отображаемое имя.',
      });
    }
    if (email.isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Email обязателен для входящего восстановления пароля.',
      });
    }

    String? passwordHash;
    if (newPassword.isNotEmpty) {
      if (newPassword.length < 8) {
        return _jsonResponse(HttpStatus.badRequest, {
          'ok': false,
          'error': 'Новый пароль должен быть не короче 8 символов.',
        });
      }
      final verified = await authService.authenticate(
        username: user.username,
        rawPassword: currentPassword,
      );
      if (verified == null) {
        return _jsonResponse(HttpStatus.badRequest, {
          'ok': false,
          'error': 'Текущий пароль указан неверно.',
        });
      }
      passwordHash = AuthService.hashPassword(newPassword);
    }

    await database.updateOwnProfile(
      id: user.id,
      displayName: displayName,
      email: email,
      passwordHash: passwordHash,
    );
    final updatedUser = await database.getUserById(user.id);
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'user': _sanitizeUserMap(updatedUser!),
    });
  });

  router.get('/api/users', (Request request) async {
    if (await _requireUser(request, authService) == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final query = request.requestedUri.queryParameters['query'] ?? '';
    final settings = await settingsService.load();
    try {
      final users = await audienceService.searchUsers(
        settings: settings,
        query: query,
      );
      return _jsonResponse(HttpStatus.ok, {
        'ok': true,
        'items': users,
      });
    } on MessagingPlatformException catch (error) {
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
      });
    }
  });

  router.get('/api/audience', (Request request) async {
    if (await _requireUser(request, authService) == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final query = request.requestedUri.queryParameters['query'] ?? '';
    final settings = await settingsService.load();
    try {
      final items = await audienceService.searchAudience(
        settings: settings,
        query: query,
      );
      return _jsonResponse(HttpStatus.ok, {
        'ok': true,
        'items': items,
      });
    } on MessagingPlatformException catch (error) {
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
      });
    }
  });

  router.get('/api/channels', (Request request) async {
    if (await _requireUser(request, authService) == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final query = request.requestedUri.queryParameters['query'] ?? '';
    final settings = await settingsService.load();
    try {
      final channels = await audienceService.searchChannels(
        settings: settings,
        query: query,
      );
      return _jsonResponse(HttpStatus.ok, {
        'ok': true,
        'items': channels,
      });
    } on MessagingPlatformException catch (error) {
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
      });
    }
  });

  router.get('/api/history', (Request request) async {
    final user = await _requireUser(request, authService);
    if (user == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final limit =
        int.tryParse(request.requestedUri.queryParameters['limit'] ?? '') ?? 20;
    final items = await database.listCampaigns(
      limit: limit.clamp(1, 100),
      createdBy: user.isAdmin ? null : user.username,
    );
    return _jsonResponse(HttpStatus.ok, {'ok': true, 'items': items});
  });

  router.post('/api/send', (Request request) async {
    final user = await _requireUser(request, authService);
    if (user == null) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Нужна авторизация.',
      });
    }

    final payload = await _readJsonBody(request);
    final message = (payload['message'] as String? ?? '').trim();
    final rawUsers = ((payload['users'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    final rawGroups = ((payload['groups'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    final rawChannels = ((payload['channels'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);

    if (message.isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Нужно указать текст рассылки.',
      });
    }

    if (rawUsers.isEmpty && rawGroups.isEmpty && rawChannels.isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Выбери хотя бы одного пользователя, группу или канал.',
      });
    }

    final settings = await settingsService.load();
    final configError = integrationRegistry.validateDeliveryConfiguration(settings);
    if (configError != null) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': configError,
      });
    }

    try {
      final outcome = await campaignDeliveryService.sendCampaign(
        sender: user,
        settings: settings,
        message: message,
        rawUsers: rawUsers,
        rawGroups: rawGroups,
        rawChannels: rawChannels,
      );
      return _jsonResponse(HttpStatus.ok, outcome.toJson());
    } on DeliveryRouterException catch (error) {
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
        'statusCode': error.statusCode,
      });
    } on MessagingPlatformException catch (error) {
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
        'statusCode': error.statusCode,
      });
    }
  });

  router.get('/api/admin/users', (Request request) async {
    final user = await _requireAdmin(request, authService);
    if (user == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final users = (await database.listUsers())
        .map(_sanitizeUserMap)
        .toList(growable: false);
    return _jsonResponse(HttpStatus.ok, {'ok': true, 'items': users});
  });

  router.post('/api/admin/users', (Request request) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final payload = await _readJsonBody(request);
    final username = (payload['username'] as String? ?? '')
        .trim()
        .toLowerCase();
    final displayName = (payload['displayName'] as String? ?? '').trim();
    final email = (payload['email'] as String? ?? '').trim().toLowerCase();
    final password = (payload['password'] as String? ?? '').trim();
    final role = (payload['role'] as String? ?? 'user').trim();
    final isActive = payload['isActive'] == true;
    _authLog(
      config,
      'admin create user attempt by=${admin.username} username=$username role=$role active=$isActive emailProvided=${email.isNotEmpty} passwordProvided=${password.isNotEmpty}',
    );

    final validationError = _validateManagedUser(
      username: username,
      displayName: displayName,
      role: role,
      password: password,
      email: email,
      requirePassword: true,
    );
    if (validationError != null) {
      _authLog(
        config,
        'admin create user failed username=$username reason=validation error=$validationError',
      );
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': validationError,
      });
    }
    if (await database.getUserByUsername(username) != null) {
      _authLog(
        config,
        'admin create user failed username=$username reason=duplicate',
      );
      return _jsonResponse(HttpStatus.conflict, {
        'ok': false,
        'error': 'Пользователь с таким логином уже существует.',
      });
    }

    final id = await database.createUser(
      username: username,
      displayName: displayName,
      email: email,
      passwordHash: AuthService.hashPassword(password),
      role: role,
      isActive: isActive,
    );
    _authLog(
      config,
      'admin create user success username=$username id=$id role=$role active=$isActive',
    );
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'user': _sanitizeUserMap((await database.getUserById(id))!),
    });
  });

  router.patch('/api/admin/users/<id|[0-9]+>', (
    Request request,
    String id,
  ) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final userId = int.parse(id);
    final existing = await database.getUserById(userId);
    if (existing == null) {
      return _jsonResponse(HttpStatus.notFound, {
        'ok': false,
        'error': 'Пользователь не найден.',
      });
    }

    final payload = await _readJsonBody(request);
    final displayName =
        (payload['displayName'] as String? ?? existing['displayName'] as String)
            .trim();
    final email =
        (payload['email'] as String? ?? ((existing['email'] as String?) ?? ''))
            .trim()
            .toLowerCase();
    final role = (payload['role'] as String? ?? existing['role'] as String)
        .trim();
    final isActive = payload.containsKey('isActive')
        ? payload['isActive'] == true
        : existing['isActive'] as bool;
    final password = (payload['password'] as String? ?? '').trim();

    final validationError = _validateManagedUser(
      username: existing['username'] as String,
      displayName: displayName,
      role: role,
      password: password,
      email: email,
      requirePassword: false,
    );
    if (validationError != null) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': validationError,
      });
    }

    if ((existing['role'] == 'admin' && role != 'admin') ||
        (existing['role'] == 'admin' &&
            existing['isActive'] == true &&
            !isActive)) {
      if (await database.countActiveAdmins() <= 1) {
        return _jsonResponse(HttpStatus.badRequest, {
          'ok': false,
          'error':
              'В системе должен остаться хотя бы один активный администратор.',
        });
      }
    }

    await database.updateUser(
      id: userId,
      displayName: displayName,
      email: email,
      role: role,
      isActive: isActive,
      passwordHash: password.isEmpty
          ? null
          : AuthService.hashPassword(password),
    );
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'user': _sanitizeUserMap((await database.getUserById(userId))!),
    });
  });

  router.get('/api/admin/settings', (Request request) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final settings = await settingsService.load();
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'settings': _buildSettingsPayload(
        settings,
        registry: integrationRegistry,
        includeAdminFields: true,
      ),
    });
  });

  router.get('/api/admin/integrations', (Request request) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final settings = await settingsService.load();
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'items': integrationRegistry
          .listIntegrations(settings)
          .map((item) => item.toJson())
          .toList(growable: false),
      'delivery': {
        'mode': settings.deliveryMode,
        'router': integrationRegistry.buildDeliveryRouter(settings)?.key,
      },
    });
  });

  router.get('/api/admin/inbound-rules', (Request request) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'items': await database.listInboundRules(),
    });
  });

  router.get('/api/admin/inbound-events', (Request request) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final limit =
        int.tryParse(request.requestedUri.queryParameters['limit'] ?? '') ?? 10;
    final source = (request.requestedUri.queryParameters['source'] ?? '').trim();

    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'items': await database.listInboundEvents(
        limit: limit.clamp(1, 100),
        source: source.isEmpty ? null : source,
      ),
    });
  });

  router.post('/api/admin/inbound-rules', (Request request) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final payload = await _readJsonBody(request);
    final validationError = _validateInboundRulePayload(payload);
    if (validationError != null) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': validationError,
      });
    }

    final id = await database.insertInboundRule(
      name: (payload['name'] as String? ?? '').trim(),
      source: (payload['source'] as String? ?? 'n8n').trim().toLowerCase(),
      eventType: (payload['eventType'] as String? ?? '').trim(),
      ruleKey: (payload['ruleKey'] as String? ?? '').trim(),
      severity: (payload['severity'] as String? ?? '').trim(),
      containsText: (payload['containsText'] as String? ?? '').trim(),
      labelFilters: _normalizeStringMap(payload['labelFilters']),
      users: _normalizeStringList(payload['users']),
      groups: _normalizeStringList(payload['groups']),
      channels: _normalizeStringList(payload['channels']),
      messageTemplate: (payload['messageTemplate'] as String? ?? '').trim(),
      enabled: payload['enabled'] != false,
    );

    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'item': await database.getInboundRuleById(id),
    });
  });

  router.patch('/api/admin/inbound-rules/<id|[0-9]+>', (
    Request request,
    String id,
  ) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final ruleId = int.parse(id);
    final existing = await database.getInboundRuleById(ruleId);
    if (existing == null) {
      return _jsonResponse(HttpStatus.notFound, {
        'ok': false,
        'error': 'Правило не найдено.',
      });
    }

    final payload = await _readJsonBody(request);
    final merged = {
      ...existing,
      ...payload,
    };
    final validationError = _validateInboundRulePayload(merged);
    if (validationError != null) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': validationError,
      });
    }

    await database.updateInboundRule(
      id: ruleId,
      name: (merged['name'] as String? ?? '').trim(),
      source: (merged['source'] as String? ?? 'n8n').trim().toLowerCase(),
      eventType: (merged['eventType'] as String? ?? '').trim(),
      ruleKey: (merged['ruleKey'] as String? ?? '').trim(),
      severity: (merged['severity'] as String? ?? '').trim(),
      containsText: (merged['containsText'] as String? ?? '').trim(),
      labelFilters: _normalizeStringMap(merged['labelFilters']),
      users: _normalizeStringList(merged['users']),
      groups: _normalizeStringList(merged['groups']),
      channels: _normalizeStringList(merged['channels']),
      messageTemplate: (merged['messageTemplate'] as String? ?? '').trim(),
      enabled: merged['enabled'] != false,
    );

    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'item': await database.getInboundRuleById(ruleId),
    });
  });

  router.put('/api/admin/settings', (Request request) async {
    final admin = await _requireAdmin(request, authService);
    if (admin == null) {
      return _jsonResponse(HttpStatus.forbidden, {
        'ok': false,
        'error': 'Нужны права администратора.',
      });
    }

    final payload = await _readJsonBody(request);
    final deliveryMode = (payload['deliveryMode'] as String? ?? '').trim();
    final authMode = (payload['authMode'] as String? ?? '').trim();
    if (deliveryMode != 'mattermost' && deliveryMode != 'n8n') {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Основной маршрут должен быть mattermost или n8n.',
      });
    }
    if (authMode != 'local' && authMode != 'hybrid' && authMode != 'keycloak') {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Режим авторизации должен быть local, hybrid или keycloak.',
      });
    }

    await settingsService.updateFromPayload(payload);
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'settings': _buildSettingsPayload(
        await settingsService.load(),
        registry: integrationRegistry,
        includeAdminFields: true,
      ),
    });
  });

  router.post('/api/incoming/n8n', (Request request) async {
    final settings = await settingsService.load();
    if (!_isInboundSecretValid(request, settings)) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Неверный inbound secret.',
      });
    }

    final payload = await _readJsonBody(request);
    final event = inboundNotificationService.normalizeEvent(
      source: 'n8n',
      payload: payload,
    );

    if (event.message.isEmpty &&
        event.ruleKey.isEmpty &&
        ((payload['messageTemplate'] as String?) ?? '').trim().isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Нужно передать message или правило с шаблоном сообщения.',
      });
    }

    if (event.requestId.isNotEmpty) {
      final existing = await database.getInboundEventByRequestId(
        source: event.source,
        requestId: event.requestId,
      );
      if (existing != null) {
        return _jsonResponse(HttpStatus.ok, {
          'ok': true,
          'duplicate': true,
          'status': existing['status'],
          'campaignId': existing['campaignId'],
          'message': 'Событие с таким request_id уже обработано.',
        });
      }
    }

    final configError = integrationRegistry.validateDeliveryConfiguration(settings);
    if (configError != null) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': configError,
      });
    }

    try {
      final resolution = await inboundNotificationService.resolveDelivery(
        settings: settings,
        event: event,
        activeRules: await database.listActiveInboundRulesBySource('n8n'),
      );

      final outcome = await campaignDeliveryService.sendCampaign(
        sender: _buildSystemSender(
          username: 'n8n',
          displayName: 'n8n inbound',
        ),
        settings: settings,
        message: resolution.message,
        rawUsers: resolution.rawUsers,
        rawGroups: resolution.rawGroups,
        rawChannels: resolution.channels,
      );

      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'sent',
          ruleId: resolution.rule?['id'] as int?,
          campaignId: outcome.campaignId,
          payload: event.rawPayload,
        );
      }

      return _jsonResponse(HttpStatus.ok, {
        ...outcome.toJson(),
        'source': event.source,
        'ruleId': resolution.rule?['id'],
        'ruleName': resolution.rule?['name'],
      });
    } on InboundNotificationException catch (error) {
      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'failed',
          errorMessage: error.message,
          payload: event.rawPayload,
        );
      }
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': error.message,
      });
    } on DeliveryRouterException catch (error) {
      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'failed',
          errorMessage: error.message,
          payload: event.rawPayload,
        );
      }
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
      });
    } on MessagingPlatformException catch (error) {
      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'failed',
          errorMessage: error.message,
          payload: event.rawPayload,
        );
      }
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
      });
    }
  });

  router.post('/api/incoming/alertmanager', (Request request) async {
    final settings = await settingsService.load();
    if (!_isInboundSecretValid(request, settings)) {
      return _jsonResponse(HttpStatus.unauthorized, {
        'ok': false,
        'error': 'Неверный inbound secret.',
      });
    }

    final payload = await _readJsonBody(request);
    final event = inboundNotificationService.normalizeAlertmanagerEvent(payload);

    if (event.message.isEmpty &&
        event.ruleKey.isEmpty &&
        ((payload['messageTemplate'] as String?) ?? '').trim().isEmpty) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'Нужно передать message, alert payload или правило с шаблоном сообщения.',
      });
    }

    if (event.requestId.isNotEmpty) {
      final existing = await database.getInboundEventByRequestId(
        source: event.source,
        requestId: event.requestId,
      );
      if (existing != null) {
        return _jsonResponse(HttpStatus.ok, {
          'ok': true,
          'duplicate': true,
          'status': existing['status'],
          'campaignId': existing['campaignId'],
          'message': 'Событие с таким request_id уже обработано.',
        });
      }
    }

    final configError = integrationRegistry.validateDeliveryConfiguration(settings);
    if (configError != null) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': configError,
      });
    }

    try {
      final resolution = await inboundNotificationService.resolveDelivery(
        settings: settings,
        event: event,
        activeRules: await database.listActiveInboundRulesBySource('alertmanager'),
      );

      final outcome = await campaignDeliveryService.sendCampaign(
        sender: _buildSystemSender(
          username: 'alertmanager',
          displayName: 'alertmanager inbound',
        ),
        settings: settings,
        message: resolution.message,
        rawUsers: resolution.rawUsers,
        rawGroups: resolution.rawGroups,
        rawChannels: resolution.channels,
      );

      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'sent',
          ruleId: resolution.rule?['id'] as int?,
          campaignId: outcome.campaignId,
          payload: event.rawPayload,
        );
      }

      return _jsonResponse(HttpStatus.ok, {
        ...outcome.toJson(),
        'source': event.source,
        'ruleId': resolution.rule?['id'],
        'ruleName': resolution.rule?['name'],
      });
    } on InboundNotificationException catch (error) {
      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'failed',
          errorMessage: error.message,
          payload: event.rawPayload,
        );
      }
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': error.message,
      });
    } on DeliveryRouterException catch (error) {
      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'failed',
          errorMessage: error.message,
          payload: event.rawPayload,
        );
      }
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
      });
    } on MessagingPlatformException catch (error) {
      if (event.requestId.isNotEmpty) {
        await database.insertInboundEvent(
          source: event.source,
          eventType: event.eventType,
          requestId: event.requestId,
          status: 'failed',
          errorMessage: error.message,
          payload: event.rawPayload,
        );
      }
      return _jsonResponse(HttpStatus.badGateway, {
        'ok': false,
        'error': error.message,
        'details': error.details,
      });
    }
  });

  router.all('/<ignored|.*>', (Request request) async {
    if (request.url.path.startsWith('api/')) {
      return _jsonResponse(HttpStatus.notFound, {
        'ok': false,
        'error': 'Маршрут не найден.',
      });
    }

    final response = await staticHandler(request);
    if (response.statusCode == HttpStatus.notFound) {
      final indexRequest = Request('GET', Uri.parse('/index.html'));
      return staticHandler(indexRequest);
    }
    return response;
  });

  return const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
}

String? _validateManagedUser({
  required String username,
  required String displayName,
  required String role,
  required String password,
  required String email,
  required bool requirePassword,
}) {
  if (username.isEmpty) {
    return 'Логин пользователя обязателен.';
  }
  if (displayName.isEmpty) {
    return 'Имя пользователя обязательно.';
  }
  if (email.isEmpty || !email.contains('@')) {
    return 'Корректный email обязателен.';
  }
  if (role != 'admin' && role != 'user') {
    return 'Роль должна быть user или admin.';
  }
  if (requirePassword && password.length < 8) {
    return 'Пароль должен быть не короче 8 символов.';
  }
  if (!requirePassword && password.isNotEmpty && password.length < 8) {
    return 'Новый пароль должен быть не короче 8 символов.';
  }
  return null;
}

String? _validateInboundRulePayload(Map<String, Object?> payload) {
  final name = (payload['name'] as String? ?? '').trim();
  final source = (payload['source'] as String? ?? 'n8n').trim().toLowerCase();
  if (name.isEmpty) {
    return 'Название правила обязательно.';
  }
  if (source != 'n8n' && source != 'alertmanager') {
    return 'Источник правила должен быть n8n или alertmanager.';
  }
  return null;
}

String _buildKeycloakRedirectUri(Request request, AppSettings settings) {
  if (settings.publicBaseUrl.isNotEmpty) {
    return '${settings.publicBaseUrl}/api/auth/keycloak/callback';
  }
  final origin =
      '${request.requestedUri.scheme}://${request.requestedUri.authority}';
  return '$origin/api/auth/keycloak/callback';
}

Future<AuthenticatedUser?> _requireUser(
  Request request,
  AuthService authService,
) async {
  final token = authService.readSessionToken(
    request.headers[HttpHeaders.cookieHeader],
  );
  return authService.resolveSession(token);
}

Future<AuthenticatedUser?> _requireAdmin(
  Request request,
  AuthService authService,
) async {
  final user = await _requireUser(request, authService);
  if (user == null || !user.isAdmin) {
    return null;
  }
  return user;
}

Map<String, Object?> _sanitizeUserMap(Map<String, Object?> user) => {
  'id': user['id'],
  'username': user['username'],
  'displayName': user['displayName'],
  'email': user['email'],
  'authProvider': user['authProvider'],
  'role': user['role'],
  'isActive': user['isActive'],
  'createdAt': user['createdAt'],
  'updatedAt': user['updatedAt'],
};

Future<Map<String, Object?>?> _findUserForPasswordReset(
  DatabaseStore database,
  String login,
) async {
  if (login.contains('@')) {
    return database.getUserByEmail(login.toLowerCase());
  }
  return database.getUserByUsername(login);
}

Map<String, Object?> _buildSettingsPayload(
  AppSettings settings, {
  required IntegrationRegistry registry,
  bool includeAdminFields = false,
}) {
  final base = includeAdminFields
      ? settings.toAdminJson()
      : settings.toPublicJson();

  return {
    ...base,
    'delivery': {
      'mode': settings.deliveryMode,
      'router': registry.buildDeliveryRouter(settings)?.key,
    },
    'integrations': {
      ...(base['integrations'] as Map<String, Object?>? ?? const {}),
      'items': registry
          .listIntegrations(settings)
          .map((item) => item.toJson())
          .toList(growable: false),
    },
  };
}

bool _isInboundSecretValid(Request request, AppSettings settings) {
  final configuredSecret = settings.n8nInboundSecret.trim();
  if (configuredSecret.isEmpty) {
    return false;
  }
  final authorization = request.headers[HttpHeaders.authorizationHeader] ?? '';
  if (authorization == 'Bearer $configuredSecret') {
    return true;
  }
  final secretHeader = request.headers['x-webhook-secret'] ?? '';
  if (secretHeader == configuredSecret) {
    return true;
  }
  return false;
}

AuthenticatedUser _buildSystemSender({
  required String username,
  required String displayName,
}) {
  return AuthenticatedUser(
    id: 0,
    username: username,
    displayName: displayName,
    email: '',
    role: 'admin',
    isActive: true,
    authProvider: 'system',
  );
}

List<String> _normalizeStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

Map<String, String> _normalizeStringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  final normalized = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    final itemValue = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && itemValue.isNotEmpty) {
      normalized[key] = itemValue;
    }
  }
  return normalized;
}

String _buildPasswordResetLink({
  required Request request,
  required AppSettings settings,
  required String token,
}) {
  if (settings.publicBaseUrl.isNotEmpty) {
    return '${settings.publicBaseUrl}/?reset_token=$token';
  }
  final origin =
      '${request.requestedUri.scheme}://${request.requestedUri.authority}';
  return '$origin/?reset_token=$token';
}

Future<Map<String, Object?>> _readJsonBody(Request request) async {
  final content = await request.readAsString();
  if (content.trim().isEmpty) {
    return <String, Object?>{};
  }
  return Map<String, Object?>.from(jsonDecode(content) as Map);
}

Response _jsonResponse(
  int statusCode,
  Map<String, Object?> body, {
  Map<String, String>? headers,
}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      ...?headers,
    },
  );
}

String? _readCookie(String? cookieHeader, String name) {
  if (cookieHeader == null || cookieHeader.isEmpty) {
    return null;
  }
  final cookies = cookieHeader.split(';');
  for (final cookie in cookies) {
    final trimmed = cookie.trim();
    final prefix = '$name=';
    if (trimmed.startsWith(prefix)) {
      return trimmed.substring(prefix.length);
    }
  }
  return null;
}

String _buildCookie({
  required String name,
  required String value,
  required bool secureCookies,
  required int maxAgeSeconds,
}) {
  final parts = <String>[
    '$name=$value',
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    'Max-Age=$maxAgeSeconds',
  ];
  if (secureCookies) {
    parts.add('Secure');
  }
  return parts.join('; ');
}

String _clearCookie({
  required String name,
  required bool secureCookies,
}) {
  return _buildCookie(
    name: name,
    value: '',
    secureCookies: secureCookies,
    maxAgeSeconds: 0,
  );
}
