import '../../../../shared/models/combo_counter.dart';
import '../../../../shared/models/position.dart';
import '../../../../shared/models/starting_hand.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../../range_chart/domain/range_action.dart';
import '../../../range_chart/domain/range_entry.dart';
import '../../../range_chart/domain/range_repository.dart';
import '../../../range_chart/domain/range_spot.dart';
import '../../../range_chart/infrastructure/mock_range_repository.dart';
import '../../../range_chart/infrastructure/range_definitions.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// プリフロップのレンジ表そのものから機械生成する出題バンク。
///
/// 正解は「アプリが同梱するレンジ表（[RangeDefinitions]）が示すアクション」を
/// そのまま採用する。したがって答えは捏造ではなく、レンジ表と常に一致する。
/// 解説にはポジション・後ろの人数・そのレンジが開く手の種類数（数え上げ）・
/// そのハンドのコンボ数（[ComboCounter]）といった、
/// 計算で確定する事実だけを使う（AGENTS.md ルール1）。
///
/// 「境界のハンド（mixed = どちらとも言える手）」を中心に、明確な value / fold の
/// アンカーを少し足して、レンジの端を体で覚えられるようにしている。
abstract final class PreflopRangeQuizzes {
  static List<Quiz> get all => _quizzes;

  static const RangeRepository _repo = MockRangeRepository();
  static const _table = TableType.sixMax;

  static final List<Quiz> _quizzes = _generate();

  /// mixed（境界）は主アクションに畳む。
  static RangeAction _effective(RangeEntry e) => e.action == RangeAction.mixed
      ? (e.blend?.primary ?? RangeAction.fold)
      : e.action;

  /// 6MAX オープンで後ろに残る人数。
  static int _seatsBehind(Position hero) {
    final order = Position.orderFor(_table);
    return order.length - 1 - order.indexOf(hero);
  }

  /// そのポジション・シチュエーションで [action] を取る手の種類数（169分類のうち）。
  static int _rangeSize(RangeChart chart, RangeAction action) => StartingHand
      .all
      .where((h) => _effective(chart.entryFor(h)) == action)
      .length;

  /// 具体的な 2 枚（スート）を決める。スーテッドは同スート、オフスートは別スート。
  static String _cards(StartingHand h) => switch (h.shape) {
    HandShape.pair => '${h.high.symbol}h ${h.high.symbol}d',
    HandShape.suited => '${h.high.symbol}h ${h.low.symbol}h',
    HandShape.offsuit => '${h.high.symbol}h ${h.low.symbol}d',
  };

  static List<Quiz> _generate() {
    final quizzes = <Quiz>[];
    for (final def in RangeDefinitions.all) {
      if (def.spot.tableType != _table) continue;
      final chart = _repo.chartById(def.spot.id);
      if (chart == null) continue;
      switch (def.spot.situation) {
        case RangeSituation.openRaise:
          quizzes.addAll(_openQuizzes(def.spot, chart));
        case RangeSituation.vsOpen:
          quizzes.addAll(_vsOpenQuizzes(def.spot, chart));
        default:
          break;
      }
    }
    return List.unmodifiable(quizzes);
  }

  /// 出題する手を選ぶ。境界（mixed）を全部＋明確な value/fold のアンカー少々。
  static List<StartingHand> _pick(RangeChart chart, List<String> anchors) {
    final seen = <String>{};
    final picks = <StartingHand>[];
    void add(StartingHand h) {
      if (seen.add(h.code)) picks.add(h);
    }

    // 境界のハンド（そのスポットで最も学びが大きい）。
    for (final h in StartingHand.all) {
      if (chart.entryFor(h).action == RangeAction.mixed) add(h);
    }
    // アンカー（明確な例）。
    for (final code in anchors) {
      add(StartingHand.parse(code));
    }
    return picks;
  }

