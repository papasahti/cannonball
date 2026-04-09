const NAV_ITEMS = [
  {
    id: 'overview',
    label: 'Центр управления',
    subtitle: 'Сводка по платформе и доступу',
    title: 'Центр управления',
    description:
      'Быстрый обзор ролей, маршрутов доставки, состояния интеграций и операционных точек внимания.',
    roles: ['admin'],
  },
  {
    id: 'compose',
    label: 'Рассылка',
    subtitle: 'Подготовка новой отправки',
    title: 'Новая рассылка',
    description: '',
    roles: ['user', 'admin'],
  },
  {
    id: 'history',
    label: 'История',
    subtitle: 'Запуски и результаты доставки',
    title: 'История рассылок',
    description: '',
    roles: ['user', 'admin'],
  },
  {
    id: 'profile',
    label: 'Профиль',
    subtitle: 'Личные данные и сессия',
    title: 'Настройки пользователя',
    description:
      'Личные данные, параметры интерфейса и управление текущей сессией пользователя.',
    roles: ['user', 'admin'],
  },
  {
    id: 'admin-users',
    label: 'Пользователи',
    subtitle: 'Роли и локальные аккаунты',
    title: 'Управление доступом',
    description:
      'Роли, доступ к платформе и сопровождение внутренних аккаунтов продукта.',
    roles: ['admin'],
  },
  {
    id: 'admin-integrations',
    label: 'Интеграции',
    subtitle: 'Каналы, SSO и внешние модули',
    title: 'Интеграции',
    description:
      'Каталог подключённых модулей платформы, активных маршрутов доставки и внешних identity-провайдеров.',
    roles: ['admin'],
  },
  {
    id: 'admin-rules',
    label: 'Правила',
    subtitle: 'Входящие события и маршрутизация',
    title: 'Правила',
    description:
      'Автоматические правила для входящих уведомлений из n8n и следующих источников интеграции.',
    roles: ['admin'],
  },
  {
    id: 'admin-settings',
    label: 'Настройки',
    subtitle: 'Маршруты, интеграции и SSO',
    title: 'Конфигурация платформы',
    description:
      'Каналы доставки, параметры продукта и интеграции с Mattermost, n8n, почтой и SSO.',
    roles: ['admin'],
  },
];

const state = {
  selectedUsers: [],
  selectedGroups: [],
  selectedChannels: [],
  theme: readStoredTheme() || 'day',
  currentUser: null,
  appSettings: null,
  adminSettings: null,
  history: [],
  adminUsers: [],
  adminIntegrations: [],
  adminRules: [],
  adminInboundEvents: [],
  adminDelivery: null,
  currentView: 'overview',
  authMode: 'login',
  resetToken: null,
  currentSettingsPanel: 'product',
  publicSettings: null,
  authMessage: '',
  audienceActiveIndex: -1,
  channelActiveIndex: -1,
  historySearch: '',
  historyStatusFilter: 'all',
  historyTriggerFilter: 'all',
  customSelectCounter: 0,
};

const elements = {
  loginView: document.getElementById('login-view'),
  appView: document.getElementById('app-view'),
  loginForm: document.getElementById('login-form'),
  forgotForm: document.getElementById('forgot-form'),
  resetForm: document.getElementById('reset-form'),
  loginUsername: document.getElementById('login-username'),
  loginPassword: document.getElementById('login-password'),
  loginPasswordToggle: document.getElementById('login-password-toggle'),
  forgotLogin: document.getElementById('forgot-login'),
  resetPassword: document.getElementById('reset-password'),
  resetPasswordConfirm: document.getElementById('reset-password-confirm'),
  loginError: document.getElementById('login-error'),
  authTitle: document.getElementById('auth-title'),
  authSubtitle: document.getElementById('auth-subtitle'),
  authSsoPanel: document.getElementById('auth-sso-panel'),
  authDivider: document.getElementById('auth-divider'),
  ssoLoginButton: document.getElementById('sso-login-button'),
  showForgotButton: document.getElementById('show-forgot-button'),
  showLoginButton: document.getElementById('show-login-button'),
  themeToggle: document.getElementById('theme-toggle'),
  logoutButton: document.getElementById('logout-button'),
  topbarLogoutButton: document.getElementById('topbar-logout-button'),
  appTitleBadge: document.getElementById('app-title-badge'),
  pageTitle: document.getElementById('page-title'),
  pageSubtitle: document.getElementById('page-subtitle'),
  pageMeta: document.getElementById('page-meta'),
  topbarRole: document.getElementById('topbar-role'),
  topbarUserName: document.getElementById('topbar-user-name'),
  topbarUserLogin: document.getElementById('topbar-user-login'),
  sidebarNav: document.getElementById('sidebar-nav'),
  settingsNavButtons: document.querySelectorAll('[data-settings-panel]'),
  settingsPanels: document.querySelectorAll('[data-settings-section]'),
  settingsSummaryRoute: document.getElementById('settings-summary-route'),
  settingsSummaryMm: document.getElementById('settings-summary-mm'),
  settingsSummaryN8n: document.getElementById('settings-summary-n8n'),
  settingsSummaryEmail: document.getElementById('settings-summary-email'),
  overviewHighlight: document.getElementById('overview-highlight'),
  overviewCards: document.getElementById('overview-cards'),
  audienceSearch: document.getElementById('audience-search'),
  audienceResults: document.getElementById('audience-results'),
  selectedAudience: document.getElementById('selected-audience'),
  channelInput: document.getElementById('channel-input'),
  channelResults: document.getElementById('channel-results'),
  selectedChannels: document.getElementById('selected-channels'),
  messageInput: document.getElementById('message-input'),
  messageHint: document.getElementById('message-hint'),
  audienceHint: document.getElementById('audience-hint'),
  channelHint: document.getElementById('channel-hint'),
  sendButton: document.getElementById('send-button'),
  sendStatus: document.getElementById('send-status'),
  composerUsersCount: document.getElementById('composer-users-count'),
  composerGroupsCount: document.getElementById('composer-groups-count'),
  composerChannelsCount: document.getElementById('composer-channels-count'),
  composerRoute: document.getElementById('composer-route'),
  historyRefresh: document.getElementById('history-refresh'),
  historySearch: document.getElementById('history-search'),
  historyStatusFilter: document.getElementById('history-status-filter'),
  historyTriggerFilter: document.getElementById('history-trigger-filter'),
  historySummary: document.getElementById('history-summary'),
  historyList: document.getElementById('history-list'),
  profileForm: document.getElementById('profile-form'),
  profileDisplayName: document.getElementById('profile-display-name'),
  profileEmail: document.getElementById('profile-email'),
  profileCurrentPassword: document.getElementById('profile-current-password'),
  profileNewPassword: document.getElementById('profile-new-password'),
  profilePasswordSection: document.getElementById('profile-password-section'),
  profileAuthHint: document.getElementById('profile-auth-hint'),
  profileStatus: document.getElementById('profile-status'),
  createUserForm: document.getElementById('create-user-form'),
  createUserUsername: document.getElementById('create-user-username'),
  createUserDisplayName: document.getElementById('create-user-display-name'),
  createUserEmail: document.getElementById('create-user-email'),
  createUserRole: document.getElementById('create-user-role'),
  createUserPassword: document.getElementById('create-user-password'),
  createUserActive: document.getElementById('create-user-active'),
  createUserStatus: document.getElementById('create-user-status'),
  adminUsersRefresh: document.getElementById('admin-users-refresh'),
  adminUsersList: document.getElementById('admin-users-list'),
  adminIntegrationsRefresh: document.getElementById('admin-integrations-refresh'),
  integrationsSummary: document.getElementById('integrations-summary'),
  integrationsList: document.getElementById('integrations-list'),
  adminRulesRefresh: document.getElementById('admin-rules-refresh'),
  adminRulesSummary: document.getElementById('admin-rules-summary'),
  createRuleForm: document.getElementById('create-rule-form'),
  ruleName: document.getElementById('rule-name'),
  ruleSource: document.getElementById('rule-source'),
  ruleKey: document.getElementById('rule-key'),
  ruleEventType: document.getElementById('rule-event-type'),
  ruleSeverity: document.getElementById('rule-severity'),
  ruleContainsText: document.getElementById('rule-contains-text'),
  ruleLabelFilters: document.getElementById('rule-label-filters'),
  ruleUsers: document.getElementById('rule-users'),
  ruleGroups: document.getElementById('rule-groups'),
  ruleChannels: document.getElementById('rule-channels'),
  ruleMessageTemplate: document.getElementById('rule-message-template'),
  ruleEnabled: document.getElementById('rule-enabled'),
  createRuleStatus: document.getElementById('create-rule-status'),
  adminRulesList: document.getElementById('admin-rules-list'),
  adminInboundEvents: document.getElementById('admin-inbound-events'),
  settingsForm: document.getElementById('settings-form'),
  settingsAppTitle: document.getElementById('settings-app-title'),
  settingsDeliveryMode: document.getElementById('settings-delivery-mode'),
  settingsDefaultChannels: document.getElementById('settings-default-channels'),
  settingsMmBaseUrl: document.getElementById('settings-mm-base-url'),
  settingsMmToken: document.getElementById('settings-mm-token'),
  settingsMmTeamId: document.getElementById('settings-mm-team-id'),
  settingsMmTeamName: document.getElementById('settings-mm-team-name'),
  settingsN8nBaseUrl: document.getElementById('settings-n8n-base-url'),
  settingsN8nWebhookUrl: document.getElementById('settings-n8n-webhook-url'),
  settingsN8nApiKey: document.getElementById('settings-n8n-api-key'),
  settingsN8nWebhookSecret: document.getElementById('settings-n8n-webhook-secret'),
  settingsN8nInboundSecret: document.getElementById('settings-n8n-inbound-secret'),
  settingsPublicBaseUrl: document.getElementById('settings-public-base-url'),
  settingsSmtpHost: document.getElementById('settings-smtp-host'),
  settingsSmtpPort: document.getElementById('settings-smtp-port'),
  settingsSmtpUsername: document.getElementById('settings-smtp-username'),
  settingsSmtpPassword: document.getElementById('settings-smtp-password'),
  settingsSmtpFromEmail: document.getElementById('settings-smtp-from-email'),
  settingsSmtpFromName: document.getElementById('settings-smtp-from-name'),
  settingsSmtpUseSsl: document.getElementById('settings-smtp-use-ssl'),
  settingsStatus: document.getElementById('settings-status'),
  settingsAuthMode: document.getElementById('settings-auth-mode'),
  settingsKeycloakIssuerUrl: document.getElementById('settings-keycloak-issuer-url'),
  settingsKeycloakClientId: document.getElementById('settings-keycloak-client-id'),
  settingsKeycloakClientSecret: document.getElementById('settings-keycloak-client-secret'),
  settingsKeycloakScopes: document.getElementById('settings-keycloak-scopes'),
  settingsKeycloakAdminRole: document.getElementById('settings-keycloak-admin-role'),
};

applyTheme();
bindEvents();
bootstrap();

async function bootstrap() {
  await loadPublicConfig();
  handleAuthRoute();
  const me = await api('/api/me');
  if (!me.ok) {
    showLogin();
    return;
  }
  await initializeSession(me.user);
}

