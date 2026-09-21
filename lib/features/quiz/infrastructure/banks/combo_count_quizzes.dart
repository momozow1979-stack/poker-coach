import '../../../../shared/models/combo_counter.dart';
import '../../../../shared/models/playing_card.dart';
import '../../../../shared/models/position.dart';
import '../../../../shared/models/starting_hand.dart';
import '../../../../shared/models/street.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// コンボ（組み合わせ）の数え上げ問題。
///
/// 「相手がその手を持つ組み合わせは何通りか」を、見えているカード（自分の手＋場）を
/// 除いて数える。答えは [ComboCounter]（＝計算で確定する数）から生成するので捏造が無く、
/// レンジ表と同じく「常に正しい」。ブロッカー効果を体で覚えるための出題。
abstract final class ComboCountQuizzes {
  static List<Quiz> get all => _quizzes;

  static final List<Quiz> _quizzes = _specs
      .map((s) => s.toQuiz())
      .toList(growable: false);

  static final List<_Spec> _specs = [
    _Spec('cmb001', 'Ac Kd', 'Qs 7d 2h', '99', QuizDifficulty.beginner),
    _Spec('cmb002', 'Ac Kd', 'Qs 7d 2h', 'QQ', QuizDifficulty.beginner),
    _Spec('cmb003', 'Ah Kh', 'Qh 7h 2c', 'AA', QuizDifficulty.intermediate),
    _Spec('cmb004', 'Ah Kh', 'Qh 7h 2c', 'QQ', QuizDifficulty.intermediate),
    _Spec('cmb005', 'Ac Ad', 'As Kd 5c', 'AA', QuizDifficulty.advanced),
    _Spec('cmb006', 'As Ks', 'Ah Kh Qd', 'AA', QuizDifficulty.advanced),
    _Spec('cmb007', 'As Ks', 'Ah Kh Qd', 'KK', QuizDifficulty.advanced),
    _Spec('cmb008', 'Jh Jc', 'Js 9d 4c', 'JJ', QuizDifficulty.advanced),
    _Spec('cmb009', 'Td Tc', '9s 8d 3h', 'TT', QuizDifficulty.advanced),
    _Spec('cmb010', '7h 6h', '8h 5h 2c', '88', QuizDifficulty.intermediate),
    _Spec('cmb011', 'Kh Qh', 'Ah 7c 2d', 'AKo', QuizDifficulty.advanced),
    _Spec('cmb012', 'Kh Qh', 'Ah 7c 2d', 'AKs', QuizDifficulty.advanced),
    _Spec('cmb013', 'Ah Ad', '7c 5d 2s', 'AKo', QuizDifficulty.intermediate),
    _Spec('cmb014', 'Ad Qd', 'Kh Js 4c', 'KQo', QuizDifficulty.advanced),
    _Spec('cmb015', 'Qc Jc', '9d 6s 2h', 'AKo', QuizDifficulty.beginner),
    _Spec('cmb016', 'Qc Jc', '9d 6s 2h', 'AJs', QuizDifficulty.intermediate),
  ];
}

class _Spec {
  _Spec(this.id, this.hero, this.board, this.targetCode, this.difficulty);

  final String id;
  final String hero;
  final String board;
  final String targetCode;
  final QuizDifficulty difficulty;

  Quiz toQuiz() {
    final target = StartingHand.parse(targetCode);
    final dead = <PlayingCard>[
      ...PlayingCard.parseAll(hero.split(' ')),
      ...PlayingCard.parseAll(board.split(' ')),
    ];
    final combos = ComboCounter.combos(target, dead: dead);
    final base = ComboCounter.combos(target);
    final choices = _numericChoices(combos, target.shape);
    final correctIndex = choices.indexOf('$combos通り');

    final blockerNote = combos == base
        ? '見えているカードにこのランクが無いので、基本の$base通りのままです。'
        : combos == 0
        ? 'あなたと場でこのランクをほぼ使い切っているため、相手はこの手を持てません（0通り）。'
        : '見えているカード（あなたの手や場）に同じランクがあるぶん、'
              '基本の$base通りより減って$combos通りになります。';

    return buildQuiz(
      id: id,
      category: QuizCategory.valueBluff,
      difficulty: difficulty,
      street: Street.flop,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: hero,
      board: board,
      question:
          '6MAX・100BB。あなたは $hero、ボードは $board です。'
          '相手が ${target.code}（${target.description}）を持つ組み合わせは何通りですか。',
      choices: choices,
      correctIndex: correctIndex,
      shortReason: '答えは$combos通りです。$blockerNote',
      gtoView:
          'コンボの数え方は決まっています。ペアは「残りの枚数から2枚を選ぶ」、'
          'スーテッドは「両方が残っているスートの数」、オフスートは'
          '「残りハイ×残りロー −スーテッド分」。相手の強い手（バリュー）が何通り'
          'あるかを数えられると、ブラフキャッチやバリューベットの判断が具体的になります。',
      practicalView:
          '自分の手が相手のどの手を減らしているか（ブロッカー効果）を意識すると、'
          'リバーで「相手のバリューを自分が持っていて減らしている→ブラフを打ちやすい」'
          'といった調整ができます。数えるクセをつけると読みが一段深くなります。',
      commonMistake:
          '基本の$base通りで止めてしまい、ブロッカーで実際は$combos通りに'
          '変わっていることを見落とすミスです。見えているカードを必ず引いて数えます。',
    );
  }

  /// [correct] を含む、重複しない数値選択肢を4つ作る。
  static List<String> _numericChoices(int correct, HandShape shape) {
    final pool = switch (shape) {
      HandShape.pair => [0, 1, 3, 6],
      HandShape.suited => [0, 1, 2, 3, 4],
      HandShape.offsuit => [0, 3, 6, 9, 12],
    };
    final values = <int>[correct];
    for (final p in pool) {
      if (values.length >= 4) break;
      if (!values.contains(p)) values.add(p);
    }
    values.sort();
    return [for (final v in values) '$v通り'];
  }
}
