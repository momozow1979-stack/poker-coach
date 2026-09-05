import '../../../../shared/models/playing_card.dart';
import '../../../../shared/models/poker_action.dart';
import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../../../shared/models/villain_style.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';

/// 相手タイプの定型文。
///
/// 実体は [VillainStyles]。既存の問題バンクが `VillainProfile.reg` の形で
/// 参照しているため、名前だけをここに残して委譲している。
abstract final class VillainProfile {
  static const reg = VillainStyles.reg;
  static const unknown = VillainStyles.unknown;
  static const tightAggressive = VillainStyles.tightAggressive;
  static const nit = VillainStyles.nit;
  static const station = VillainStyles.station;
  static const loosePassive = VillainStyles.loosePassive;
  static const looseAggressive = VillainStyles.looseAggressive;
  static const maniac = VillainStyles.maniac;
  static const overFolder = VillainStyles.overFolder;
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

  /// true にすると、各選択肢のラベルから [inferActionType] でアクション種別を
  /// 推測して付与する。全カテゴリへの一括付与はまだ内容確認が済んでいないため、
  /// 選択肢が一貫して「Fold」「Raise 2.5BB」のような定型のアクション名で
  /// 書かれていることを確認済みのカテゴリ（プリフロップ・フロップ）だけで
  /// 有効にしている。
  bool tagActionTypes = false,
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
        QuizChoice(
          id: '$id-c$i',
          label: choices[i],
          actionType: tagActionTypes ? inferActionType(choices[i]) : null,
        ),
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

/// 選択肢のラベルから対応するアクション種別を推測する。
///
/// 出題バンクの選択肢は「Fold」「Call」「Raise 2.5BB」「3Bet 8BB」のような、
/// 定型のアクション名（英語表記）+ 任意のサイズや注釈、という書式でほぼ
/// 統一されている。既知のアクション語を含む場合だけ種別を返し、
/// 「相手のベットを待つ」のような概念的な選択肢には何も返さない
/// （無理にアクション種別へ当てはめない）。
///
/// 複合語（`Check-Raise`・`Re-raise`・`3Bet`/`4Bet`）は、それ単体の語
/// （`Check`・`Raise`・`Bet`）にも一致してしまうため、判定の前段で拾う。
PokerActionType? inferActionType(String label) {
  if (label.contains('Check-Raise') || label.contains('Re-raise')) {
    return PokerActionType.raise;
  }
  if (label.contains('3Bet') || label.contains('4Bet')) {
    return PokerActionType.raise;
  }
  if (label.contains('All-in')) return PokerActionType.allIn;
  if (label.contains('Fold')) return PokerActionType.fold;
  if (label.contains('Call')) return PokerActionType.call;
  if (label.contains('Check')) return PokerActionType.check;
  if (label.contains('Raise')) return PokerActionType.raise;
  if (label.contains('Bet')) return PokerActionType.bet;
  return null;
}

/// 卓の状況を伴わない、定義を問う問題を組み立てる。
///
/// 用語問題のほか、既存カテゴリの中にある「◯◯とはどういう意味か」型の設問にも使う。
/// 板と無関係な設問に卓の図を出すと、初心者は
/// 「この board を読み取らないと答えられないのか」と誤解する。
Quiz buildDefinitionQuiz({
  required String id,
  required QuizCategory category,
  required QuizDifficulty difficulty,
  required String question,
  required List<String> choices,
  required int correctIndex,
  required String shortReason,
  required String gtoView,
  required String practicalView,
  required String commonMistake,
}) {
  return Quiz(
    id: id,
    category: category,
    difficulty: difficulty,
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
    ),
  );
}

/// 用語問題を組み立てる。
///
/// 用語の暗記で終わらせないよう、「なぜその概念が重要か」を必ず書く。
Quiz buildTermQuiz({
  required String id,
  required QuizDifficulty difficulty,
  required String question,
  required List<String> choices,
  required int correctIndex,
  required String meaning,
  required String whyItMatters,
  required String inPractice,
  required String misconception,
}) => buildDefinitionQuiz(
  id: id,
  category: QuizCategory.terminology,
  difficulty: difficulty,
  question: question,
  choices: choices,
  correctIndex: correctIndex,
  shortReason: meaning,
  gtoView: whyItMatters,
  practicalView: inPractice,
  commonMistake: misconception,
);