function bindEvents() {
  window.addEventListener('resize', syncViewportScrollbarOffset);
  document.addEventListener('click', handleDocumentClick);
  document.addEventListener('keydown', handleDocumentKeydown);
  elements.loginForm.addEventListener('submit', onLogin);
  elements.forgotForm.addEventListener('submit', onForgotPassword);
  elements.resetForm.addEventListener('submit', onResetPassword);
  bindSubmitOnEnter(elements.loginUsername, elements.loginForm);
  bindSubmitOnEnter(elements.loginPassword, elements.loginForm);
  if (elements.loginPasswordToggle) {
    elements.loginPasswordToggle.addEventListener('click', toggleLoginPasswordVisibility);
  }
  bindSubmitOnEnter(elements.forgotLogin, elements.forgotForm);
  bindSubmitOnEnter(elements.resetPassword, elements.resetForm);
  bindSubmitOnEnter(elements.resetPasswordConfirm, elements.resetForm);
  elements.showForgotButton.addEventListener('click', function () {
    switchAuthMode('forgot');
  });
  elements.showLoginButton.addEventListener('click', function () {
    history.replaceState(null, '', window.location.pathname);
    state.resetToken = null;
    state.authMessage = '';
    switchAuthMode('login');
  });
  elements.ssoLoginButton.addEventListener('click', function () {
    window.location.href = '/api/auth/keycloak/start';
  });
  elements.logoutButton.addEventListener('click', onLogout);
  elements.topbarLogoutButton.addEventListener('click', onLogout);
  elements.themeToggle.addEventListener('click', toggleTheme);
  prepareLookupInput(elements.audienceSearch);
  prepareLookupInput(elements.channelInput);
  prepareLookupInput(elements.historySearch);
  elements.audienceSearch.addEventListener('input', debounce(loadAudience, 200));
  elements.audienceSearch.addEventListener('focus', function () {
    loadAudience();
  });
  elements.audienceSearch.addEventListener('input', function () {
    updateComposerFieldStates();
  });
  elements.audienceSearch.addEventListener('keydown', function (event) {
    handleSearchNavigation(event, elements.audienceResults, 'audience');
  });
  elements.messageInput.addEventListener('input', function () {
    renderComposerSummary();
  });
  elements.channelInput.addEventListener('input', debounce(loadChannels, 250));
  elements.channelInput.addEventListener('focus', function () {
    loadChannels();
  });
  elements.channelInput.addEventListener('input', function () {
    updateComposerFieldStates();
  });
  elements.channelInput.addEventListener('keydown', function (event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      addChannel(elements.channelInput.value);
      return;
    }
    handleSearchNavigation(event, elements.channelResults, 'channel');
  });
  elements.sendButton.addEventListener('click', onSend);
  elements.historyRefresh.addEventListener('click', function () {
    loadHistory();
  });
  if (elements.historySearch) {
    elements.historySearch.addEventListener('input', function () {
      state.historySearch = elements.historySearch.value.trim();
      renderHistory();
    });
  }
  if (elements.historyStatusFilter) {
    elements.historyStatusFilter.addEventListener('change', function () {
      state.historyStatusFilter = elements.historyStatusFilter.value;
      renderHistory();
    });
  }
  if (elements.historyTriggerFilter) {
    elements.historyTriggerFilter.addEventListener('change', function () {
      state.historyTriggerFilter = elements.historyTriggerFilter.value;
      renderHistory();
    });
  }
  elements.profileForm.addEventListener('submit', onSaveProfile);
  elements.createUserForm.addEventListener('submit', onCreateUser);
  elements.adminUsersRefresh.addEventListener('click', function () {
    loadAdminUsers();
  });
  elements.adminIntegrationsRefresh.addEventListener('click', function () {
    loadAdminIntegrations();
  });
  if (elements.createRuleForm) {
    elements.createRuleForm.addEventListener('submit', onCreateRule);
  }
  if (elements.adminRulesRefresh) {
    elements.adminRulesRefresh.addEventListener('click', function () {
      loadAdminRules();
    });
  }
  if (elements.adminInboundEvents) {
    elements.adminInboundEvents.addEventListener('click', function (event) {
      const button = event.target.closest('[data-open-history-campaign]');
      if (!button) {
        return;
      }
      openHistoryFromInbound(button.getAttribute('data-open-history-campaign'));
    });
  }
  if (elements.integrationsList) {
    elements.integrationsList.addEventListener('click', function (event) {
      const button = event.target.closest('[data-open-settings-panel]');
      if (!button) {
        return;
      }
      openSettingsPanel(button.getAttribute('data-open-settings-panel'));
    });
  }
  elements.settingsForm.addEventListener('submit', onSaveSettings);
  elements.settingsNavButtons.forEach(function (button) {
    button.addEventListener('click', function () {
      switchSettingsPanel(button.getAttribute('data-settings-panel'));
    });
  });

  initializeCustomSelects(document);

  if (typeof ResizeObserver !== 'undefined') {
    const layoutObserver = new ResizeObserver(function () {
      syncViewportScrollbarOffset();
    });
    layoutObserver.observe(document.body);
  }
}

async function initializeSession(user) {
  state.currentUser = user;
  state.currentView = isAdmin() ? 'overview' : 'compose';
  showApp();
  renderSelectedAudience();
  renderSelectedChannels();
  renderSidebar();
  renderUserIdentity();

  await loadConfig();
  await Promise.all([loadHistory(), loadAudience(), loadChannels()]);

  if (isAdmin()) {
    await Promise.all([
      loadAdminUsers(),
      loadAdminSettings(),
      loadAdminIntegrations(),
      loadAdminRules(),
    ]);
  }

  ensureAllowedView();
  switchView(state.currentView);
}

async function onLogin(event) {
  event.preventDefault();
  elements.loginError.textContent = '';

  if (!elements.loginUsername.value.trim() || !elements.loginPassword.value) {
    elements.loginError.textContent = 'Введи логин и пароль.';
    return;
  }

  const response = await api('/api/login', {
    method: 'POST',
    body: JSON.stringify({
      username: elements.loginUsername.value.trim(),
      password: elements.loginPassword.value,
    }),
  });

  if (!response.ok) {
    elements.loginError.textContent = response.error || 'Не удалось выполнить вход.';
    return;
  }

  elements.loginPassword.value = '';
  resetLoginPasswordVisibility();
  await initializeSession(response.user);
}

async function onForgotPassword(event) {
  event.preventDefault();
  if (!elements.forgotLogin.value.trim()) {
    elements.loginError.textContent = 'Укажи логин или email для восстановления.';
    return;
  }
  elements.loginError.textContent = 'Проверяю запрос...';

  const response = await api('/api/password/forgot', {
    method: 'POST',
    body: JSON.stringify({
      login: elements.forgotLogin.value.trim(),
    }),
  });

  if (!response.ok) {
    elements.loginError.textContent =
      response.error || 'Не удалось отправить письмо для восстановления доступа.';
    return;
  }

  elements.loginError.textContent = response.message;
}

async function onResetPassword(event) {
  event.preventDefault();
  if (!state.resetToken) {
    elements.loginError.textContent =
      'Ссылка восстановления отсутствует или недействительна.';
    return;
  }
  if (elements.resetPassword.value !== elements.resetPasswordConfirm.value) {
    elements.loginError.textContent = 'Пароли не совпадают.';
    return;
  }
  if (elements.resetPassword.value.length < 8) {
    elements.loginError.textContent = 'Новый пароль должен быть не короче 8 символов.';
    return;
  }

  elements.loginError.textContent = 'Сохраняю новый пароль...';
  const response = await api('/api/password/reset', {
    method: 'POST',
    body: JSON.stringify({
      token: state.resetToken,
      newPassword: elements.resetPassword.value,
    }),
  });

  if (!response.ok) {
    elements.loginError.textContent =
      response.error || 'Не удалось обновить пароль.';
    return;
  }

  elements.resetForm.reset();
  state.resetToken = null;
  history.replaceState(null, '', window.location.pathname);
  switchAuthMode('login');
  elements.loginError.textContent = response.message;
}

async function onLogout() {
  await api('/api/logout', { method: 'POST' });
  state.selectedUsers = [];
  state.selectedGroups = [];
  state.selectedChannels = [];
  state.currentUser = null;
  state.appSettings = null;
  state.adminSettings = null;
  state.history = [];
  state.adminUsers = [];
  state.adminIntegrations = [];
  state.adminRules = [];
  state.adminDelivery = null;
  state.currentView = 'overview';
  state.authMode = 'login';
  state.resetToken = null;
  state.currentSettingsPanel = 'product';
  state.authMessage = '';
  resetLoginPasswordVisibility();
  elements.loginForm.reset();
  elements.forgotForm.reset();
  elements.resetForm.reset();
  showLogin();
}

async function loadPublicConfig() {
  const response = await api('/api/public-config');
  if (!response.ok) {
    return;
  }
  state.publicSettings = response.settings;
  elements.appTitleBadge.textContent = response.settings.appTitle || 'cannonball';
  document.title = response.settings.appTitle || 'cannonball';
}

async function loadConfig() {
  const response = await api('/api/config');
  if (!response.ok) {
    return;
  }

  state.currentUser = response.user;
  state.appSettings = response.settings;
  if (!state.selectedChannels.length) {
    const channels = response.settings.defaultChannels || [];
    for (let index = 0; index < channels.length; index += 1) {
      if (!state.selectedChannels.includes(channels[index])) {
        state.selectedChannels.push(channels[index]);
      }
    }
  }

  elements.appTitleBadge.textContent = response.settings.appTitle || 'cannonball';
  document.title = response.settings.appTitle || 'cannonball';
  state.publicSettings = response.settings;
  renderUserIdentity();
  renderSelectedChannels();
  renderSelectedAudience();
  renderOverview();
  renderSettingsSummary();
}

async function loadAudience() {
  if (!state.currentUser) {
    return;
  }
  const query = elements.audienceSearch.value.trim();
  const normalizedQuery = query.toLowerCase();
  const shouldShowUserSuggestions = normalizedQuery.length >= 4;
  const response = await api('/api/audience?query=' + encodeURIComponent(query));
  if (!response.ok) {
    const emptyText =
      state.appSettings &&
      state.appSettings.integrations &&
      state.appSettings.integrations.mattermostConfigured !== true
        ? 'Получатели появятся после подключения Mattermost.'
        : 'Получатели сейчас недоступны.';
    renderSearchResults(elements.audienceResults, [], emptyText, null, 'audience');
    return;
  }

  const items = (response.items || []).filter(function (item) {
    if (item.kind === 'user' && !shouldShowUserSuggestions) {
      return false;
    }
    if (item.kind === 'group') {
      return !state.selectedGroups.find(function (selected) {
        return selected.id === item.id;
      });
    }
    return !state.selectedUsers.find(function (selected) {
      return selected.id === item.id;
    });
  });

  let emptyText = 'Начни вводить имя сотрудника или группу.';
  if (query && query.length < 4) {
    emptyText = 'Подсказки по пользователям появятся с 4-го символа. Группы можно искать сразу.';
  } else if (query) {
    emptyText = 'Ничего не найдено.';
  }

  renderSearchResults(
    elements.audienceResults,
    items,
    emptyText,
    function (item) {
      if (item.kind === 'group') {
        state.selectedGroups.push(item);
      } else {
        state.selectedUsers.push(item);
      }
      elements.audienceSearch.value = '';
      renderSelectedAudience();
      loadAudience();
    },
    'audience',
  );
}

async function loadChannels() {
  if (!state.currentUser) {
    return;
  }
  const query = elements.channelInput.value.trim();
  const response = await api('/api/channels?query=' + encodeURIComponent(query));
  if (!response.ok) {
    const emptyText =
      state.appSettings &&
      state.appSettings.integrations &&
      state.appSettings.integrations.mattermostConfigured !== true
        ? 'Подсказки по каналам появятся после подключения Mattermost.'
        : 'Каналы сейчас недоступны.';
    renderSearchResults(elements.channelResults, [], emptyText, null, 'channel');
    return;
  }

  const items = (response.items || []).filter(function (item) {
    return !state.selectedChannels.includes(item.name);
  });
  renderSearchResults(
    elements.channelResults,
    items,
    query ? 'Ничего не найдено.' : 'Начни вводить название канала.',
    function (item) {
      addChannel(item.name);
    },
    'channel',
  );
}

