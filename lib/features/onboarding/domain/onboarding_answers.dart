import '../../profile/domain/user_profile.dart';
import '../../quiz/domain/quiz_category.dart';

/// 初回オンボーディングの回答。
///
/// 端末ローカルにのみ保存する（Supabase への同期は今回は行わない）。
class OnboardingAnswers {
  const OnboardingAnswers({
    required this.pokerLevel,
    required this.focusCategories,
    required this.completedAt,
  });

  /// 自己申告の熟練度。プロフィールの初期値になる。
  final PokerLevel pokerLevel;

  /// 学びたい分野。苦手分野がまだ検出されていない間の出題の重み付けに使う。
  final List<QuizCategory> focusCategories;

  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
    'poker_level': pokerLevel.id,
    'focus_categories': [for (final c in focusCategories) c.id],
    'completed_at': completedAt.toUtc().toIso8601String(),
  };

  /// 壊れた保存データからは null を返す（オンボーディングをやり直させる）。
  static OnboardingAnswers? fromJson(Map<String, dynamic> json) {
    final levelId = json['poker_level'];
    final completedAtRaw = json['completed_at'];
    if (levelId is! String || completedAtRaw is! String) return null;

    final completedAt = DateTime.tryParse(completedAtRaw);
    if (completedAt == null) return null;

    PokerLevel? level;
    for (final candidate in PokerLevel.values) {
      if (candidate.id == levelId) {
        level = candidate;
        break;
      }
    }
    if (level == null) return null;

    final rawCategories = json['focus_categories'];
    final categories = <QuizCategory>[];
    if (rawCategories is List) {
      for (final id in rawCategories) {
        if (id is! String) continue;
        try {
          categories.add(QuizCategory.fromId(id));
        } on StateError {
          // 未知のカテゴリIDは無視する（将来カテゴリが減った場合の保険）。
        }
      }
    }

    return OnboardingAnswers(
      pokerLevel: level,
      focusCategories: categories,
      completedAt: completedAt.toLocal(),
    );
  }
}
