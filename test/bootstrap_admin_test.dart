import 'dart:io';

import 'package:cannonball/src/auth_service.dart';
import 'package:cannonball/src/database.dart';
import 'package:test/test.dart';

void main() {
  test('force password sync updates bootstrap admin password', () {
    final tempDir = Directory.systemTemp.createTempSync('cannonball-bootstrap-');
    final databasePath = '${tempDir.path}/cannonball.db';

    try {
      final database = AppDatabase(databasePath: databasePath);
      database.initialize();
      database.ensureBootstrapAdmin(
        username: 'admin',
        displayName: 'Admin',
        email: 'admin@example.com',
        passwordHash: AuthService.hashPassword('oldpass'),
      );

      database.ensureBootstrapAdmin(
        username: 'admin',
        displayName: 'System Administrator',
        email: 'admin@example.com',
        passwordHash: AuthService.hashPassword('adminadmin'),
        forcePasswordSync: true,
      );

      final admin = database.getUserByUsername('admin');
      expect(admin, isNotNull);
      expect(admin!['passwordHash'], AuthService.hashPassword('adminadmin'));
      expect(admin['role'], 'admin');
      expect(admin['isActive'], isTrue);

      database.close();
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('force password sync updates bootstrap user password', () {
    final tempDir = Directory.systemTemp.createTempSync(
      'cannonball-bootstrap-user-',
    );
    final databasePath = '${tempDir.path}/cannonball.db';

    try {
      final database = AppDatabase(databasePath: databasePath);
      database.initialize();
      database.ensureBootstrapUser(
        username: 'operator1',
        displayName: 'Old Operator',
        email: 'old@example.com',
        passwordHash: AuthService.hashPassword('oldpass'),
      );

      database.ensureBootstrapUser(
        username: 'operator1',
        displayName: 'Operator One',
        email: 'operator1@example.com',
        passwordHash: AuthService.hashPassword('operator123'),
        forcePasswordSync: true,
      );

      final user = database.getUserByUsername('operator1');
      expect(user, isNotNull);
      expect(user!['passwordHash'], AuthService.hashPassword('operator123'));
      expect(user['displayName'], 'Operator One');
      expect(user['email'], 'operator1@example.com');
      expect(user['role'], 'user');
      expect(user['isActive'], isTrue);

      database.close();
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