function addChannel(value) {
  const normalized = value.trim().replace(/^#/, '');
  if (!normalized) {
    return;
  }
  if (!state.selectedChannels.includes(normalized)) {
    state.selectedChannels.push(normalized);
  }
  elements.channelInput.value = '';
  renderSelectedChannels();
  loadChannels();
}

async function onSend() {
  const composerState = getComposerState();
  if (!composerState.ready) {
    setStatus(elements.sendStatus, composerState.hint, 'negative');
    updateComposerFieldStates();
    return;
  }
  setStatus(elements.sendStatus, 'Отправляю сообщения...', 'neutral');
  elements.sendButton.disabled = true;
  const payload = {
    message: elements.messageInput.value.trim(),
    users: state.selectedUsers,
    groups: state.selectedGroups,
    channels: state.selectedChannels,
  };

  const response = await api('/api/send', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    setStatus(
      elements.sendStatus,
      response.error || 'Не удалось отправить рассылку. Проверь маршрут и попробуй ещё раз.',
      'negative',
    );
    renderComposerSummary();
    return;
  }

  setStatus(
    elements.sendStatus,
    'Рассылка отправлена: ' +
      response.sent +
      ' успешно, ' +
      response.failed +
      ' с ошибкой. Маршрут: ' +
      response.deliveryMode,
    'positive',
  );
  elements.messageInput.value = '';
  elements.audienceSearch.value = '';
  elements.channelInput.value = '';
  state.selectedUsers = [];
  state.selectedGroups = [];
  state.selectedChannels = [];
  renderSelectedAudience();
  renderSelectedChannels();
  await loadHistory();
  renderOverview();
  loadAudience();
  loadChannels();
  renderComposerSummary();
}

async function loadHistory() {
  const response = await api('/api/history?limit=20');
  if (!response.ok) {
    elements.historyList.innerHTML =
      '<div class="history-card">Не удалось загрузить историю.</div>';
    return;
  }

  state.history = response.items || [];
  renderHistory();
  renderOverview();
}

async function onSaveProfile(event) {
  event.preventDefault();
  const email = elements.profileEmail.value.trim();
  if (!elements.profileDisplayName.value.trim()) {
    setStatus(elements.profileStatus, 'Укажи отображаемое имя.', 'negative');
    markFieldInvalid(elements.profileDisplayName, true);
    return;
  }
  if (!isValidEmail(email)) {
    setStatus(elements.profileStatus, 'Укажи корректный email.', 'negative');
    markFieldInvalid(elements.profileEmail, true);
    return;
  }
  if (
    elements.profileNewPassword.value &&
    elements.profileNewPassword.value.length < 8
  ) {
    setStatus(elements.profileStatus, 'Новый пароль должен быть не короче 8 символов.', 'negative');
    markFieldInvalid(elements.profileNewPassword, true);
    return;
  }

  markFieldInvalid(elements.profileDisplayName, false);
  markFieldInvalid(elements.profileEmail, false);
  markFieldInvalid(elements.profileNewPassword, false);
  setStatus(elements.profileStatus, 'Сохраняю изменения профиля...', 'neutral');

  const response = await api('/api/profile', {
    method: 'PATCH',
    body: JSON.stringify({
      displayName: elements.profileDisplayName.value.trim(),
      email: elements.profileEmail.value.trim(),
      currentPassword: elements.profileCurrentPassword.value,
      newPassword: elements.profileNewPassword.value,
    }),
  });

  if (!response.ok) {
    setStatus(
      elements.profileStatus,
      response.error || 'Не удалось сохранить профиль. Попробуй ещё раз.',
      'negative',
    );
    return;
  }

  state.currentUser = response.user;
  elements.profileCurrentPassword.value = '';
  elements.profileNewPassword.value = '';
  setStatus(elements.profileStatus, 'Изменения профиля сохранены.', 'positive');
  renderUserIdentity();
}

async function loadAdminUsers() {
  if (!isAdmin()) {
    return;
  }
  const response = await api('/api/admin/users');
  if (!response.ok) {
    elements.adminUsersList.innerHTML =
      '<div class="history-card">Не удалось загрузить список локальных пользователей.</div>';
    return;
  }
  state.adminUsers = response.items || [];
  renderAdminUsers();
  renderOverview();
}

async function onCreateUser(event) {
  event.preventDefault();
  const username = elements.createUserUsername.value.trim();
  const displayName = elements.createUserDisplayName.value.trim();
  const email = elements.createUserEmail.value.trim();
  const password = elements.createUserPassword.value;

  const usernameValid = /^[a-zA-Z0-9._-]+$/.test(username);
  markFieldInvalid(elements.createUserUsername, !usernameValid);
  markFieldInvalid(elements.createUserDisplayName, !displayName);
  markFieldInvalid(elements.createUserEmail, !isValidEmail(email));
  markFieldInvalid(elements.createUserPassword, password.length < 8);

  if (!usernameValid || !displayName || !isValidEmail(email) || password.length < 8) {
    setStatus(
      elements.createUserStatus,
      'Проверь логин, имя, email и пароль. Обязательные поля должны быть заполнены корректно.',
      'negative',
    );
    return;
  }

  setStatus(elements.createUserStatus, 'Создаю пользователя...', 'neutral');

  const response = await api('/api/admin/users', {
    method: 'POST',
    body: JSON.stringify({
      username: elements.createUserUsername.value.trim(),
      displayName: elements.createUserDisplayName.value.trim(),
      email: elements.createUserEmail.value.trim(),
      role: elements.createUserRole.value,
      password: elements.createUserPassword.value,
      isActive: elements.createUserActive.checked,
    }),
  });

  if (!response.ok) {
    setStatus(
      elements.createUserStatus,
      response.error || 'Не удалось создать пользователя. Проверь поля и попробуй ещё раз.',
      'negative',
    );
    return;
  }

  elements.createUserForm.reset();
  elements.createUserActive.checked = true;
  syncCustomSelects(elements.createUserForm);
  clearFieldState(elements.createUserUsername);
  clearFieldState(elements.createUserDisplayName);
  clearFieldState(elements.createUserEmail);
  clearFieldState(elements.createUserPassword);
  setStatus(elements.createUserStatus, 'Пользователь успешно добавлен.', 'positive');
  await loadAdminUsers();
}

async function onSaveManagedUser(id) {
  const card = document.querySelector('[data-user-card="' + id + '"]');
  if (!card) {
    return;
  }

  const payload = {
    displayName: card.querySelector('[data-field="displayName"]').value.trim(),
    email: card.querySelector('[data-field="email"]').value.trim(),
    role: card.querySelector('[data-field="role"]').value,
    isActive: card.querySelector('[data-field="isActive"]').checked,
    password: card.querySelector('[data-field="password"]').value,
  };

  const statusNode = card.querySelector('[data-user-status]');
  statusNode.textContent = 'Сохраняю изменения...';
  const response = await api('/api/admin/users/' + id, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    statusNode.textContent =
      response.error || 'Не удалось сохранить изменения пользователя.';
    return;
  }

  statusNode.textContent = 'Изменения пользователя сохранены.';
  await loadAdminUsers();
}

async function loadAdminSettings() {
  if (!isAdmin()) {
    return;
  }
  const response = await api('/api/admin/settings');
  if (!response.ok) {
    elements.settingsStatus.textContent =
      response.error || 'Не удалось загрузить конфигурацию платформы.';
    return;
  }
  state.adminSettings = response.settings;
  fillSettingsForm();
  renderSettingsSummary();
  renderOverview();
}

async function loadAdminIntegrations() {
  if (!isAdmin()) {
    return;
  }
  const response = await api('/api/admin/integrations');
  if (!response.ok) {
    if (elements.integrationsList) {
      elements.integrationsList.innerHTML =
        '<div class="history-card">Не удалось загрузить список интеграций.</div>';
    }
    return;
  }

  state.adminIntegrations = response.items || [];
  state.adminDelivery = response.delivery || null;
  renderAdminIntegrations();
  renderOverview();
}

async function loadAdminRules() {
  if (!isAdmin()) {
    return;
  }
  const response = await api('/api/admin/inbound-rules');
  if (!response.ok) {
    if (elements.adminRulesList) {
      elements.adminRulesList.innerHTML =
        '<div class="history-card">Не удалось загрузить правила.</div>';
    }
    return;
  }

  state.adminRules = response.items || [];
  renderAdminRules();
  await loadAdminInboundEvents();
}

async function loadAdminInboundEvents() {
  if (!isAdmin()) {
    return;
  }
  const response = await api('/api/admin/inbound-events?limit=10');
  if (!response.ok) {
    if (elements.adminInboundEvents) {
      elements.adminInboundEvents.innerHTML =
        '<div class="history-card">Не удалось загрузить последние входящие события.</div>';
    }
    return;
  }

  state.adminInboundEvents = response.items || [];
  renderAdminInboundEvents();
}

async function onCreateRule(event) {
  event.preventDefault();
  const payload = collectRuleFormPayload();

  if (!payload.name) {
    setStatus(elements.createRuleStatus, 'Название правила обязательно.', 'negative');
    return;
  }
  if (payload.labelFilters === null) {
    setStatus(
      elements.createRuleStatus,
      'Фильтры labels должны быть корректным JSON-объектом.',
      'negative',
    );
    return;
  }

  setStatus(elements.createRuleStatus, 'Сохраняю правило...', 'neutral');
  const response = await api('/api/admin/inbound-rules', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    setStatus(
      elements.createRuleStatus,
      response.error || 'Не удалось сохранить правило.',
      'negative',
    );
    return;
  }

  elements.createRuleForm.reset();
  elements.ruleSource.value = 'n8n';
  elements.ruleEnabled.checked = true;
  syncCustomSelects(elements.createRuleForm);
  setStatus(elements.createRuleStatus, 'Правило добавлено.', 'positive');
  await loadAdminRules();
}

async function onSaveRule(id) {
  const card = document.querySelector('[data-rule-card="' + id + '"]');
  if (!card) {
    return;
  }

  const statusNode = card.querySelector('[data-rule-status]');
  const payload = {
    name: card.querySelector('[data-rule-field="name"]').value.trim(),
    source: card.querySelector('[data-rule-field="source"]').value,
    ruleKey: card.querySelector('[data-rule-field="ruleKey"]').value.trim(),
    eventType: card.querySelector('[data-rule-field="eventType"]').value.trim(),
    severity: card.querySelector('[data-rule-field="severity"]').value.trim(),
    containsText: card.querySelector('[data-rule-field="containsText"]').value.trim(),
    labelFilters: parseJsonObjectInput(
      card.querySelector('[data-rule-field="labelFilters"]').value,
    ),
    users: splitCommaList(card.querySelector('[data-rule-field="users"]').value),
    groups: splitCommaList(card.querySelector('[data-rule-field="groups"]').value),
    channels: splitCommaList(card.querySelector('[data-rule-field="channels"]').value),
    messageTemplate: card
      .querySelector('[data-rule-field="messageTemplate"]')
      .value.trim(),
    enabled: card.querySelector('[data-rule-field="enabled"]').checked,
  };

  if (!payload.name) {
    statusNode.textContent = 'Название правила обязательно.';
    return;
  }
  if (payload.labelFilters === null) {
    statusNode.textContent = 'Фильтры labels должны быть корректным JSON-объектом.';
    return;
  }

  statusNode.textContent = 'Сохраняю правило...';
  const response = await api('/api/admin/inbound-rules/' + id, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    statusNode.textContent = response.error || 'Не удалось сохранить правило.';
    return;
  }

  statusNode.textContent = 'Правило сохранено.';
  await loadAdminRules();
}

async function onSaveSettings(event) {
  event.preventDefault();
  elements.settingsStatus.textContent = 'Сохраняю конфигурацию платформы...';

  const response = await api('/api/admin/settings', {
    method: 'PUT',
    body: JSON.stringify({
      appTitle: elements.settingsAppTitle.value.trim(),
      deliveryMode: elements.settingsDeliveryMode.value,
      defaultChannels: splitCommaList(elements.settingsDefaultChannels.value),
      mattermostBaseUrl: elements.settingsMmBaseUrl.value.trim(),
      mattermostToken: elements.settingsMmToken.value.trim(),
      mattermostTeamId: elements.settingsMmTeamId.value.trim(),
      mattermostTeamName: elements.settingsMmTeamName.value.trim(),
      n8nBaseUrl: elements.settingsN8nBaseUrl.value.trim(),
      n8nWebhookUrl: elements.settingsN8nWebhookUrl.value.trim(),
      n8nApiKey: elements.settingsN8nApiKey.value.trim(),
      n8nWebhookSecret: elements.settingsN8nWebhookSecret.value.trim(),
      n8nInboundSecret: elements.settingsN8nInboundSecret.value.trim(),
      publicBaseUrl: elements.settingsPublicBaseUrl.value.trim(),
      smtpHost: elements.settingsSmtpHost.value.trim(),
      smtpPort: elements.settingsSmtpPort.value.trim(),
      smtpUsername: elements.settingsSmtpUsername.value.trim(),
      smtpPassword: elements.settingsSmtpPassword.value.trim(),
      smtpFromEmail: elements.settingsSmtpFromEmail.value.trim(),
      smtpFromName: elements.settingsSmtpFromName.value.trim(),
      smtpUseSsl: elements.settingsSmtpUseSsl.checked,
      authMode: elements.settingsAuthMode.value,
      keycloakIssuerUrl: elements.settingsKeycloakIssuerUrl.value.trim(),
      keycloakClientId: elements.settingsKeycloakClientId.value.trim(),
      keycloakClientSecret: elements.settingsKeycloakClientSecret.value.trim(),
      keycloakScopes: elements.settingsKeycloakScopes.value.trim(),
      keycloakAdminRole: elements.settingsKeycloakAdminRole.value.trim(),
    }),
  });

  if (!response.ok) {
    elements.settingsStatus.textContent =
      response.error || 'Не удалось сохранить конфигурацию платформы.';
    return;
  }

  elements.settingsStatus.textContent = 'Конфигурация платформы сохранена.';
  state.adminSettings = response.settings;
  await loadConfig();
  await loadAdminIntegrations();
  fillSettingsForm();
  renderSettingsSummary();
}

function renderAdminIntegrations() {
  if (!elements.integrationsList || !elements.integrationsSummary) {
    return;
  }

  const items = state.adminIntegrations || [];
  const configuredCount = items.filter(function (item) {
    return item.configured;
  }).length;
  const enabledCount = items.filter(function (item) {
    return item.enabled;
  }).length;
  const identityCount = items.filter(function (item) {
    return item.kind === 'identity';
  }).length;

  elements.integrationsSummary.innerHTML =
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Маршрут</span>' +
    '<strong class="metric-value">' +
    escapeHtml(
      formatDeliveryMode(
        (state.adminDelivery && state.adminDelivery.mode) ||
          (state.adminSettings && state.adminSettings.deliveryMode) ||
          'mattermost',
      ),
    ) +
    '</strong>' +
    '<p class="muted">Активный контур доставки по умолчанию.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Подключено</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(configuredCount)) +
    '</strong>' +
    '<p class="muted">Интеграции с заполненной конфигурацией.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Активно</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(enabledCount)) +
    '</strong>' +
    '<p class="muted">Модули, которые сейчас участвуют в работе платформы.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Identity</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(identityCount)) +
    '</strong>' +
    '<p class="muted">Провайдеры входа и корпоративной идентификации.</p>' +
    '</article>';

  if (!items.length) {
    elements.integrationsList.innerHTML =
      '<div class="history-card">Интеграции пока не описаны.</div>';
    return;
  }

  elements.integrationsList.innerHTML = items
    .map(function (item) {
      const settingsPanel = getIntegrationSettingsPanel(item.key);
      return (
        '<article class="integration-card">' +
        '<div class="integration-card-head">' +
        '<div>' +
        '<span class="metric-label">' +
        escapeHtml(item.kind) +
        '</span>' +
        '<h3>' +
        escapeHtml(item.label) +
        '</h3>' +
        '</div>' +
        '<span class="integration-status ' +
        (item.enabled
          ? 'status-positive'
          : item.configured
            ? 'status-neutral'
            : 'status-negative') +
        '">' +
        escapeHtml(
          item.enabled ? 'Активна' : item.configured ? 'Подключена' : 'Не настроена',
        ) +
        '</span>' +
        '</div>' +
        '<p class="muted">' +
        escapeHtml(item.description || 'Описание пока не задано.') +
        '</p>' +
        '<div class="integration-card-meta">' +
        '<span class="page-meta-pill">Ключ: ' +
        escapeHtml(item.key) +
        '</span>' +
        '<span class="page-meta-pill">Тип: ' +
        escapeHtml(item.kind) +
        '</span>' +
        '</div>' +
        '<div class="integration-card-actions">' +
        '<button class="ghost-button subtle-button" type="button" data-open-settings-panel="' +
        escapeHtml(settingsPanel) +
        '">' +
        'Открыть настройки' +
        '</button>' +
        '</div>' +
        '</article>'
      );
    })
    .join('');
}

function getIntegrationSettingsPanel(key) {
  if (key === 'mattermost') {
    return 'mattermost';
  }
  if (key === 'n8n') {
    return 'n8n';
  }
  if (key === 'email') {
    return 'email';
  }
  if (key === 'keycloak') {
    return 'auth';
  }
  return 'product';
}

function openSettingsPanel(panelId) {
  switchView('admin-settings');
  switchSettingsPanel(panelId || 'product');
}

function fillSettingsForm() {
  if (!state.adminSettings) {
    return;
  }
  elements.settingsAppTitle.value = state.adminSettings.appTitle || '';
  elements.settingsDeliveryMode.value =
    state.adminSettings.deliveryMode || 'mattermost';
  elements.settingsDefaultChannels.value = (
    state.adminSettings.defaultChannels || []
  ).join(', ');
  elements.settingsMmBaseUrl.value = state.adminSettings.mattermostBaseUrl || '';
  elements.settingsMmToken.value = state.adminSettings.mattermostToken || '';
  elements.settingsMmTeamId.value = state.adminSettings.mattermostTeamId || '';
  elements.settingsMmTeamName.value =
    state.adminSettings.mattermostTeamName || '';
  elements.settingsN8nBaseUrl.value = state.adminSettings.n8nBaseUrl || '';
  elements.settingsN8nWebhookUrl.value =
    state.adminSettings.n8nWebhookUrl || '';
  elements.settingsN8nApiKey.value = state.adminSettings.n8nApiKey || '';
  elements.settingsN8nWebhookSecret.value =
    state.adminSettings.n8nWebhookSecret || '';
  elements.settingsN8nInboundSecret.value =
    state.adminSettings.n8nInboundSecret || '';
  elements.settingsPublicBaseUrl.value = state.adminSettings.publicBaseUrl || '';
  elements.settingsSmtpHost.value = state.adminSettings.smtpHost || '';
  elements.settingsSmtpPort.value = state.adminSettings.smtpPort || 587;
  elements.settingsSmtpUsername.value = state.adminSettings.smtpUsername || '';
  elements.settingsSmtpPassword.value = state.adminSettings.smtpPassword || '';
  elements.settingsSmtpFromEmail.value =
    state.adminSettings.smtpFromEmail || '';
  elements.settingsSmtpFromName.value = state.adminSettings.smtpFromName || '';
  elements.settingsSmtpUseSsl.checked = state.adminSettings.smtpUseSsl === true;
  elements.settingsAuthMode.value = state.adminSettings.authMode || 'local';
  elements.settingsKeycloakIssuerUrl.value =
    state.adminSettings.keycloakIssuerUrl || '';
  elements.settingsKeycloakClientId.value =
    state.adminSettings.keycloakClientId || '';
  elements.settingsKeycloakClientSecret.value =
    state.adminSettings.keycloakClientSecret || '';
  elements.settingsKeycloakScopes.value =
    state.adminSettings.keycloakScopes || 'openid profile email';
  elements.settingsKeycloakAdminRole.value =
    state.adminSettings.keycloakAdminRole || 'cannonball-admin';
  syncCustomSelects(document);
}

function renderSidebar() {
  if (!state.currentUser) {
    return;
  }
  const items = NAV_ITEMS.filter(function (item) {
    return item.roles.includes(state.currentUser.role);
  });

  elements.sidebarNav.innerHTML = items
    .map(function (item) {
      return (
        '<button class="nav-button' +
        (item.id === state.currentView ? ' active' : '') +
        '" type="button" data-nav="' +
        item.id +
        '" aria-current="' +
        (item.id === state.currentView ? 'page' : 'false') +
        '">' +
        '<span class="nav-button-label">' +
        escapeHtml(item.label) +
        '</span>' +
        '<span class="nav-button-subtitle">' +
        escapeHtml(item.subtitle || '') +
        '</span>' +
        '</button>'
      );
    })
    .join('');

  elements.sidebarNav.querySelectorAll('[data-nav]').forEach(function (button) {
    button.addEventListener('click', function () {
      switchView(button.getAttribute('data-nav'));
    });
  });
}

function switchView(viewId) {
  state.currentView = viewId;
  ensureAllowedView();
  const sections = document.querySelectorAll('.view-section');
  sections.forEach(function (section) {
    section.classList.add('hidden');
  });
  const target = document.getElementById('view-' + state.currentView);
  if (target) {
    target.classList.remove('hidden');
  }
  if (state.currentView === 'admin-settings') {
    switchSettingsPanel(state.currentSettingsPanel);
  }
  renderPageContext();
  renderSidebar();
  syncViewportScrollbarOffset();
}

function switchSettingsPanel(panelId) {
  state.currentSettingsPanel = panelId || 'product';
  elements.settingsNavButtons.forEach(function (button) {
    button.classList.toggle(
      'active',
      button.getAttribute('data-settings-panel') === state.currentSettingsPanel,
    );
  });
  elements.settingsPanels.forEach(function (panel) {
    panel.classList.toggle(
      'hidden',
      panel.getAttribute('data-settings-section') !== state.currentSettingsPanel,
    );
  });
  if (state.currentView === 'admin-settings') {
    renderPageContext();
  }
}

function ensureAllowedView() {
  if (!state.currentUser) {
    state.currentView = 'compose';
    return;
  }
  const allowed = NAV_ITEMS.filter(function (item) {
    return item.roles.includes(state.currentUser.role);
  }).map(function (item) {
    return item.id;
  });
  if (!allowed.includes(state.currentView)) {
    state.currentView = isAdmin() ? 'overview' : 'compose';
  }
}

function renderUserIdentity() {
  if (!state.currentUser) {
    return;
  }
  const displayName = state.currentUser.displayName || '';
  elements.topbarRole.textContent = isAdmin() ? 'Администратор' : 'Оператор';
  elements.topbarUserName.textContent = displayName;
  elements.topbarUserLogin.textContent = '@' + state.currentUser.username;
  elements.profileDisplayName.value = state.currentUser.displayName || '';
  elements.profileEmail.value = state.currentUser.email || '';
  const showLocalPassword =
    isLocalAuthEnabled() && state.currentUser.authProvider !== 'keycloak';
  elements.profilePasswordSection.classList.toggle('hidden', !showLocalPassword);
  elements.profileAuthHint.classList.toggle('hidden', showLocalPassword);
}

function renderOverview() {
  if (!state.currentUser || !state.appSettings) {
    return;
  }

  const totalCampaigns = state.history.length;
  const totalErrors = state.history.reduce(function (sum, broadcast) {
    return sum + (broadcast.failedCount || 0);
  }, 0);
  const totalSent = state.history.reduce(function (sum, broadcast) {
    return sum + (broadcast.sentCount || 0);
  }, 0);
  const highlightTitle = isAdmin()
    ? 'Платформа под контролем'
    : 'Рабочее место оператора готово';
  const highlightBody = isAdmin()
    ? 'Проверь конфигурацию маршрутов, состояние интеграций и операционные зоны риска перед следующими изменениями.'
    : 'Отсюда удобно перейти к новой рассылке, проверить историю отправок и обновить профиль без лишней навигации.';
  const nextStep = isAdmin()
    ? 'Следующий шаг: держать в фокусе настройки платформы и состояние доставки.'
    : 'Следующий шаг: перейти в раздел рассылки и собрать аудиторию.';
  const cards = [
    {
      title: 'Роль в продукте',
      value: isAdmin() ? 'Администратор' : 'Пользователь',
      subtitle: isAdmin()
        ? 'Полный доступ к рассылкам, пользователям и конфигурации платформы.'
        : 'Доступ к рассылкам, истории отправок и личному профилю.',
    },
    {
      title: 'Основной маршрут',
      value: formatDeliveryMode(state.appSettings.deliveryMode),
      subtitle:
        state.appSettings.deliveryMode === 'n8n'
          ? 'Платформа передаёт события в n8n для оркестрации доставки.'
          : 'Платформа публикует сообщения напрямую через Mattermost API.',
    },
    {
      title: 'Рассылки',
      value: String(totalCampaigns),
      subtitle:
        totalCampaigns > 0
          ? 'Успешных доставок: ' + totalSent + ', ошибок: ' + totalErrors + '.'
          : 'Рассылки ещё не запускались.',
    },
    {
      title: 'Интеграционный контур',
      value: describeIntegrations(),
      subtitle: isAdmin()
        ? 'Управляется в разделе конфигурации платформы.'
        : 'Если маршрут недоступен, обратись к администратору платформы.',
    },
  ];

  if (isAdmin()) {
    cards.push({
      title: 'Локальные аккаунты',
      value: String(state.adminUsers.length || 0),
      subtitle: 'Роли, доступ и операционные права внутри продукта.',
    });
    cards.push({
      title: 'Восстановление доступа',
      value: state.appSettings.integrations.emailConfigured
        ? 'Настроено'
        : 'Не настроено',
      subtitle: state.appSettings.integrations.emailConfigured
        ? 'Пользователи могут восстанавливать пароль по почте.'
        : 'Настрой SMTP в конфигурации платформы.',
    });
  }

  if (elements.overviewHighlight) {
    elements.overviewHighlight.innerHTML =
      '<article class="overview-highlight-card">' +
      '<div>' +
      '<span class="metric-label">Фокус раздела</span>' +
      '<h3>' +
      escapeHtml(highlightTitle) +
      '</h3>' +
      '<p class="muted">' +
      escapeHtml(highlightBody) +
      '</p>' +
      '</div>' +
      '<div class="overview-highlight-meta">' +
      '<span class="pill">' +
      escapeHtml(nextStep) +
      '</span>' +
      '</div>' +
      '</article>';
  }

  elements.overviewCards.innerHTML = cards
    .map(function (card) {
      return (
        '<article class="metric-card">' +
        '<span class="metric-label">' +
        escapeHtml(card.title) +
        '</span>' +
        '<strong class="metric-value">' +
        escapeHtml(card.value) +
        '</strong>' +
        '<p class="muted">' +
        escapeHtml(card.subtitle) +
        '</p>' +
        '</article>'
      );
    })
    .join('');
}

function renderPageContext() {
  const config = NAV_ITEMS.find(function (item) {
    return item.id === state.currentView;
  });

  if (!config) {
    return;
  }

  elements.pageTitle.textContent = config.title || config.label;
  if (isAdmin()) {
    elements.pageSubtitle.textContent = config.description || '';
    elements.pageSubtitle.classList.toggle('hidden', !config.description);
  } else {
    elements.pageSubtitle.textContent = '';
    elements.pageSubtitle.classList.add('hidden');
  }

  if (!isAdmin()) {
    elements.pageMeta.innerHTML = '';
    return;
  }

  const meta = [];
  meta.push('Административный контур');
  if (config.id === 'compose' && state.appSettings) {
    meta.push('Маршрут: ' + formatDeliveryMode(state.appSettings.deliveryMode));
  }
  if (config.id === 'history') {
    meta.push('Запусков в ленте: ' + String(state.history.length));
  }
  if (config.id === 'admin-users') {
    meta.push('Локальных аккаунтов: ' + String(state.adminUsers.length || 0));
  }
  if (config.id === 'admin-integrations') {
    meta.push(
      'Интеграций в каталоге: ' + String(state.adminIntegrations.length || 0),
    );
    if (state.adminDelivery && state.adminDelivery.mode) {
      meta.push('Маршрут: ' + formatDeliveryMode(state.adminDelivery.mode));
    }
  }
  if (config.id === 'admin-settings' && state.adminSettings) {
    meta.push(
      'Активная секция: ' + formatSettingsPanelLabel(state.currentSettingsPanel),
    );
  }

  elements.pageMeta.innerHTML = meta
    .map(function (item) {
      return '<span class="page-meta-pill">' + escapeHtml(item) + '</span>';
    })
    .join('');
}

function renderSettingsSummary() {
  const settings = state.adminSettings || state.appSettings;
  if (!settings || !elements.settingsSummaryRoute) {
    return;
  }

  const integrationItems =
    settings.integrations && Array.isArray(settings.integrations.items)
      ? settings.integrations.items
      : [];

  function findIntegration(key) {
    return integrationItems.find(function (item) {
      return item.key === key;
    });
  }

  const mattermost = findIntegration('mattermost');
  const n8n = findIntegration('n8n');
  const email = findIntegration('email');

  elements.settingsSummaryRoute.textContent =
    formatDeliveryMode(
      (settings.delivery && settings.delivery.mode) || settings.deliveryMode,
    );
  elements.settingsSummaryMm.textContent =
    mattermost && mattermost.configured ? 'Подключён' : 'Не настроен';
  elements.settingsSummaryN8n.textContent =
    n8n && n8n.enabled
      ? 'Активен'
      : n8n && n8n.configured
        ? 'Подключён'
        : 'Отключён';
  elements.settingsSummaryEmail.textContent =
    email && email.configured ? 'Подключён' : 'Не настроен';
}

function renderHistory() {
  const filteredHistory = getFilteredHistory();

  if (!state.history.length) {
    renderHistorySummary([]);
    elements.historyList.innerHTML =
      '<div class="history-card">История пока пустая.</div>';
    return;
  }

  renderHistorySummary(filteredHistory);
  if (!filteredHistory.length) {
    elements.historyList.innerHTML =
      '<div class="history-card">По текущим фильтрам ничего не найдено. Попробуй изменить строку поиска или статус.</div>';
    return;
  }

  elements.historyList.innerHTML = filteredHistory
    .map(function (item) {
      return renderHistoryCard(item);
    })
    .join('');
}

function renderHistorySummary(items) {
  if (!elements.historySummary) {
    return;
  }

  const historyItems = items || [];
  const totalCampaigns = historyItems.length;
  const inboundCount = historyItems.filter(function (item) {
    return (item.trigger && item.trigger.kind) === 'inbound';
  }).length;
  const manualCount = totalCampaigns - inboundCount;
  const totalSent = historyItems.reduce(function (sum, item) {
    return sum + (item.sentCount || 0);
  }, 0);
  const totalFailed = historyItems.reduce(function (sum, item) {
    return sum + (item.failedCount || 0);
  }, 0);
  const lastLaunch = historyItems.length
    ? formatDate(historyItems[0].createdAt)
    : 'Пока нет запусков';

  const cards = [
    {
      label: 'Запусков',
      value: String(totalCampaigns),
      caption: totalCampaigns
        ? 'Ручных: ' + String(manualCount) + ' • входящих: ' + String(inboundCount)
        : 'История ещё не накоплена.',
    },
    {
      label: 'Успешных доставок',
      value: String(totalSent),
      caption: totalSent ? 'Сумма успешных доставок по текущей выборке.' : 'Пока нет успешных отправок.',
    },
    {
      label: 'Ошибок доставки',
      value: String(totalFailed),
      caption: totalFailed ? 'Проверь карточки запусков с ошибками ниже.' : 'В текущей ленте ошибок нет.',
    },
    {
      label: 'Последний запуск',
      value: lastLaunch,
      caption: totalCampaigns ? 'Самое свежее событие в журнале.' : 'После первой отправки появится здесь.',
    },
  ];

  elements.historySummary.innerHTML = cards
    .map(function (card) {
      return (
        '<article class="history-summary-card">' +
        '<span class="metric-label">' +
        escapeHtml(card.label) +
        '</span>' +
        '<strong class="history-summary-value">' +
        escapeHtml(card.value) +
        '</strong>' +
        '<p class="muted">' +
        escapeHtml(card.caption) +
        '</p>' +
        '</article>'
      );
    })
    .join('');
}

function getFilteredHistory() {
  const searchValue = state.historySearch.trim().toLowerCase();

  return state.history.filter(function (item) {
    if (!matchHistoryStatus(item, state.historyStatusFilter)) {
      return false;
    }
    if (!matchHistoryTrigger(item, state.historyTriggerFilter)) {
      return false;
    }

    if (!searchValue) {
      return true;
    }

    const haystack = []
      .concat('#' + String(item.id || ''))
      .concat(item.createdBy || '')
      .concat(item.message || '')
      .concat((item.trigger && item.trigger.source) || '')
      .concat((item.trigger && item.trigger.requestId) || '')
      .concat((item.trigger && item.trigger.ruleName) || '')
      .concat(
        (item.users || []).map(function (user) {
          return [user.displayName || '', user.username || ''].join(' ');
        }),
      )
      .concat(
        (item.groups || []).map(function (group) {
          return [group.displayName || '', group.name || ''].join(' ');
        }),
      )
      .concat((item.channels || []).map(function (channel) {
        return '#' + channel;
      }))
      .concat(
        (item.deliveries || []).map(function (delivery) {
          return [
            delivery.targetLabel || '',
            delivery.status || '',
            delivery.errorMessage || '',
          ].join(' ');
        }),
      )
      .join(' ')
      .toLowerCase();

    return haystack.indexOf(searchValue) !== -1;
  });
}

function matchHistoryStatus(item, filterValue) {
  if (filterValue === 'failed') {
    return Number(item.failedCount || 0) > 0;
  }
  if (filterValue === 'success') {
    return Number(item.sentCount || 0) > 0 && Number(item.failedCount || 0) === 0;
  }
  return true;
}

function matchHistoryTrigger(item, filterValue) {
  const trigger = item.trigger || { kind: 'manual' };
  if (filterValue === 'manual') {
    return trigger.kind !== 'inbound';
  }
  if (filterValue === 'inbound') {
    return trigger.kind === 'inbound';
  }
  if (filterValue === 'n8n') {
    return trigger.kind === 'inbound' && trigger.source === 'n8n';
  }
  return true;
}

function renderHistoryCard(item) {
  const trigger = item.trigger || { kind: 'manual' };
  const totalTargets =
    (item.users || []).length +
    (item.groups || []).length +
    (item.channels || []).length;
  const deliveryCount = (item.deliveries || []).length;
  const hiddenDeliveries = Math.max(deliveryCount - 10, 0);
  const targets = []
    .concat(
      (item.users || []).map(function (user) {
        return (
          '<span class="pill">' +
          escapeHtml(user.displayName || '@' + user.username) +
          '</span>'
        );
      }),
    )
    .concat(
      (item.groups || []).map(function (group) {
        return (
          '<span class="pill pill-group">' +
          escapeHtml(group.displayName || group.name || 'Группа') +
          '</span>'
        );
      }),
    )
    .concat(
      (item.channels || []).map(function (channel) {
        return '<span class="pill">#' + escapeHtml(channel) + '</span>';
      }),
    )
    .join('');

  const deliveries = (item.deliveries || [])
    .slice(0, 10)
    .map(function (delivery) {
      const statusClass =
        delivery.status === 'sent' ? 'status-sent' : 'status-failed';
      const statusLabel = delivery.status === 'sent' ? 'доставлено' : 'ошибка';
      const errorLine = delivery.errorMessage
        ? '<div class="subtitle">' + escapeHtml(delivery.errorMessage) + '</div>'
        : '';
      return (
        '<div class="search-card">' +
        '<strong>' +
        escapeHtml(delivery.targetLabel) +
        '</strong>' +
        '<div class="subtitle"><span class="' +
        statusClass +
        '">' +
        escapeHtml(statusLabel) +
        '</span></div>' +
        errorLine +
        '</div>'
      );
    })
    .join('');

  const triggerPills = []
    .concat(
      trigger.kind === 'inbound'
        ? ['Входящее событие', trigger.source ? 'Источник: ' + trigger.source : '']
        : ['Ручной запуск'],
    )
    .concat(trigger.ruleName ? ['Правило: ' + trigger.ruleName] : [])
    .concat(trigger.requestId ? ['request_id: ' + trigger.requestId] : [])
    .filter(Boolean)
    .map(function (label) {
      return '<span class="page-meta-pill">' + escapeHtml(label) + '</span>';
    })
    .join('');

  return (
    '<article class="history-card">' +
    '<div class="section-heading compact">' +
    '<div>' +
    '<h3>#' +
    escapeHtml(item.id) +
    ' от ' +
    escapeHtml(formatDate(item.createdAt)) +
    '</h3>' +
    '<div class="history-meta">' +
    '<span>Автор: ' +
    escapeHtml(item.createdBy) +
    '</span>' +
    '<span>Успешно: ' +
    escapeHtml(item.sentCount) +
    '</span>' +
    '<span>Ошибок: ' +
    escapeHtml(item.failedCount) +
    '</span>' +
    '<span>Точек доставки: ' +
    escapeHtml(totalTargets) +
    '</span>' +
    '</div></div></div>' +
    '<div class="history-origin-strip">' +
    triggerPills +
    '</div>' +
    '<div class="history-message-block">' +
    '<span class="metric-label">Сообщение</span>' +
    '<p class="history-message">' +
    escapeHtml(item.message) +
    '</p>' +
    '</div>' +
    '<div class="history-section-label">Аудитория и каналы</div>' +
    '<div class="history-targets">' +
    targets +
    '</div>' +
    '<div class="history-section-label">Результаты доставки</div>' +
    '<div class="search-results">' +
    deliveries +
    '</div>' +
    (hiddenDeliveries > 0
      ? '<p class="history-footnote muted">Показаны первые 10 доставок из ' +
        escapeHtml(deliveryCount) +
        '.</p>'
      : '') +
    '</article>'
  );
}

function renderSelectedAudience() {
  if (!state.selectedUsers.length && !state.selectedGroups.length) {
    elements.selectedAudience.innerHTML =
      '<span class="token-empty">Получатели ещё не выбраны</span>';
    renderComposerSummary();
    return;
  }

  const userChips = state.selectedUsers.map(function (user) {
    return (
      '<span class="pill">' +
      escapeHtml(user.displayName || '@' + user.username) +
      '<button type="button" data-remove-user="' +
      escapeHtml(user.id) +
      '">×</button>' +
      '</span>'
    );
  });
  const groupChips = state.selectedGroups.map(function (group) {
    const title = group.displayName || group.name || 'Группа';
    return (
      '<span class="pill pill-group">' +
      escapeHtml(title) +
      '<button type="button" data-remove-group="' +
      escapeHtml(group.id) +
      '">×</button>' +
      '</span>'
    );
  });

  elements.selectedAudience.innerHTML = userChips
    .concat(groupChips)
    .join('');

  elements.selectedAudience
    .querySelectorAll('[data-remove-user]')
    .forEach(function (button) {
      button.addEventListener('click', function () {
        const userId = button.getAttribute('data-remove-user');
        state.selectedUsers = state.selectedUsers.filter(function (user) {
          return String(user.id) !== String(userId);
        });
        renderSelectedAudience();
        loadAudience();
      });
    });

  elements.selectedAudience
    .querySelectorAll('[data-remove-group]')
    .forEach(function (button) {
      button.addEventListener('click', function () {
        const groupId = button.getAttribute('data-remove-group');
        state.selectedGroups = state.selectedGroups.filter(function (group) {
          return String(group.id) !== String(groupId);
        });
        renderSelectedAudience();
        loadAudience();
      });
    });

  renderComposerSummary();
}

function renderSelectedChannels() {
  if (!state.selectedChannels.length) {
    elements.selectedChannels.innerHTML =
      '<span class="token-empty">Каналы публикации ещё не добавлены</span>';
    renderComposerSummary();
    return;
  }

  elements.selectedChannels.innerHTML = state.selectedChannels
    .map(function (channel) {
      return (
        '<span class="pill">' +
        '#' +
        escapeHtml(channel) +
        '<button type="button" data-remove-channel="' +
        escapeHtml(channel) +
        '">×</button>' +
        '</span>'
      );
    })
    .join('');

  elements.selectedChannels
    .querySelectorAll('[data-remove-channel]')
    .forEach(function (button) {
      button.addEventListener('click', function () {
        const channelName = button.getAttribute('data-remove-channel');
        state.selectedChannels = state.selectedChannels.filter(function (channel) {
          return channel !== channelName;
        });
        renderSelectedChannels();
        loadChannels();
      });
    });

  renderComposerSummary();
}

function renderAdminUsers() {
  if (!state.adminUsers.length) {
    elements.adminUsersList.innerHTML =
      '<div class="history-card">Локальные пользователи пока не созданы.</div>';
    return;
  }

  const totalAdmins = state.adminUsers.filter(function (user) {
    return user.role === 'admin';
  }).length;
  const totalActive = state.adminUsers.filter(function (user) {
    return user.isActive;
  }).length;

  const rows = state.adminUsers
    .map(function (user) {
      return (
        '<article class="history-card admin-user-row-card" data-user-card="' +
        escapeHtml(user.id) +
        '">' +
        '<div class="admin-user-row-top">' +
        '<div class="admin-user-identity">' +
        '<div class="admin-user-main">' +
        '<h3>' +
        escapeHtml(user.displayName) +
        '</h3>' +
        '<p class="muted admin-user-email">' +
        escapeHtml(user.email || 'email не указан') +
        '</p>' +
        '</div>' +
        '<div class="history-meta history-meta-compact admin-user-meta">' +
        '<span class="page-meta-pill">@' +
        escapeHtml(user.username) +
        '</span>' +
        '<span class="page-meta-pill">' +
        escapeHtml(user.role === 'admin' ? 'администратор' : 'пользователь') +
        '</span>' +
        '<span class="page-meta-pill">' +
        escapeHtml(user.isActive ? 'активен' : 'отключён') +
        '</span>' +
        '</div>' +
        '</div>' +
        '<div class="admin-user-row-actions">' +
        '<button class="ghost-button" type="button" data-save-user="' +
        escapeHtml(user.id) +
        '">Сохранить</button>' +
        '<p class="muted admin-user-status" data-user-status></p>' +
        '</div>' +
        '</div>' +
        '<div class="admin-user-grid">' +
        '<label class="field"><span>Имя</span><input data-field="displayName" type="text" value="' +
        escapeHtml(user.displayName) +
        '" /></label>' +
        '<label class="field"><span>Email</span><input data-field="email" type="email" value="' +
        escapeHtml(user.email || '') +
        '" /></label>' +
        '<label class="field"><span>Роль</span><div class="select-shell"><select data-field="role">' +
        '<option value="user"' +
        (user.role === 'user' ? ' selected' : '') +
        '>Пользователь</option>' +
        '<option value="admin"' +
        (user.role === 'admin' ? ' selected' : '') +
        '>Администратор</option>' +
        '</select></div></label>' +
        '<label class="field"><span>Новый пароль</span><input data-field="password" type="password" placeholder="Оставь поле пустым, если пароль не меняется" /></label>' +
        '<label class="field inline-field admin-user-toggle"><span>Активен</span><input data-field="isActive" type="checkbox"' +
        (user.isActive ? ' checked' : '') +
        ' /></label>' +
        '</div>' +
        '</article>'
      );
    })
    .join('');

  elements.adminUsersList.innerHTML =
    '<div class="admin-list-summary">' +
    '<div class="admin-list-summary-copy">' +
    '<strong>Локальные аккаунты</strong>' +
    '<p class="muted">Компактное редактирование состава, ролей и доступов без перехода в отдельные карточки.</p>' +
    '</div>' +
    '<div class="history-meta admin-list-summary-meta">' +
    '<span class="page-meta-pill">Всего: ' +
    escapeHtml(state.adminUsers.length) +
    '</span>' +
    '<span class="page-meta-pill">Администраторов: ' +
    escapeHtml(totalAdmins) +
    '</span>' +
    '<span class="page-meta-pill">Активных: ' +
    escapeHtml(totalActive) +
    '</span>' +
    '</div>' +
    '</div>' +
    '<div class="admin-list-head" aria-hidden="true">' +
    '<span>Пользователь</span>' +
    '<span>Имя</span>' +
    '<span>Email</span>' +
    '<span>Роль</span>' +
    '<span>Пароль</span>' +
    '<span>Статус</span>' +
    '</div>' +
    rows;

  initializeCustomSelects(elements.adminUsersList);

  elements.adminUsersList
    .querySelectorAll('[data-save-user]')
    .forEach(function (button) {
      button.addEventListener('click', function () {
        onSaveManagedUser(button.getAttribute('data-save-user'));
      });
    });
}

function renderAdminRules() {
  if (!elements.adminRulesList) {
    return;
  }

  renderAdminRulesSummary();

  if (!state.adminRules.length) {
    elements.adminRulesList.innerHTML =
      '<div class="history-card">Правила пока не созданы.</div>';
    return;
  }

  elements.adminRulesList.innerHTML = state.adminRules
    .map(function (rule) {
      const labelFilters = JSON.stringify(rule.labelFilters || {}, null, 2);
      const recipientsCount =
        (rule.users || []).length +
        (rule.groups || []).length +
        (rule.channels || []).length;
      const totalRuns = Number(rule.totalRuns || 0);
      const failedRuns = Number(rule.failedRuns || 0);
      const matchSummary = buildRuleMatchSummary(rule);
      const templatePreview = (rule.messageTemplate || '').trim();
      return (
        '<article class="history-card admin-rule-card" data-rule-card="' +
        escapeHtml(rule.id) +
        '">' +
        '<div class="admin-rule-head">' +
        '<div class="admin-rule-main">' +
        '<div class="admin-user-main">' +
        '<h3>' +
        escapeHtml(rule.name) +
        '</h3>' +
        '<p class="muted admin-user-email">' +
        escapeHtml('Источник: ' + formatInboundSource(rule.source) + ' • ' + matchSummary) +
        '</p>' +
        '</div>' +
        '<div class="history-meta history-meta-compact admin-user-meta">' +
        '<span class="page-meta-pill">' +
        escapeHtml(rule.enabled ? 'активно' : 'выключено') +
        '</span>' +
        '<span class="page-meta-pill">' +
        escapeHtml(rule.ruleKey || 'без rule key') +
        '</span>' +
        '<span class="page-meta-pill">' +
        escapeHtml('Адресатов: ' + String(recipientsCount)) +
        '</span>' +
        '<span class="page-meta-pill">' +
        escapeHtml('Срабатываний: ' + String(totalRuns)) +
        '</span>' +
        '<span class="page-meta-pill">' +
        escapeHtml('Ошибок: ' + String(failedRuns)) +
        '</span>' +
        '</div>' +
        '</div>' +
        '<div class="admin-user-row-actions">' +
        '<button class="ghost-button" type="button" data-save-rule="' +
        escapeHtml(rule.id) +
        '">Сохранить</button>' +
        '<p class="muted admin-user-status" data-rule-status></p>' +
        '</div>' +
        '</div>' +
        '<div class="admin-rule-telemetry">' +
        '<span class="metric-label">Последнее событие</span>' +
        '<strong>' +
        escapeHtml(
          rule.lastTriggeredAt ? formatDate(rule.lastTriggeredAt) : 'Пока не срабатывало',
        ) +
        '</strong>' +
        '<span class="muted">Обновлено: ' +
        escapeHtml(formatDate(rule.updatedAt)) +
        '</span>' +
        '</div>' +
        '<div class="admin-rule-layout">' +
        '<section class="admin-rule-column">' +
        '<div class="admin-rule-column-title">Маршрутизация</div>' +
        '<div class="admin-rule-grid">' +
        '<label class="field"><span>Название</span><input data-rule-field="name" type="text" value="' +
        escapeHtml(rule.name || '') +
        '" /></label>' +
        '<label class="field"><span>Источник</span><div class="select-shell"><select data-rule-field="source">' +
        '<option value="n8n"' +
        (rule.source === 'n8n' ? ' selected' : '') +
        '>n8n</option>' +
        '<option value="alertmanager"' +
        (rule.source === 'alertmanager' ? ' selected' : '') +
        '>Alertmanager / Grafana</option>' +
        '</select></div></label>' +
        '<label class="field"><span>Rule key</span><input data-rule-field="ruleKey" type="text" value="' +
        escapeHtml(rule.ruleKey || '') +
        '" /></label>' +
        '<label class="field"><span>Тип события</span><input data-rule-field="eventType" type="text" value="' +
        escapeHtml(rule.eventType || '') +
        '" /></label>' +
        '<label class="field"><span>Severity</span><input data-rule-field="severity" type="text" value="' +
        escapeHtml(rule.severity || '') +
        '" /></label>' +
        '<label class="field settings-field-wide"><span>Фильтры labels</span><textarea data-rule-field="labelFilters" rows="3">' +
        escapeHtml(labelFilters) +
        '</textarea></label>' +
        '<label class="field settings-field-wide"><span>Фильтр по тексту</span><input data-rule-field="containsText" type="text" value="' +
        escapeHtml(rule.containsText || '') +
        '" /></label>' +
        '</div>' +
        '</section>' +
        '<section class="admin-rule-column">' +
        '<div class="admin-rule-column-title">Получатели и сообщение</div>' +
        '<div class="admin-rule-grid">' +
        '<label class="field"><span>Пользователи</span><input data-rule-field="users" type="text" value="' +
        escapeHtml((rule.users || []).join(', ')) +
        '" /></label>' +
        '<label class="field"><span>Группы</span><input data-rule-field="groups" type="text" value="' +
        escapeHtml((rule.groups || []).join(', ')) +
        '" /></label>' +
        '<label class="field"><span>Каналы</span><input data-rule-field="channels" type="text" value="' +
        escapeHtml((rule.channels || []).join(', ')) +
        '" /></label>' +
        '<label class="field settings-field-wide"><span>Шаблон сообщения</span><textarea data-rule-field="messageTemplate" rows="4">' +
        escapeHtml(rule.messageTemplate || '') +
        '</textarea></label>' +
        '<label class="field inline-field admin-user-toggle"><span>Активно</span><input data-rule-field="enabled" type="checkbox"' +
        (rule.enabled ? ' checked' : '') +
        ' /></label>' +
        '<div class="admin-rule-preview-card settings-field-wide">' +
        '<span class="metric-label">Превью шаблона</span>' +
        '<p class="admin-rule-preview">' +
        escapeHtml(
          templatePreview.isNotEmpty
            ? templatePreview
            : 'Если шаблон пустой, в рассылку уйдёт исходный message из входящего события.',
        ) +
        '</p>' +
        '</div>' +
        '</div>' +
        '</section>' +
        '</div>' +
        '</article>'
      );
    })
    .join('');

  elements.adminRulesList
    .querySelectorAll('[data-save-rule]')
    .forEach(function (button) {
      button.addEventListener('click', function () {
        onSaveRule(button.getAttribute('data-save-rule'));
      });
    });

  initializeCustomSelects(elements.adminRulesList);
}

function renderAdminInboundEvents() {
  if (!elements.adminInboundEvents) {
    return;
  }

  if (!state.adminInboundEvents.length) {
    elements.adminInboundEvents.innerHTML =
      '<div class="history-card">Входящих событий пока не было.</div>';
    return;
  }

  elements.adminInboundEvents.innerHTML = state.adminInboundEvents
    .map(function (event) {
      const statusClass =
        event.status === 'sent' ? 'status-sent' : 'status-failed';
      const statusLabel =
        event.status === 'sent' ? 'обработано' : event.status || 'ошибка';
      const messageText = (event.message || '').trim();
      return (
        '<article class="history-card admin-inbound-event-card">' +
        '<div class="section-heading compact">' +
        '<div>' +
        '<h3>' +
        escapeHtml(event.ruleName || 'Без правила') +
        '</h3>' +
        '<div class="history-meta">' +
        '<span class="page-meta-pill">' +
        escapeHtml(event.source || 'n8n') +
        '</span>' +
        '<span class="page-meta-pill">' +
        escapeHtml(event.requestId || 'без request_id') +
        '</span>' +
        (event.campaignId
          ? '<span class="page-meta-pill">Кампания #' +
            escapeHtml(event.campaignId) +
            '</span>'
          : '') +
        '</div>' +
        '</div>' +
        '<span class="' +
        statusClass +
        '">' +
        escapeHtml(statusLabel) +
        '</span>' +
        '</div>' +
        '<p class="muted admin-inbound-event-time">' +
        escapeHtml(formatDate(event.createdAt)) +
        '</p>' +
        (messageText
          ? '<p class="admin-rule-preview">' + escapeHtml(messageText) + '</p>'
          : '') +
        (event.errorMessage
          ? '<p class="status-negative admin-inbound-event-error">' +
            escapeHtml(event.errorMessage) +
            '</p>'
          : '') +
        '<div class="admin-inbound-event-actions">' +
        (event.campaignId
          ? '<button class="ghost-button subtle-button" type="button" data-open-history-campaign="' +
            escapeHtml(event.campaignId) +
            '">Открыть в истории</button>'
          : '') +
        '</div>' +
        '</article>'
      );
    })
    .join('');
}

async function openHistoryFromInbound(campaignId) {
  if (!campaignId) {
    return;
  }

  if (!state.history.length) {
    await loadHistory();
  }

  state.historySearch = '#' + String(campaignId);
  state.historyStatusFilter = 'all';
  state.historyTriggerFilter = 'all';

  if (elements.historySearch) {
    elements.historySearch.value = state.historySearch;
  }
  if (elements.historyStatusFilter) {
    elements.historyStatusFilter.value = 'all';
  }
  if (elements.historyTriggerFilter) {
    elements.historyTriggerFilter.value = 'all';
  }
  syncCustomSelects(document);
  switchView('history');
  renderHistory();
}

function renderAdminRulesSummary() {
  if (!elements.adminRulesSummary) {
    return;
  }

  const settings = state.adminSettings || {};
  const total = state.adminRules.length;
  const enabled = state.adminRules.filter(function (rule) {
    return rule.enabled;
  }).length;
  const withRuleKey = state.adminRules.filter(function (rule) {
    return Boolean((rule.ruleKey || '').trim());
  }).length;
  const withTemplates = state.adminRules.filter(function (rule) {
    return Boolean((rule.messageTemplate || '').trim());
  }).length;
  const triggered = state.adminRules.filter(function (rule) {
    return Number(rule.totalRuns || 0) > 0;
  }).length;
  const lastInbound = (state.adminInboundEvents || []).find(function (event) {
    return event.status === 'sent';
  });
  const inboundSecretConfigured = Boolean((settings.n8nInboundSecret || '').trim());
  const routeLabel = formatDeliveryMode(
    settings.deliveryMode || (state.appSettings && state.appSettings.deliveryMode) || 'mattermost',
  );

  elements.adminRulesSummary.innerHTML =
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Inbound secret</span>' +
    '<strong class="metric-value">' +
    escapeHtml(inboundSecretConfigured ? 'Настроен' : 'Не задан') +
    '</strong>' +
    '<p class="muted">Защита endpoint `/api/incoming/n8n`.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Маршрут</span>' +
    '<strong class="metric-value">' +
    escapeHtml(routeLabel) +
    '</strong>' +
    '<p class="muted">Текущий контур доставки для входящих событий.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Всего правил</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(total)) +
    '</strong>' +
    '<p class="muted">Активные сценарии обработки входящих событий.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Активно</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(enabled)) +
    '</strong>' +
    '<p class="muted">Правила, которые сейчас участвуют в маршрутизации.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Rule key</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(withRuleKey)) +
    '</strong>' +
    '<p class="muted">Правила, которые можно вызывать адресно из n8n.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Шаблоны</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(withTemplates)) +
    '</strong>' +
    '<p class="muted">Правила с собственным текстом поверх входящего события.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Срабатывали</span>' +
    '<strong class="metric-value">' +
    escapeHtml(String(triggered)) +
    '</strong>' +
    '<p class="muted">Правила, по которым уже были входящие события.</p>' +
    '</article>' +
    '<article class="settings-overview-card">' +
    '<span class="metric-label">Последний успех</span>' +
    '<strong class="metric-value">' +
    escapeHtml(lastInbound ? formatDate(lastInbound.createdAt) : 'Пока нет') +
    '</strong>' +
    '<p class="muted">' +
    escapeHtml(
      lastInbound
        ? (lastInbound.ruleName || 'Событие без правила')
        : 'После первой успешной обработки появится здесь.',
    ) +
    '</p>' +
    '</article>';
}

function buildRuleMatchSummary(rule) {
  const parts = [];
  if ((rule.eventType || '').trim()) {
    parts.push('тип: ' + rule.eventType.trim());
  }
  if ((rule.severity || '').trim()) {
    parts.push('severity: ' + rule.severity.trim());
  }
  if ((rule.containsText || '').trim()) {
    parts.push('текст содержит: ' + rule.containsText.trim());
  }
  const labelFilters = rule.labelFilters || {};
  const labelKeys = Object.keys(labelFilters).filter(function (key) {
    return String(labelFilters[key] || '').trim() !== '';
  });
  if (labelKeys.length) {
    parts.push('labels: ' + labelKeys.join(', '));
  }
  if (!parts.length) {
    return 'без дополнительных условий';
  }
  return parts.join(' • ');
}

function collectRuleFormPayload() {
  return {
    name: elements.ruleName.value.trim(),
    source: elements.ruleSource.value,
    ruleKey: elements.ruleKey.value.trim(),
    eventType: elements.ruleEventType.value.trim(),
    severity: elements.ruleSeverity.value.trim(),
    containsText: elements.ruleContainsText.value.trim(),
    labelFilters: parseJsonObjectInput(elements.ruleLabelFilters.value),
    users: splitCommaList(elements.ruleUsers.value),
    groups: splitCommaList(elements.ruleGroups.value),
    channels: splitCommaList(elements.ruleChannels.value),
    messageTemplate: elements.ruleMessageTemplate.value.trim(),
    enabled: elements.ruleEnabled.checked,
  };
}

function formatInboundSource(source) {
  return source === 'alertmanager' ? 'Alertmanager / Grafana' : 'n8n';
}

function parseJsonObjectInput(value) {
  const source = (value || '').trim();
  if (!source) {
    return {};
  }
  try {
    const parsed = JSON.parse(source);
    if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') {
      return null;
    }
    return parsed;
  } catch (_) {
    return null;
  }
}

