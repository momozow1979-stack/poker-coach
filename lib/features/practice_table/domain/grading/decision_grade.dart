import '../../../../shared/models/poker_action.dart';
import '../../../../shared/models/street.dart';
import '../../../range_chart/domain/range_action.dart';

/// 1 つの選択肢への判定。
///
/// 「唯一の正解」を断定しすぎないよう（AGENTS.md ルール5）、僅差の場面は
/// ○/× ではなく △ にする。
enum PracticeVerdict {
  good('○'),
  close('△'),
  bad('×');

  const PracticeVerdict(this.symbol);

  final String symbol;
}

/// 何を根拠に採点したか。
enum GradingBasis {
  /// プリフロップで最初にオープンするかどうか。アプリ同梱のレンジ表
  /// （学習用の目安）の答えをそのまま使う。
  rangeTable,

  /// このAI（決まった打ち方の相手）に対して、各選択肢の損得を計算した。
  versusOpponent,
}

/// 採点の対象になる、画面で押せる 1 つのボタン。
class PracticeOption {
  const PracticeOption(this.action, {this.sizeBb});

  final PokerActionType action;

  /// ベット / レイズで揃える額（BB）。それ以外とオールインは null。
  final double? sizeBb;

  bool matches(PokerActionType other, double? otherSize) {
    if (action != other) return false;
    if (sizeBb == null || otherSize == null) return sizeBb == otherSize;
    return (sizeBb! - otherSize).abs() < 1e-6;
  }

  String get label => sizeBb == null
      ? action.description
      : '${action.description} ${formatBb(sizeBb!)}BB';
}

/// 0.25 刻みの BB を、余計な小数を付けずに表示する。
String formatBb(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// 1 つの選択肢の採点結果と、その根拠になった数値。
class PracticeOptionGrade {
  const PracticeOptionGrade({
    required this.option,
    required this.verdict,
    this.evBb,
    this.lossBb,
    this.heroAddBb,
    this.foldRate,
    this.raiseRate,
    this.equityWhenCalled,
    this.breakEvenFoldRate,
    this.impliedOddsSoftened = false,
  });

  final PracticeOption option;
  final PracticeVerdict verdict;

  /// ここから先の損得の見込み（BB、降りた場合を 0 とする）。
  /// [GradingBasis.versusOpponent] のときだけ。
  final double? evBb;

  /// 一番良い選択肢との差（BB、0 以上）。
  final double? lossBb;

  /// この選択でヒーローが新たに出す額（BB）。
  final double? heroAddBb;

  /// 賭けた場合に、相手の候補のうち降りる割合（0.0〜1.0）。
  final double? foldRate;

  /// 賭けた場合に、相手がレイズし返してくる割合。
  final double? raiseRate;

  /// 賭けてコールされたときの、コールしてくる手に対する勝率。
  final double? equityWhenCalled;

  /// ブラフ（降りてもらうだけ）で元が取れるのに必要な、相手の降りる割合。
  /// `賭ける額 ÷ (今のポット + 賭ける額)`。
  final double? breakEvenFoldRate;

  /// ドローがあるため、計算上は × でもインプライドオッズ次第として △ に
  /// したか。
  final bool impliedOddsSoftened;
}

/// ヒーローの 1 回の判断に対する採点。
class PracticeDecisionGrade {
  const PracticeDecisionGrade({
    required this.basis,
    required this.street,
    required this.potBb,
    required this.toCallBb,
    required this.options,
    this.heroHandCode,
    this.rangeAction,
    this.rangeComboCount,
    this.heroEquity,
    this.equityIsExact = true,
    this.equityMargin = 0,
    this.equitySamplesPerCombo = 0,
    this.requiredEquity,
    this.heroDraws = const [],
  });

  final GradingBasis basis;
  final Street street;

  /// 判断する直前のポット（BB）。
  final double potBb;

  /// コールに必要な額。賭けに直面していなければ 0。
  final double toCallBb;

  final List<PracticeOptionGrade> options;

  /// [GradingBasis.rangeTable] のとき: ヒーローの手札（`AKs` など）と、
  /// レンジ表での扱い。
  final String? heroHandCode;
  final RangeAction? rangeAction;

  /// [GradingBasis.versusOpponent] のとき: 相手がここまでの行動を取る手札が
  /// 何通りあるか。
  final int? rangeComboCount;

  /// その手札すべて（同じ確率）に対するヒーローの勝率。
  final double? heroEquity;

  /// 勝率が数え上げた厳密な値か（プリフロップだけは推定）。
  final bool equityIsExact;

  /// 推定のときの誤差の目安（0.0〜1.0）。
  final double equityMargin;

  /// 推定のとき、相手の手札 1 通りあたりに試したボードの数。
  final int equitySamplesPerCombo;

  /// 賭けに直面しているときの必要勝率（ポットオッズ）。
  final double? requiredEquity;

  /// ヒーローのドロー（フラッシュドローなど）。
  final List<String> heroDraws;

  bool get facingBet => toCallBb > 0;

  PracticeOptionGrade? gradeOf(PokerActionType action, double? sizeBb) {
    for (final grade in options) {
      if (grade.option.matches(action, sizeBb)) return grade;
    }
    return null;
  }

  /// ○ の選択肢（[GradingBasis.versusOpponent] では損得の良い順）。
  List<PracticeOptionGrade> get goodOptions {
    final good = [
      for (final grade in options)
        if (grade.verdict == PracticeVerdict.good) grade,
    ];
    if (basis == GradingBasis.versusOpponent) {
      good.sort((a, b) => (b.evBb ?? 0).compareTo(a.evBb ?? 0));
    }
    return good;
  }
}