  static List<Quiz> _openQuizzes(RangeSpot spot, RangeChart chart) {
    final hero = spot.heroPosition;
    final behind = _seatsBehind(hero);
    final openSize = _rangeSize(chart, RangeAction.raise);
    final hands = _pick(chart, const [
      'AA',
      'AKs',
      'KQs',
      'A5s',
      'KJo',
      '72o',
      'J4o',
      'T6o',
    ]);

    return [
      for (final h in hands)
        () {
          final action = _effective(chart.entryFor(h));
          final raises = action == RangeAction.raise;
          final borderline = chart.entryFor(h).action == RangeAction.mixed;
          final combos = ComboCounter.combos(h);
          return buildQuiz(
            id: 'pfr-o-${hero.label.toLowerCase()}-${h.code}',
            category: QuizCategory.preflop,
            difficulty: borderline
                ? QuizDifficulty.intermediate
                : QuizDifficulty.beginner,
            street: Street.preflop,
            hero: hero,
            heroCards: _cards(h),
            tableType: _table,
            villainProfile: VillainProfile.unknown,
            history: const ['前が全員フォールドし、あなたに最初のアクションが回ってきた'],
            question:
                '6MAX・100BB。${hero.label} のあなたに最初のアクションが回ってきました。'
                '${h.code}（${h.description}）でどうしますか。',
            choices: const ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
            correctIndex: raises ? 2 : 0,
            shortReason: raises
                ? '${h.code} はこのアプリが薦める ${hero.label} のオープンレンジに入ります。'
                      '開くなら 2.5BB 前後のレイズで、リンプ（ただコール）はしません。'
                : '${h.code}（$combos通り）は ${hero.label} のオープンレンジ外です。'
                      '後ろに $behind 人残っていて支配されやすく、フォールドが基本です。',
            gtoView: raises
                ? '${hero.label} が開くのは169種類の手のうちおよそ $openSize 種類。'
                      '後ろの人数が多い席ほど狭く、少ない席ほど広がります。'
                      '${h.code} はその範囲の中に入っています。'
                : '${hero.label} が開くのは169種類のうちおよそ $openSize 種類まで。'
                      '${h.code} はそこに入らないため降ります。'
                      '同じ手でも、後ろの人数が減る席（CO や BTN）なら開けるようになります。',
            practicalView: raises
                ? 'まず「レイズ or フォールド」で考え、リンプで入らないのが基本です。'
                      'リンプは主導権を渡し、複数人を呼び込みやすくなります。'
                : '「この手は後ろのどの席なら開けるか」をセットで覚えると、'
                      'レンジ表が頭に入りやすくなります。',
            commonMistake: raises
                ? 'レイズせずリンプで参加するのは、フロップ以降の主導権を失う典型的な損です。'
                : '「エースだから」「絵札だから」で無条件に開くのは負け筋です。'
                      'キッカーの強さと後ろの人数で判断します。',
            relatedRangeSpotId: spot.id,
          );
        }(),
    ];
  }

  static List<Quiz> _vsOpenQuizzes(RangeSpot spot, RangeChart chart) {
    final hero = spot.heroPosition;
    final villain = spot.villainPosition;
    final villainLabel = villain?.label ?? '相手';
    final callSize = _rangeSize(chart, RangeAction.call);
    final threeBetSize = _rangeSize(chart, RangeAction.threeBet);
    final hands = _pick(chart, const ['AA', 'AKo', 'QJs', 'K9o', '72o', 'J6o']);

    return [
      for (final h in hands)
        () {
          final action = _effective(chart.entryFor(h));
          final borderline = chart.entryFor(h).action == RangeAction.mixed;
          final combos = ComboCounter.combos(h);
          final correctIndex = switch (action) {
            RangeAction.threeBet => 2,
            RangeAction.call => 1,
            _ => 0,
          };
          return buildQuiz(
            id: 'pfr-v-${hero.label.toLowerCase()}-${h.code}',
            category: QuizCategory.preflop,
            difficulty: borderline
                ? QuizDifficulty.advanced
                : QuizDifficulty.intermediate,
            street: Street.preflop,
            hero: hero,
            villain: villain,
            heroCards: _cards(h),
            tableType: _table,
            history: ['$villainLabel が 2.5BB でオープンし、あなたに回ってきた'],
            question:
                '6MAX・100BB。$villainLabel が 2.5BB オープン。'
                '${hero.label} のあなたは ${h.code}（${h.description}）でどうしますか。',
            choices: const ['Fold', 'Call', '3Bet', 'All-in'],
            correctIndex: correctIndex,
            shortReason: switch (action) {
              RangeAction.threeBet =>
                '${h.code} は $villainLabel のオープンに対して 3ベットで対応する手です。',
              RangeAction.call =>
                '${h.code} は 3ベットするには惜しく、降りるにはもったいない手。'
                    'コールで受けて様子を見ます。',
              _ =>
                '${h.code}（$combos通り）は $villainLabel のオープンに対して'
                    '受けるには弱く、フォールドが基本です。',
            },
            gtoView: switch (action) {
              RangeAction.threeBet =>
                '3ベットはバリュー（強い手）とブラフ（ブロッカー持ちの手）で構成します。'
                    '${hero.label} の 3ベットは169種のうちおよそ $threeBetSize 種類。'
                    '${h.code} はその一角として 3ベットに回します。',
              RangeAction.call =>
                '${hero.label} のコールレンジは169種のうちおよそ $callSize 種類。'
                    'コールは「強すぎず弱すぎず」の帯で、${h.code} はここに入ります。',
              _ =>
                'コールにも 3ベットにも届かない手は無理に守りません。'
                    'ブラインドが絡む席ほど守備範囲は変わります。',
            },
            practicalView: switch (action) {
              RangeAction.threeBet =>
                '相手が降りすぎるならブラフ 3ベットを増やし、'
                    '降りない相手にはバリュー中心に絞ります。',
              RangeAction.call =>
                '自分がインポジションか、後ろにまだ人が残っていないかで、'
                    'コールかフォールドかが変わります。',
              _ => '位置（IP/OOP）と相手の広さ次第で、同じ手でもコールに格上げできることがあります。',
            },
            commonMistake: switch (action) {
              RangeAction.threeBet => '強い手をコールで隠しすぎると、3ベットがブラフに偏って見抜かれます。',
              RangeAction.call => 'なんでも 3ベットにすると、コールに残るのが強い手ばかりになり読まれます。',
              _ => '「毎回反応しないと弱い」と弱い手で受けると、じわじわ損をします。',
            },
            relatedRangeSpotId: spot.id,
          );
        }(),
    ];
  }
}