function renderSearchResults(container, items, emptyText, onSelect, kind) {
  const input = kind === 'channel' ? elements.channelInput : elements.audienceSearch;
  if (!items.length) {
    resetSearchActiveIndex(kind);
    container.innerHTML =
      '<div class="search-empty">' + escapeHtml(emptyText) + '</div>';
    input.setAttribute('aria-expanded', 'false');
    input.removeAttribute('aria-activedescendant');
    return;
  }

  container.innerHTML = '';
  input.setAttribute('aria-expanded', 'true');
  items.slice(0, 8).forEach(function (item) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'search-card';
    button.setAttribute('role', 'option');

    const title = document.createElement('strong');
    title.textContent =
      item.displayName || item.name || item.username || item.groupName;

    const subtitle = document.createElement('div');
    subtitle.className = 'subtitle';
    if (item.kind === 'group') {
      subtitle.textContent =
        'Группа' +
        (item.memberCount ? ' · ' + item.memberCount + ' участников' : '');
    } else if (item.email) {
      subtitle.textContent = item.username + ' · ' + item.email;
    } else if (item.displayName && item.name) {
      subtitle.textContent = '#' + item.name;
    } else {
      subtitle.textContent = item.username || '';
    }

    button.appendChild(title);
    button.appendChild(subtitle);
    if (onSelect) {
      button.addEventListener('click', function () {
        onSelect(item);
      });
    } else {
      button.disabled = true;
    }
    container.appendChild(button);
  });

  resetSearchActiveIndex(kind);
}

