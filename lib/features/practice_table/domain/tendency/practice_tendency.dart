import '../../../../shared/models/poker_action.dart';
import '../../../../shared/models/street.dart';
import '../grading/decision_grade.dart';
import '../grading/decision_reason.dart';
import '../grading/hand_reviewer.dart';
import '../practice_hand_record.dart';
import '../practice_opponent.dart';

/// 判断の種類（傾向を見るための分け方）。
enum DecisionKind {
  open('オープン', 'プリフロップで参加するか（レンジ表で採点）'),
  call('コール', '賭けられてコールした'),
  fold('フォールド', '賭けられて降りた'),
  bet('ベット・レイズ', '自分から賭けた・上乗せした'),
  check('チェック', '賭けずに回した');

  const DecisionKind(this.label, this.description);

  final String label;
  final String description;

  static DecisionKind of(ReviewedDecision decision) {
    if (decision.grade.basis == GradingBasis.rangeTable) return open;
    final action = decision.chosen.option.action;
    if (action.isAggressive) return bet;
    return switch (action) {
      PokerActionType.call => call,
      PokerActionType.fold => fold,
      _ => check,
    };
  }
}

/// 1 回の判断の記録（傾向分析に使う分だけ）。
class LoggedDecision {
  const LoggedDecision({
    required this.kind,
    required this.street,
    required this.verdict,
    this.lossBb,
    this.reason,
    this.reasonVerdict,
  });

  final DecisionKind kind;
  final Street street;
  final PracticeVerdict verdict;
  final double? lossBb;
  final DecisionReason? reason;
  final ReasonVerdict? reasonVerdict;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'street': street.id,
    'verdict': verdict.name,
    if (lossBb != null) 'loss_bb': lossBb,
    if (reason != null) 'reason': reason!.name,
    if (reasonVerdict != null) 'reason_verdict': reasonVerdict!.name,
  };

  static LoggedDecision? fromJson(Map<String, dynamic> json) {
    final kind = _byName(DecisionKind.values, json['kind']);
    final verdict = _byName(PracticeVerdict.values, json['verdict']);
    final street = Street.values.where((s) => s.id == json['street']);
    if (kind == null || verdict == null || street.isEmpty) return null;
    return LoggedDecision(
      kind: kind,
      street: street.first,
      verdict: verdict,
      lossBb: (json['loss_bb'] as num?)?.toDouble(),
      reason: DecisionReason.byName(json['reason'] as String?),
      reasonVerdict: _byName(ReasonVerdict.values, json['reason_verdict']),
    );
  }
}

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// 1 ハンド分の判断の記録。
class PracticeHandLog {
  const PracticeHandLog({
    required this.recordId,
    required this.createdAt,
    required this.opponentStyle,
    required this.decisions,
  });

  factory PracticeHandLog.fromReview(
    PracticeHandRecord record,
    PracticeHandReview review,
  ) => PracticeHandLog(
    recordId: record.id,
    createdAt: record.createdAt,
    opponentStyle: record.opponentStyle,
    decisions: [
      for (final decision in review.decisions)
        LoggedDecision(
          kind: DecisionKind.of(decision),
          street: decision.street,
          verdict: decision.chosen.verdict,
          lossBb: decision.chosen.lossBb,
          reason: decision.reasonGrade?.reason,
          reasonVerdict: decision.reasonGrade?.verdict,
        ),
    ],
  );

  final String recordId;
  final DateTime createdAt;
  final PracticeOpponentStyle opponentStyle;
  final List<LoggedDecision> decisions;

  Map<String, dynamic> toJson() => {
    'record_id': recordId,
    'created_at': createdAt.toIso8601String(),
    'opponent_style': opponentStyle.name,
    'decisions': [for (final d in decisions) d.toJson()],
  };

  static PracticeHandLog? fromJson(Map<String, dynamic> json) {
    final id = json['record_id'];
    final created = DateTime.tryParse('${json['created_at']}');
    final rows = json['decisions'];
    if (id is! String || created == null || rows is! List) return null;
    return PracticeHandLog(
      recordId: id,
      createdAt: created,
      opponentStyle: PracticeOpponentStyle.byName(
        json['opponent_style'] as String?,
      ),
      decisions: [
        for (final row in rows)
          if (row is Map<String, dynamic>) ?LoggedDecision.fromJson(row),
      ],
    );
  }
}

/// 判断の種類ごとの数。
class KindStats {
  const KindStats({this.total = 0, this.bad = 0, this.close = 0});

  final int total;
  final int bad;
  final int close;

  double get badRate => total == 0 ? 0 : bad / total;

