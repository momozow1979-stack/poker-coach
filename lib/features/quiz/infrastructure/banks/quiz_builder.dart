import '../../../../shared/models/playing_card.dart';
import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';

/// 相手タイプの定型文。
///
/// ポーカーの最適解はスタック深さ・相手のタイプ・レーキで変わるため、
/// 「正解が一つに決まる」問題にするには相手の前提を固定する必要がある。
/// 問題文ごとに書き分けるとブレるので、ここに集約している。
abstract final class VillainProfile {
  /// 極端な偏りのない相手。GTO 寄りの基礎を問う問題で使う。
  static const reg = 'レギュラー（標準的で、極端な偏りはない）';

  /// 初対面。母集団の平均として扱う。
  static const unknown = '情報なし（初対面。母集団の平均として扱う）';

  /// 参加は絞るが、参加したら攻めてくる。
  static const tightAggressive = 'タイト・アグレッシブ（参加を絞り、参加したら攻める）';

  /// 参加が少なく、強い手以外は降りる。
  static const nit = 'タイト・パッシブ（参加が少なく、強い手以外は降りる）';

  /// コールが多く、めったに降りない。
  static const station = 'コーリングステーション（コールが多く、めったに降りない）';

  /// 広く参加するが、自分からはあまり打たない。
  static const loosePassive = 'ルース・パッシブ（広く参加するが、自分からは打たない）';

  /// 広く参加し、ブラフも多い。
  static const looseAggressive = 'ルース・アグレッシブ（広く参加し、ブラフも多い）';

  /// 極端に攻撃的で、ブラフが非常に多い。
  static const maniac = 'マニアック（極端に攻撃的で、ブラフが非常に多い）';

  /// 降りすぎる。ベットへの抵抗が弱い。
  static const overFolder = 'フォールドしすぎる相手（ベットへの抵抗が弱い）';
}

/// 1 問を組み立てるヘルパー。
///
/// 解説は「短い理由 / GTO視点 / 実戦視点 / よくあるミス」の 4 点セットで持ち、
/// ソルバーの厳密な頻度や EV 値は書かない（仕様書 14-3 / docs/ai-prompts.md）。
Quiz buildQuiz({
  required String id,
  required QuizCategory category,
  required QuizDifficulty difficulty,
  required Street street,
  required Position hero,
  Position? villain,
  required String heroCards,
  String board = '',
  double stackBb = 100,
  double potBb = 1.5,
  TableType tableType = TableType.sixMax,
  String villainProfile = VillainProfile.reg,
  List<String> history = const [],
  required String question,
  required List<String> choices,
  required int correctIndex,
  required String shortReason,
  required String gtoView,
  required String practicalView,
  required String commonMistake,
  String? relatedRangeSpotId,
}) {
  return Quiz(
    id: id,
    category: category,
    difficulty: difficulty,
    situation: QuizSituation(
      tableType: tableType,
      street: street,
      heroPosition: hero,
      villainPosition: villain,
      heroCards: PlayingCard.parseAll(_splitCards(heroCards)),
      board: PlayingCard.parseAll(_splitCards(board)),
      effectiveStackBb: stackBb,
      potBb: potBb,
      actionHistory: history,
      villainProfile: villainProfile,
    ),
    question: question,
    choices: [
      for (var i = 0; i < choices.length; i++)
        QuizChoice(id: '$id-c$i', label: choices[i]),
    ],
    correctChoiceId: '$id-c$correctIndex',
    explanation: QuizExplanation(
      shortReason: shortReason,
      gtoView: gtoView,
      practicalView: practicalView,
      commonMistake: commonMistake,
      relatedRangeSpotId: relatedRangeSpotId,
    ),
  );
}

List<String> _splitCards(String cards) => cards.isEmpty
    ? const []
    : cards.split(' ').where((card) => card.isNotEmpty).toList();