function renderComposerSummary() {
  if (!elements.composerUsersCount) {
    return;
  }
  elements.composerUsersCount.textContent = String(state.selectedUsers.length);
  elements.composerGroupsCount.textContent = String(state.selectedGroups.length);
  elements.composerChannelsCount.textContent = String(state.selectedChannels.length);
  elements.composerRoute.textContent =
    formatDeliveryMode(state.appSettings && state.appSettings.deliveryMode);
  const composerState = getComposerState();
  elements.sendButton.disabled = !composerState.ready;
  updateComposerFieldStates();
  if (!elements.sendStatus.textContent || elements.sendStatus.dataset.mode === 'hint') {
    setStatus(
      elements.sendStatus,
      composerState.ready ? 'Рассылка готова к отправке.' : composerState.hint,
      composerState.ready ? 'positive' : 'neutral',
    );
  }
}

function getComposerState() {
  const message = elements.messageInput.value.trim();
  const hasAudience =
    state.selectedUsers.length > 0 ||
    state.selectedGroups.length > 0 ||
    state.selectedChannels.length > 0;
  if (!message && !hasAudience) {
    return {
      ready: false,
      hint: 'Добавь текст и хотя бы одного получателя, группу или канал.',
    };
  }
  if (!message) {
    return {
      ready: false,
      hint: 'Сначала добавь текст рассылки.',
    };
  }
  if (!hasAudience) {
    return {
      ready: false,
      hint: 'Выбери хотя бы одного получателя, группу или канал.',
    };
  }
  return {
    ready: true,
    hint: 'Рассылка готова к отправке.',
  };
}

