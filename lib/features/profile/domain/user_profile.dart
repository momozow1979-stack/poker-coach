/// ユーザーの自己申告レベル。
enum PokerLevel {
  beginner('beginner', '初心者'),
  novice('novice', '初級者'),
  intermediate('intermediate', '中級者'),
  advanced('advanced', '上級者');

  const PokerLevel(this.id, this.label);

  final String id;
  final String label;
}

/// Supabase の `profiles` に対応する。
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.pokerLevel,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final PokerLevel pokerLevel;
  final DateTime createdAt;

  int get daysSinceJoined =>
      DateTime.now().difference(createdAt).inDays.clamp(0, 100000);

  UserProfile copyWith({
    String? id,
    String? displayName,
    PokerLevel? pokerLevel,
    DateTime? createdAt,
  }) => UserProfile(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    pokerLevel: pokerLevel ?? this.pokerLevel,
    createdAt: createdAt ?? this.createdAt,
  );
}
