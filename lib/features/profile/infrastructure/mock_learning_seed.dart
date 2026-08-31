import 'dart:math';

import '../../../core/utils/date_x.dart';
import '../../quiz/domain/quiz_attempt.dart';
import '../../quiz/infrastructure/quiz_bank.dart';
import '../domain/learning_record.dart';

/// デバッグ用のダミー学習履歴。
///
/// **本番の起動パスからは呼ばれない。**
/// `--dart-define=USE_MOCK_SEED=true` を付けたデバッグビルドで、ローカルの履歴が
/// 空のときにだけ流し込まれる（`LearningSyncController._seedForDebug`）。
/// リリースビルドでは [AppConfig.useMockSeed] が定数 false になるため、
/// このクラスごと tree-shake される。
///
/// 偽の統計を実データとして見せないために、通常の起動では
/// 履歴が空なら空状態を出す。
abstract final class MockLearningSeed {
  /// カテゴリごとの想定正答率。苦手分野が意図どおり検出されるようにする。
  static const Map<String, double> _accuracyByCategory = {
    'preflop': 0.85,
    'flop': 0.72,
    'turn': 0.55,
    'river': 0.5,
    'position': 0.9,
    'bet_sizing': 0.58,
    'pot_odds': 0.8,
    'value_bluff': 0.65,
    'gto': 0.7,
    'exploit': 0.75,
  };

  static LearningRecord build({DateTime? today}) {
    final base = (today ?? DateTime.now()).dateOnly;
    final random = Random(20260829);
    final quizzes = QuizBank.all;
    final attempts = <QuizAttempt>[];
    final activeDays = <DateTime>{};

    // 直近 12 日のうち、9 日ぶん学習した想定。連続 3 日は必ず入る。
    const daysBack = [1, 2, 3, 4, 6, 7, 8, 10, 11];
    for (final offset in daysBack) {
      final day = base.subtract(Duration(days: offset));
      activeDays.add(day);
      for (var i = 0; i < 10; i++) {
        final quiz = quizzes[random.nextInt(quizzes.length)];
        final targetAccuracy = _accuracyByCategory[quiz.category.id] ?? 0.7;
        final isCorrect = random.nextDouble() < targetAccuracy;
        attempts.add(
          QuizAttempt(
            quizId: quiz.id,
            category: quiz.category,
            selectedChoiceId: isCorrect
                ? quiz.correctChoiceId
                : quiz.choices
                      .firstWhere((choice) => choice.id != quiz.correctChoiceId)
                      .id,
            isCorrect: isCorrect,
            answeredAt: day.add(Duration(hours: 20, minutes: i * 2)),
          ),
        );
      }
    }

    return LearningRecord(attempts: attempts, activeDays: activeDays);
  }
}