function updateComposerFieldStates() {
  const message = elements.messageInput.value.trim();
  const hasAudience =
    state.selectedUsers.length > 0 ||
    state.selectedGroups.length > 0 ||
    state.selectedChannels.length > 0;
  const hasChannels = state.selectedChannels.length > 0;

  markFieldInvalid(elements.messageInput, !message);
  markFieldInvalid(elements.audienceSearch, !hasAudience && !hasChannels);
  markFieldInvalid(elements.channelInput, false);
  elements.selectedAudience.parentElement.classList.toggle(
    'is-invalid',
    !hasAudience && !hasChannels,
  );

  elements.messageHint.textContent = message
    ? 'Сообщение заполнено и будет отправлено в выбранные точки доставки.'
    : 'Добавь короткий и однозначный текст сообщения.';
  elements.messageHint.className =
    'field-hint' + (message ? '' : ' field-error');

  elements.audienceHint.textContent = hasAudience || hasChannels
    ? 'Маршрут доставки собран. Можно отправлять после финальной проверки.'
    : 'Выбери хотя бы одного получателя, группу или канал публикации.';
  elements.audienceHint.className =
    'field-hint' + (hasAudience || hasChannels ? '' : ' field-error');

  elements.channelHint.textContent = hasChannels
    ? 'Каналы добавлены в маршрут публикации.'
    : 'Нажми Enter, чтобы добавить канал вручную, или выбери его из подсказок.';
  elements.channelHint.className = 'field-hint';
}

