import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'settings_service.dart';

class EmailService {
  Future<void> sendPasswordReset({
    required AppSettings settings,
    required String recipientEmail,
    required String recipientName,
    required String resetLink,
  }) async {
    if (!settings.isEmailConfigured) {
      throw StateError(
        'Email integration is not configured in the platform settings.',
      );
    }

    final smtpServer = SmtpServer(
      settings.smtpHost,
      port: settings.smtpPort,
      username: settings.smtpUsername,
      password: settings.smtpPassword,
      ssl: settings.smtpUseSsl,
      allowInsecure: !settings.smtpUseSsl,
    );

    final productName = settings.appTitle.isNotEmpty
        ? settings.appTitle
        : 'cannonball';
    final message = Message()
      ..from = Address(
        settings.smtpFromEmail,
        settings.smtpFromName.isNotEmpty ? settings.smtpFromName : productName,
      )
      ..recipients.add(recipientEmail)
      ..subject = '$productName: восстановление пароля'
      ..text =
          '''
Здравствуйте, ${recipientName.isNotEmpty ? recipientName : recipientEmail}.

Вы запросили восстановление пароля в $productName.

Откройте ссылку, чтобы задать новый пароль:
$resetLink

Ссылка действует 1 час. Если вы не запрашивали сброс, просто проигнорируйте это письмо.
'''
      ..html =
          '''
<p>Здравствуйте, ${_escapeHtml(recipientName.isNotEmpty ? recipientName : recipientEmail)}.</p>
<p>Вы запросили восстановление пароля в <strong>${_escapeHtml(productName)}</strong>.</p>
<p><a href="${_escapeHtml(resetLink)}">Открыть страницу сброса пароля</a></p>
<p>Ссылка действует 1 час. Если вы не запрашивали сброс, просто проигнорируйте это письмо.</p>
''';

    await send(message, smtpServer);
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }
}
