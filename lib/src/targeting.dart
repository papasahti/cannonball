class TargetCandidate {
  TargetCandidate({
    required this.type,
    required this.key,
    required this.label,
    this.userId,
    this.username,
    this.displayName,
    this.groupId,
    this.groupName,
    this.memberCount,
  });

  final String type;
  final String key;
  final String label;
  final String? userId;
  final String? username;
  final String? displayName;
  final String? groupId;
  final String? groupName;
  final int? memberCount;

  Map<String, Object?> toJson() => {
    'type': type,
    'key': key,
    'label': label,
    'userId': userId,
    'username': username,
    'displayName': displayName,
    'groupId': groupId,
    'groupName': groupName,
    'memberCount': memberCount,
  };
}

List<TargetCandidate> buildTargets({
  required List<Map<String, Object?>> rawUsers,
  required List<Map<String, Object?>> rawGroups,
  required List<String> rawChannels,
}) {
  final byKey = <String, TargetCandidate>{};

  for (final user in rawUsers) {
    final id = (user['id'] as String?)?.trim();
    final username = (user['username'] as String?)?.trim();
    if (id == null || id.isEmpty || username == null || username.isEmpty) {
      continue;
    }
    final displayName = (user['displayName'] as String?)?.trim();
    final normalizedName = username.replaceFirst('@', '');
    final label = displayName?.isNotEmpty == true
        ? '$displayName (@$normalizedName)'
        : '@$normalizedName';
    final nextCandidate = TargetCandidate(
      type: 'user',
      key: id,
      label: label,
      userId: id,
      username: normalizedName,
      displayName: displayName,
    );
    final existing = byKey['user:$id'];
    if (existing == null ||
        ((existing.displayName == null || existing.displayName!.isEmpty) &&
            displayName?.isNotEmpty == true)) {
      byKey['user:$id'] = nextCandidate;
    }
  }

  for (final group in rawGroups) {
    final id = (group['id'] as String?)?.trim();
    final name = (group['name'] as String?)?.trim();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      continue;
    }
    final displayName = (group['displayName'] as String?)?.trim();
    final memberCount = (group['memberCount'] as num?)?.toInt() ?? 0;
    final normalizedName = name.replaceFirst('@', '');
    final label = displayName?.isNotEmpty == true
        ? '$displayName (группа)'
        : normalizedName;
    byKey['group:$id'] = TargetCandidate(
      type: 'group',
      key: id,
      label: label,
      groupId: id,
      groupName: normalizedName,
      displayName: displayName,
      memberCount: memberCount,
    );
  }

  for (final channel in rawChannels) {
    final normalized = channel.trim().replaceFirst('#', '');
    if (normalized.isEmpty) {
      continue;
    }
    byKey['channel:${normalized.toLowerCase()}'] = TargetCandidate(
      type: 'channel',
      key: normalized,
      label: '#$normalized',
    );
  }

  return byKey.values.toList(growable: false);
}