function handleSearchNavigation(event, container, kind) {
  const options = Array.from(
    container.querySelectorAll('.search-card:not([disabled])'),
  );
  if (!options.length) {
    return;
  }

  const stateKey =
    kind === 'channel' ? 'channelActiveIndex' : 'audienceActiveIndex';
  const input =
    kind === 'channel' ? elements.channelInput : elements.audienceSearch;

  if (event.key === 'ArrowDown') {
    event.preventDefault();
    state[stateKey] = (state[stateKey] + 1) % options.length;
    updateSearchActiveOption(options, state[stateKey], input);
    return;
  }

  if (event.key === 'ArrowUp') {
    event.preventDefault();
    state[stateKey] =
      state[stateKey] <= 0 ? options.length - 1 : state[stateKey] - 1;
    updateSearchActiveOption(options, state[stateKey], input);
    return;
  }

  if (event.key === 'Escape') {
    resetSearchActiveIndex(kind);
    input.removeAttribute('aria-activedescendant');
    return;
  }

  if (
    event.key === 'Enter' &&
    state[stateKey] >= 0 &&
    state[stateKey] < options.length
  ) {
    event.preventDefault();
    options[state[stateKey]].click();
  }
}

function updateSearchActiveOption(options, activeIndex, input) {
  options.forEach(function (option, index) {
    option.classList.toggle('is-active', index === activeIndex);
    if (index === activeIndex) {
      if (!option.id) {
        option.id =
          'search-option-' +
          index +
          '-' +
          Math.random().toString(36).slice(2, 8);
      }
      input.setAttribute('aria-activedescendant', option.id);
      option.scrollIntoView({ block: 'nearest' });
    }
  });
}

function resetSearchActiveIndex(kind) {
  if (kind === 'channel') {
    state.channelActiveIndex = -1;
  } else {
    state.audienceActiveIndex = -1;
  }
}

function setStatus(node, message, tone) {
  node.textContent = message || '';
  node.dataset.mode = tone || 'neutral';
  node.classList.remove('status-positive', 'status-negative', 'status-neutral');
  if (tone === 'positive') {
    node.classList.add('status-positive');
  } else if (tone === 'negative') {
    node.classList.add('status-negative');
  } else {
    node.classList.add('status-neutral');
  }
}

function markFieldInvalid(field, isInvalid) {
  if (!field) {
    return;
  }
  field.classList.toggle('is-invalid', Boolean(isInvalid));
  field.setAttribute('aria-invalid', isInvalid ? 'true' : 'false');
}

function clearFieldState(field) {
  markFieldInvalid(field, false);
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || '').trim());
}

function formatDeliveryMode(mode) {
  return mode === 'n8n' ? 'n8n automation' : 'Mattermost API';
}

function formatSettingsPanelLabel(panelId) {
  const labels = {
    product: 'Продукт',
    mattermost: 'Mattermost',
    n8n: 'n8n',
    email: 'Почта',
    auth: 'Авторизация',
  };
  return labels[panelId] || 'Продукт';
}

function showLogin() {
  resetLoginPasswordVisibility();
  switchAuthMode(state.authMode);
  elements.loginView.classList.remove('hidden');
  elements.appView.classList.add('hidden');
  syncViewportScrollbarOffset();
}

function toggleLoginPasswordVisibility() {
  if (!elements.loginPassword || !elements.loginPasswordToggle) {
    return;
  }

  const isVisible = elements.loginPassword.type === 'text';
  elements.loginPassword.type = isVisible ? 'password' : 'text';
  elements.loginPasswordToggle.textContent = isVisible ? 'Показать' : 'Скрыть';
  elements.loginPasswordToggle.setAttribute(
    'aria-label',
    isVisible ? 'Показать пароль' : 'Скрыть пароль',
  );
  elements.loginPasswordToggle.setAttribute(
    'aria-pressed',
    isVisible ? 'false' : 'true',
  );
}

function resetLoginPasswordVisibility() {
  if (!elements.loginPassword || !elements.loginPasswordToggle) {
    return;
  }

  elements.loginPassword.type = 'password';
  elements.loginPasswordToggle.textContent = 'Показать';
  elements.loginPasswordToggle.setAttribute('aria-label', 'Показать пароль');
  elements.loginPasswordToggle.setAttribute('aria-pressed', 'false');
}

function showApp() {
  elements.loginView.classList.add('hidden');
  elements.appView.classList.remove('hidden');
  syncViewportScrollbarOffset();
}

function toggleTheme() {
  state.theme = state.theme === 'day' ? 'night' : 'day';
  writeStoredTheme(state.theme);
  applyTheme();
}

function applyTheme() {
  const theme = state.theme === 'night' ? 'night' : 'day';
  document.documentElement.dataset.theme = theme;
  document.body.dataset.theme = theme;
  elements.themeToggle.textContent =
    state.theme === 'night' ? 'Дневной режим' : 'Ночной режим';
}

function initializeCustomSelects(root) {
  const scope = root || document;
  scope.querySelectorAll('select').forEach(function (select) {
    if (select.dataset.customSelectReady === 'true') {
      refreshCustomSelect(select);
      return;
    }
    buildCustomSelect(select);
  });
}

