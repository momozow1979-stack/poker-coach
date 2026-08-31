import '../../../../shared/models/playing_card.dart';
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
