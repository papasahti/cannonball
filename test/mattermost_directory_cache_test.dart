import 'dart:io';

import 'package:cannonball/src/database.dart';
import 'package:test/test.dart';

void main() {
  test('mattermost directory cache survives repeated initialization', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cannonball-mm-cache-',
    );
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final databasePath = '${tempDir.path}/cannonball.db';
    final firstDatabase = AppDatabase(databasePath: databasePath);
    firstDatabase.initialize();
    firstDatabase.replaceMattermostDirectoryUsers([
      {
        'id': 'u-1',
        'username': 'i.ivanov',
        'displayName': 'i.ivanov',
        'email': 'i.ivanov@example.com',
      },
      {
        'id': 'u-2',
        'username': 'i.a.ivanov',
        'displayName': 'i.a.ivanov',
        'email': 'i.a.ivanov@example.com',
      },
    ]);
    firstDatabase.replaceMattermostDirectoryGroups([
      {
        'id': 'g-1',
        'name': 'oncall',
        'displayName': 'Oncall',
        'memberCount': 2,
      },
    ]);
    firstDatabase.replaceMattermostDirectoryChannels([
      {
        'id': 'c-1',
        'name': 'alerts',
        'displayName': 'Alerts',
        'type': 'O',
      },
      {
        'id': 'c-2',
        'name': 'incident-private',
        'displayName': 'Incident Private',
        'type': 'P',
      },
    ]);
    firstDatabase.close();

    final secondDatabase = AppDatabase(databasePath: databasePath);
    secondDatabase.initialize();
    addTearDown(secondDatabase.close);

    final userResults = secondDatabase.searchMattermostDirectoryUsers('ivanov');
    final groupResults = secondDatabase.searchMattermostDirectoryGroups('oncall');
    final channelResults =
        secondDatabase.searchMattermostDirectoryChannels('incident');

    expect(userResults, hasLength(2));
    expect(
      userResults.map((row) => row['username']),
      containsAll(['i.ivanov', 'i.a.ivanov']),
    );
    expect(groupResults.single['name'], 'oncall');
    expect(channelResults.single['name'], 'incident-private');
  });
}