function buildCustomSelect(select) {
  let shell = select.closest('.select-shell');
  if (!shell) {
    shell = document.createElement('div');
    shell.className = 'select-shell';
    select.parentNode.insertBefore(shell, select);
    shell.appendChild(select);
  }

  shell.classList.add('custom-select');
  select.classList.add('native-select');
  select.dataset.customSelectReady = 'true';

  const listId = select.id
    ? select.id + '-listbox'
    : 'custom-select-' + String(++state.customSelectCounter);

  const trigger = document.createElement('button');
  trigger.type = 'button';
  trigger.className = 'custom-select-trigger';
  trigger.setAttribute('aria-haspopup', 'listbox');
  trigger.setAttribute('aria-expanded', 'false');
  trigger.setAttribute('aria-controls', listId);

  const triggerLabel = document.createElement('span');
  triggerLabel.className = 'custom-select-label';
  trigger.appendChild(triggerLabel);

  const menu = document.createElement('div');
  menu.className = 'custom-select-menu hidden';
  menu.id = listId;
  menu.setAttribute('role', 'listbox');

  Array.from(select.options).forEach(function (option, index) {
    const optionButton = document.createElement('button');
    optionButton.type = 'button';
    optionButton.className = 'custom-select-option';
    optionButton.dataset.value = option.value;
    optionButton.dataset.index = String(index);
    optionButton.setAttribute('role', 'option');
    optionButton.textContent = option.textContent || option.label || option.value;
    optionButton.addEventListener('click', function () {
      if (select.value !== option.value) {
        select.value = option.value;
        select.dispatchEvent(new Event('change', { bubbles: true }));
      } else {
        refreshCustomSelect(select);
      }
      closeCustomSelect(shell);
      trigger.focus();
    });
    menu.appendChild(optionButton);
  });

  trigger.addEventListener('click', function () {
    if (shell.classList.contains('is-open')) {
      closeCustomSelect(shell);
    } else {
      openCustomSelect(shell);
    }
  });

  trigger.addEventListener('keydown', function (event) {
    if (
      event.key === 'ArrowDown' ||
      event.key === 'ArrowUp' ||
      event.key === 'Enter' ||
      event.key === ' '
    ) {
      event.preventDefault();
      openCustomSelect(shell);
      return;
    }
    if (event.key === 'Escape') {
      closeCustomSelect(shell);
    }
  });

  menu.addEventListener('keydown', function (event) {
    const options = Array.from(menu.querySelectorAll('.custom-select-option'));
    const currentIndex = options.findIndex(function (button) {
      return button === document.activeElement;
    });

    if (event.key === 'Escape') {
      event.preventDefault();
      closeCustomSelect(shell);
      trigger.focus();
      return;
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      const nextIndex = currentIndex < options.length - 1 ? currentIndex + 1 : 0;
      if (options[nextIndex]) {
        options[nextIndex].focus();
      }
      return;
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault();
      const prevIndex = currentIndex > 0 ? currentIndex - 1 : options.length - 1;
      if (options[prevIndex]) {
        options[prevIndex].focus();
      }
    }
  });

  select.addEventListener('change', function () {
    refreshCustomSelect(select);
  });

  shell.appendChild(trigger);
  shell.appendChild(menu);
  refreshCustomSelect(select);
}

function refreshCustomSelect(select) {
  const shell = select.closest('.custom-select');
  if (!shell) {
    return;
  }

  const triggerLabel = shell.querySelector('.custom-select-label');
  const options = Array.from(shell.querySelectorAll('.custom-select-option'));
  const selectedIndex = select.selectedIndex >= 0 ? select.selectedIndex : 0;
  const selectedOption = select.options[selectedIndex];

  if (triggerLabel && selectedOption) {
    triggerLabel.textContent =
      selectedOption.textContent || selectedOption.label || selectedOption.value;
  }

  options.forEach(function (button, index) {
    const isSelected = index === selectedIndex;
    button.classList.toggle('is-selected', isSelected);
    button.setAttribute('aria-selected', isSelected ? 'true' : 'false');
    button.tabIndex = isSelected ? 0 : -1;
  });
}

function syncCustomSelects(root) {
  const scope = root || document;
  scope
    .querySelectorAll('select[data-custom-select-ready="true"]')
    .forEach(function (select) {
      refreshCustomSelect(select);
    });
}

function openCustomSelect(shell) {
  if (!shell) {
    return;
  }
  closeCustomSelects(shell);
  shell.classList.add('is-open');
  const trigger = shell.querySelector('.custom-select-trigger');
  const menu = shell.querySelector('.custom-select-menu');
  if (trigger) {
    trigger.setAttribute('aria-expanded', 'true');
  }
  if (menu) {
    menu.classList.remove('hidden');
    const selected = menu.querySelector('.custom-select-option.is-selected');
    if (selected) {
      selected.focus();
    }
  }
}

function closeCustomSelect(shell) {
  if (!shell) {
    return;
  }
  shell.classList.remove('is-open');
  const trigger = shell.querySelector('.custom-select-trigger');
  const menu = shell.querySelector('.custom-select-menu');
  if (trigger) {
    trigger.setAttribute('aria-expanded', 'false');
  }
  if (menu) {
    menu.classList.add('hidden');
  }
}

function closeCustomSelects(exceptShell) {
  document.querySelectorAll('.custom-select.is-open').forEach(function (shell) {
    if (shell !== exceptShell) {
      closeCustomSelect(shell);
    }
  });
}

function handleDocumentClick(event) {
  if (!event.target.closest('.custom-select')) {
    closeCustomSelects();
  }
}

function handleDocumentKeydown(event) {
  if (event.key === 'Escape') {
    closeCustomSelects();
  }
}

function prepareLookupInput(input) {
  if (!input) {
    return;
  }

  input.readOnly = true;

  function unlock() {
    if (input.readOnly) {
      input.readOnly = false;
    }
  }

  input.addEventListener(
    'pointerdown',
    function () {
      unlock();
    },
    { passive: true },
  );

  input.addEventListener('focus', function () {
    unlock();
  });

  input.addEventListener('blur', function () {
    window.setTimeout(function () {
      if (document.activeElement !== input) {
        input.readOnly = true;
      }
    }, 0);
  });
}

function syncViewportScrollbarOffset() {
  const scrollbarWidth = Math.max(
    0,
    window.innerWidth - document.documentElement.clientWidth,
  );
  document.documentElement.style.setProperty(
    '--viewport-scrollbar-offset',
    scrollbarWidth > 0 ? scrollbarWidth / 2 + 'px' : '0px',
  );
}

function isAdmin() {
  return state.currentUser && state.currentUser.role === 'admin';
}

function describeIntegrations() {
  if (!state.appSettings) {
    return 'Нет данных';
  }
  const items =
    state.appSettings.integrations &&
    Array.isArray(state.appSettings.integrations.items)
      ? state.appSettings.integrations.items
      : [];
  const enabledLabels = items
    .filter(function (item) {
      return item.enabled;
    })
    .map(function (item) {
      return item.label;
    });
  if (enabledLabels.length) {
    return enabledLabels.join(' + ');
  }

  const configuredLabels = items
    .filter(function (item) {
      return item.configured;
    })
    .map(function (item) {
      return item.label;
    });

  return configuredLabels.length
    ? configuredLabels.join(' + ')
    : 'Не настроен';
}

function splitCommaList(value) {
  return value
    .split(',')
    .map(function (item) {
      return item.trim().replace(/^#/, '');
    })
    .filter(function (item) {
      return Boolean(item);
    });
}

function handleAuthRoute() {
  const params = new URLSearchParams(window.location.search);
  const loginError = params.get('login_error');
  if (loginError) {
    state.authMessage = loginError;
    history.replaceState(null, '', window.location.pathname);
  }
  const resetToken = params.get('reset_token');
  if (resetToken) {
    state.resetToken = resetToken;
    switchAuthMode('reset');
    validateResetToken(resetToken);
    return;
  }
  switchAuthMode('login');
}

async function validateResetToken(token) {
  const response = await api('/api/password/reset/' + encodeURIComponent(token));
  if (!response.ok || !response.valid) {
    state.resetToken = null;
    switchAuthMode('forgot');
    elements.loginError.textContent =
      response.error || 'Ссылка восстановления недействительна.';
    return;
  }
  elements.loginError.textContent =
    'Задай новый пароль для аккаунта ' + response.user.username + '.';
}

function switchAuthMode(mode) {
  state.authMode = mode;
  elements.loginForm.classList.add('hidden');
  elements.forgotForm.classList.add('hidden');
  elements.resetForm.classList.add('hidden');
  elements.showForgotButton.classList.add('hidden');
  elements.showLoginButton.classList.add('hidden');
  elements.loginError.textContent = '';

  if (mode === 'forgot') {
    if (!isLocalAuthEnabled()) {
      switchAuthMode('login');
      return;
    }
    elements.authTitle.textContent = 'Восстановление доступа';
    elements.authSubtitle.textContent =
      'Укажи логин или email. Если почта подключена, мы отправим ссылку для смены пароля.';
    elements.forgotForm.classList.remove('hidden');
    elements.showLoginButton.classList.remove('hidden');
    return;
  }

  if (mode === 'reset') {
    if (!isLocalAuthEnabled()) {
      switchAuthMode('login');
      return;
    }
    elements.authTitle.textContent = 'Новый пароль';
    elements.authSubtitle.textContent =
      'Ссылка действует ограниченное время. После смены пароля можно сразу войти в продукт.';
    elements.resetForm.classList.remove('hidden');
    elements.showLoginButton.classList.remove('hidden');
    return;
  }

  elements.authTitle.textContent = 'Вход в личный кабинет';
  elements.authSubtitle.textContent = 'Корпоративная система рассылок.';
  elements.loginForm.classList.toggle('hidden', !isLocalAuthEnabled());
  elements.showForgotButton.classList.toggle('hidden', !isLocalAuthEnabled());
  elements.authSsoPanel.classList.toggle('hidden', !isKeycloakEnabled());
  elements.authDivider.classList.toggle(
    'hidden',
    !(isLocalAuthEnabled() && isKeycloakEnabled()),
  );
  if (state.authMessage) {
    elements.loginError.textContent = state.authMessage;
    state.authMessage = '';
  }
}

function isLocalAuthEnabled() {
  if (!state.publicSettings || !state.publicSettings.auth) {
    return true;
  }
  return state.publicSettings.auth.localEnabled === true;
}

function isKeycloakEnabled() {
  if (!state.publicSettings || !state.publicSettings.auth) {
    return false;
  }
  return state.publicSettings.auth.keycloakEnabled === true;
}

async function api(url, options) {
  const resolvedOptions = options || {};
  try {
    const response = await performRequest(url, resolvedOptions);
    const payload = response.body ? safeJsonParse(response.body) : {};
    return {
      ok: response.ok && payload.ok !== false,
      status: response.status,
      ...payload,
    };
  } catch (error) {
    return {
      ok: false,
      error: error.message || 'Network error',
    };
  }
}

function performRequest(url, options) {
  if (window.fetch) {
    return fetch(url, {
      credentials: 'include',
      headers: Object.assign(
        {
          'Content-Type': 'application/json',
        },
        options.headers || {},
      ),
      method: options.method || 'GET',
      body: options.body,
    }).then(function (response) {
      return response
        .text()
        .catch(function () {
          return '';
        })
        .then(function (body) {
          return {
            ok: response.ok,
            status: response.status,
            body: body,
          };
        });
    });
  }

  return new Promise(function (resolve, reject) {
    const request = new XMLHttpRequest();
    request.open(options.method || 'GET', url, true);
    request.withCredentials = true;
    request.setRequestHeader('Content-Type', 'application/json');

    const headers = options.headers || {};
    Object.keys(headers).forEach(function (key) {
      request.setRequestHeader(key, headers[key]);
    });

    request.onreadystatechange = function () {
      if (request.readyState !== 4) {
        return;
      }
      resolve({
        ok: request.status >= 200 && request.status < 300,
        status: request.status,
        body: request.responseText || '',
      });
    };
    request.onerror = function () {
      reject(new Error('Network error'));
    };
    request.send(options.body || null);
  });
}

function debounce(callback, delay) {
  let timeoutId;
  return function () {
    const args = arguments;
    clearTimeout(timeoutId);
    timeoutId = setTimeout(function () {
      callback.apply(null, args);
    }, delay);
  };
}

function bindSubmitOnEnter(input, form) {
  if (!input || !form) {
    return;
  }
  input.addEventListener('keydown', function (event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      if (typeof form.requestSubmit === 'function') {
        form.requestSubmit();
        return;
      }
      form.dispatchEvent(new Event('submit', { cancelable: true }));
    }
  });
}

function safeJsonParse(value) {
  try {
    return JSON.parse(value);
  } catch (error) {
    return {};
  }
}

function replaceAllCompat(value, search, replacement) {
  return String(value).split(search).join(replacement);
}

function escapeHtml(value) {
  let result = String(value);
  result = replaceAllCompat(result, '&', '&amp;');
  result = replaceAllCompat(result, '<', '&lt;');
  result = replaceAllCompat(result, '>', '&gt;');
  result = replaceAllCompat(result, '"', '&quot;');
  result = replaceAllCompat(result, "'", '&#039;');
  return result;
}

function formatDate(value) {
  return new Date(value).toLocaleString('ru-RU');
}

function readStoredTheme() {
  try {
    return window.localStorage ? localStorage.getItem('cannonball-theme') : null;
  } catch (error) {
    return null;
  }
}

function writeStoredTheme(value) {
  try {
    if (window.localStorage) {
      localStorage.setItem('cannonball-theme', value);
    }
  } catch (error) {
    return;
  }
}
