import 'package:cannonball/src/targeting.dart';
import 'package:test/test.dart';

void main() {
  test('buildTargets normalizes users, groups and channels', () {
    final targets = buildTargets(
      rawUsers: [
        {'id': 'u-1', 'username': '@alice', 'displayName': 'Alice Doe'},
        {'id': 'u-1', 'username': 'alice'},
      ],
      rawGroups: [
        {
          'id': 'g-1',
          'name': 'ops-team',
          'displayName': 'Ops Team',
          'memberCount': 4,
        },
      ],
      rawChannels: ['alerts', '#alerts', 'ops'],
    );

    expect(targets.length, 4);
    expect(
      targets.where((item) => item.type == 'user').single.label,
      'Alice Doe (@alice)',
    );
    expect(
      targets.where((item) => item.type == 'group').single.label,
      'Ops Team (группа)',
    );
    expect(
      targets.where((item) => item.type == 'channel').map((item) => item.key),
      containsAll(['alerts', 'ops']),
    );
  });
}
