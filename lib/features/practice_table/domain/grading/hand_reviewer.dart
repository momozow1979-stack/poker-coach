import '../../../../shared/models/street.dart';
import '../../../hand_review/domain/hand_flow.dart' show Actor;
import '../practice_event.dart';
import 'decision_grade.dart';
import 'decision_grader.dart';
import 'decision_reason.dart';
import 'grade_explainer.dart';

/// 振り返りで見せる、ヒーローの 1 回の判断と、その採点。
class ReviewedDecision {
  const ReviewedDecision({
    required this.eventIndex,
    required this.street,
    required this.grade,
    required this.chosen,
    required this.explanation,
    this.reasonGrade,
  });

  /// その判断（ヒーローの [ActionOccurred]）が、イベント列の何番目か。
  final int eventIndex;
  final Street street;
  final PracticeDecisionGrade grade;
  final PracticeOptionGrade chosen;
  final PracticeGradeExplanation explanation;

  /// 選んだ理由とその判定。理由を聞かなかった判断では null。
  final ReasonGrade? reasonGrade;
}

/// 1 ハンドの総合評価。
///
/// 1 回の判断につき、アクション 2 点（○2・△1・×0）と、理由を答えた
/// 場合は理由 1 点（合っていれば 1、違う・なんとなくは 0）。
/// 取れた点 ÷ 満点 を 100 点満点にする。
class PracticeHandScore {
  const PracticeHandScore({
    required this.actionPoints,
    required this.actionMax,
    required this.reasonCorrect,
    required this.reasonAnswered,
  });

  final int actionPoints;
  final int actionMax;

  /// 理由が合っていた数 / 理由を答えた数。
  final int reasonCorrect;
  final int reasonAnswered;

  int get maxPoints => actionMax + reasonAnswered;

  /// 0〜100。採点できる判断が無ければ null。
  int? get total => maxPoints == 0
      ? null
      : ((actionPoints + reasonCorrect) * 100 / maxPoints).round();

  String get label {
    final value = total;
    if (value == null) return '採点できる判断がありませんでした';
    if (value >= 90) return 'すばらしい！';
    if (value >= 70) return 'よくできました';
    if (value >= 50) return 'もう一歩';
    return '復習しよう';
  }
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

  PracticeHandScore get score {
    var actionPoints = 0;
    var reasonCorrect = 0;
    var reasonAnswered = 0;
    for (final decision in decisions) {
      actionPoints += switch (decision.chosen.verdict) {
        PracticeVerdict.good => 2,
        PracticeVerdict.close => 1,
        PracticeVerdict.bad => 0,
      };
      final reason = decision.reasonGrade;
      if (reason != null) {
        reasonAnswered++;
        if (reason.verdict == ReasonVerdict.correct) reasonCorrect++;
      }
    }
    return PracticeHandScore(
      actionPoints: actionPoints,
      actionMax: decisions.length * 2,
      reasonCorrect: reasonCorrect,
      reasonAnswered: reasonAnswered,
    );
  }

  /// 一番損をした判断（△か×のうち、損が一番大きいもの）。無ければ null。
  /// レンジ表で採点した判断は損の額が無いので、×なら損の額より優先する。
  ReviewedDecision? get biggestMistake {
    ReviewedDecision? worst;
    double rank(ReviewedDecision d) {
      if (d.chosen.verdict == PracticeVerdict.good) return -1;
      final loss = d.chosen.lossBb;
      if (loss != null) return loss;
      return d.chosen.verdict == PracticeVerdict.bad ? 1000 : 0;
    }

    for (final decision in decisions) {
      if (rank(decision) < 0) continue;
      if (worst == null || rank(decision) > rank(worst)) worst = decision;
    }
    return worst;
  }

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
    PracticeDecisionGrader grader, {
    Map<int, DecisionReason> reasons = const {},
  }) async {
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
          reasonGrade: reasons[i] == null
              ? null
              : ReasonGrader.grade(grade, chosen, reasons[i]!),
        ),
      );
    }
    return PracticeHandReview(decisions: decisions, ungradedCount: ungraded);
  }
}
