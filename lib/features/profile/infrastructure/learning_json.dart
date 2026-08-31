import '../../hand_review/domain/hand_review_input.dart';
import '../../hand_review/domain/hand_review_record.dart';
import '../../hand_review/domain/hand_review_result.dart';
import '../../quiz/domain/quiz_attempt.dart';
import '../../quiz/domain/quiz_category.dart';

/// ローカル保存と Supabase 送信で共有する JSON 変換。
///
/// 日時は UTC の ISO8601 で持ち、読み戻すときにローカル時刻へ直す。
/// 連続学習日数やカレンダー集計はローカルの日付で数えるため。
abstract final class LearningJson {
  static Map<String, dynamic> attemptToJson(QuizAttempt attempt) => {
    'quiz_key': attempt.quizId,
    'category': attempt.category.id,
    'selected_choice_id': attempt.selectedChoiceId,
    'is_correct': attempt.isCorrect,
    'answered_at': attempt.answeredAt.toUtc().toIso8601String(),
  };

  /// 壊れた行は null を返す。1 行の破損で履歴全体が読めなくなるのを避ける。
  static QuizAttempt? attemptFromJson(Map<String, dynamic> json) {
    final quizId = json['quiz_key'] as String?;
    final answeredAt = _parseDate(json['answered_at']);
    if (quizId == null || quizId.isEmpty || answeredAt == null) return null;

    return QuizAttempt(
      quizId: quizId,
      category: _category(json['category']),
      selectedChoiceId: json['selected_choice_id'] as String? ?? '',
      isCorrect: json['is_correct'] == true,
      answeredAt: answeredAt,
    );
  }

  static Map<String, dynamic> reviewToJson(HandReviewRecord review) => {
    'id': review.id,
    'created_at': review.createdAt.toUtc().toIso8601String(),
    'input': review.input.toJson(),
    'result': review.result.toJson(),
  };

  static HandReviewRecord? reviewFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final createdAt = _parseDate(json['created_at']);
    final input = json['input'];
    final result = json['result'];
    if (id == null || createdAt == null) return null;
    if (input is! Map<String, dynamic> || result is! Map<String, dynamic>) {
      return null;
    }

    return HandReviewRecord(
      id: id,
      input: HandReviewInput.fromJson(input),
      result: HandReviewResult.fromJson(result),
      createdAt: createdAt,
    );
  }

  static QuizCategory _category(Object? id) {
    if (id is! String) return QuizCategory.preflop;
    try {
      return QuizCategory.fromId(id);
    } on StateError {
      return QuizCategory.preflop;
    }
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
