import '../../../../shared/models/street.dart';
import '../../../hand_review/domain/hand_flow.dart' show Actor;
import '../practice_event.dart';
import 'decision_grade.dart';
import 'decision_grader.dart';
import 'grade_explainer.dart';

/// 振り返りで見せる、ヒーローの 1 回の判断と、その採点。
class ReviewedDecision {
  const ReviewedDecision({
    required this.eventIndex,
    required this.street,
    required this.grade,
    required this.chosen,
    required this.explanation,
  });

  /// その判断（ヒーローの [ActionOccurred]）が、イベント列の何番目か。
  final int eventIndex;
  final Street street;
  final PracticeDecisionGrade grade;
  final PracticeOptionGrade chosen;
  final PracticeGradeExplanation explanation;
}

/// 1 ハンド分の振り返り。
class PracticeHandReview {
  const PracticeHandReview({
    required this.decisions,
    required this.ungradedCount,
  });

  /// ヒーローの判断（時系列順）。
  final List<ReviewedDecision> decisions;

  /// 採点できなかった判断の数（今と違う打ち方の AI と対戦した記録など）。
  final int ungradedCount;

  int countOf(PracticeVerdict verdict) =>
      decisions.where((d) => d.chosen.verdict == verdict).length;

  /// [eventIndex] 番目のイベントがヒーローの判断なら、その採点。
  ReviewedDecision? atEvent(int eventIndex) {
    for (final decision in decisions) {
      if (decision.eventIndex == eventIndex) return decision;
    }
    return null;
  }
}

/// 終わったハンドの、ヒーローの判断をすべて採点する。
///
/// 初心者モードで 1 手ずつ出す判定と、まったく同じ採点
/// （[PracticeDecisionGrader]）を使う。判断ごとに重い計算をするので、
/// 1 つ採点するたびに処理を譲り、Web でも画面が固まらないようにする。
abstract final class PracticeHandReviewer {
  static Future<PracticeHandReview> review(
    List<PracticeEvent> events,
    PracticeDecisionGrader grader,
  ) async {
    final decisions = <ReviewedDecision>[];
    var ungraded = 0;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (event is! ActionOccurred || event.actor != Actor.hero) continue;
      await Future<void>.delayed(Duration.zero);

      final grade = grader.grade(events.sublist(0, i));
      final chosen = grade?.gradeOf(event.action, event.sizeBb);
      if (grade == null || chosen == null) {
        ungraded++;
        continue;
      }
      decisions.add(
        ReviewedDecision(
          eventIndex: i,
          street: event.street,
          grade: grade,
          chosen: chosen,
          explanation: PracticeGradeExplainer.explain(grade, chosen),
        ),
      );
    }
    return PracticeHandReview(decisions: decisions, ungradedCount: ungraded);
  }
}