  KindStats add(PracticeVerdict verdict) => KindStats(
    total: total + 1,
    bad: bad + (verdict == PracticeVerdict.bad ? 1 : 0),
    close: close + (verdict == PracticeVerdict.close ? 1 : 0),
  );
}

/// 多いミス（傾向）。
enum PracticeLeak {
  overCalling(
    DecisionKind.call,
    '受けすぎ',
    '勝率が必要勝率に届かないのにコールしている場面があります。'
        'コールの前に「自分の勝率は、ポットオッズから出る必要勝率以上か」を確かめましょう。',
    PracticeOpponentStyle.valueHeavy,
  ),
  overFolding(
    DecisionKind.fold,
    '降りすぎ',
    '勝率が足りているのに降りている場面があります。'
        '賭けられたら、すぐ降りる前に必要勝率と比べましょう。',
    PracticeOpponentStyle.bluffer,
  ),
  overBetting(
    DecisionKind.bet,
    '打ちすぎ',
    '相手が降りる割合が足りない、または自分より強い手にしか受けてもらえない場面で'
        '賭けています。ブラフは「相手が降りる割合 ≥ 必要な割合」のときだけにしましょう。',
    PracticeOpponentStyle.callingStation,
  ),
  passive(
    DecisionKind.check,
    '消極的',
    '賭ければ得な場面でチェックしています（バリューやブラフの取り逃し）。'
        'チェックの前に「賭けたら相手は何で受け、何で降りるか」を考えましょう。',
    null,
  ),
  openRange(
    DecisionKind.open,
    'オープンの判断',
    'プリフロップで、レンジ表と違う参加・不参加をしています。'
        'ドリルの「プリフロップ連続ドリル」で境目の手を練習しましょう。',
    null,
  );

  const PracticeLeak(this.kind, this.label, this.advice, this.counterStyle);

  final DecisionKind kind;
  final String label;
  final String advice;

  /// この傾向を突く相手の型（無ければ null）。
  final PracticeOpponentStyle? counterStyle;
}

/// 練習の記録から見た、打ち方の傾向。
class PracticeTendency {
  const PracticeTendency({
    required this.handCount,
    required this.byKind,
    required this.reasonStats,
  });

  /// 傾向とみなすのに必要な ×（損をする選択）の回数。
  static const minBadForLeak = 2;

  /// 傾向とみなすのに必要な、その種類の判断の中での × の割合。
  static const minBadRateForLeak = 0.2;

  /// 分析に使う直近のハンド数。
  static const recentHands = 30;

  factory PracticeTendency.analyze(List<PracticeHandLog> logs) {
    final recent = [...logs]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final used = recent.take(recentHands).toList();
    final byKind = {
      for (final kind in DecisionKind.values) kind: const KindStats(),
    };
    final reasons = <DecisionReason, (int, int)>{};
    for (final log in used) {
      for (final decision in log.decisions) {
        byKind[decision.kind] = byKind[decision.kind]!.add(decision.verdict);
        final reason = decision.reason;
        final verdict = decision.reasonVerdict;
        if (reason != null && verdict != null) {
          final (ok, all) = reasons[reason] ?? (0, 0);
          reasons[reason] = (
            ok + (verdict == ReasonVerdict.correct ? 1 : 0),
            all + 1,
          );
        }
      }
    }
    return PracticeTendency(
      handCount: used.length,
      byKind: byKind,
      reasonStats: reasons,
    );
  }

  final int handCount;
  final Map<DecisionKind, KindStats> byKind;

  /// 理由ごとの（合っていた数, 答えた数）。
  final Map<DecisionReason, (int, int)> reasonStats;

  /// 傾向（× が多い順）。
  List<PracticeLeak> get leaks {
    final found = [
      for (final leak in PracticeLeak.values)
        if (byKind[leak.kind]!.bad >= minBadForLeak &&
            byKind[leak.kind]!.badRate >= minBadRateForLeak)
          leak,
    ];
    found.sort((a, b) => byKind[b.kind]!.bad.compareTo(byKind[a.kind]!.bad));
    return found;
  }

  /// 「育つ相手」が使う型: 突ける傾向のうち一番多いもの。無ければふつう。
  PracticeOpponentStyle get recommendedStyle {
    for (final leak in leaks) {
      final style = leak.counterStyle;
      if (style != null) return style;
    }
    return PracticeOpponentStyle.standard;
  }

  /// [recommendedStyle] を選んだ理由になった傾向。
  PracticeLeak? get targetedLeak {
    for (final leak in leaks) {
      if (leak.counterStyle != null) return leak;
    }
    return null;
  }
}
