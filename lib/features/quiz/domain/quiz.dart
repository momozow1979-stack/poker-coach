import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';
import 'quiz_category.dart';

/// クイズに提示されるゲーム状況。
class QuizSituation {
  const QuizSituation({
    required this.tableType,
    required this.street,
    required this.heroPosition,
    required this.heroCards,
    this.villainPosition,
    required this.effectiveStackBb,
    required this.potBb,
    this.board = const [],
    this.actionHistory = const [],
    this.blindsLabel = 'SB 0.5 / BB 1',
    this.villainProfile = 'レギュラー（標準的な相手）',
  });

  final TableType tableType;
  final Street street;
  final Position heroPosition;
  final List<PlayingCard> heroCards;
  final Position? villainPosition;
  final double effectiveStackBb;
  final double potBb;
  final List<PlayingCard> board;

  /// 「BTN raise 2.5BB」のような、そこまでのアクション履歴。
  final List<String> actionHistory;
  final String blindsLabel;

  /// 相手のタイプ。
  ///
  /// ポーカーの最適解は相手次第で変わるため、
  /// 「正解」を一つに決める問題では前提として必ず提示する。
  final String villainProfile;
}

/// 回答の選択肢。
class QuizChoice {
  const QuizChoice({required this.id, required this.label, this.actionType});

  final String id;
  final String label;

  /// この選択肢が表すポーカーのアクション種別。
  ///
  /// 「フォールド」「レイズ」のような、実際のアクションを表す選択肢だけに
  /// 設定する。用語問題の選択肢のように、概念や説明文が並ぶ場合は null のまま
  /// でよい（無理にアクション種別へ当てはめない）。null なら選択肢ボタンは
  /// アクションの色・アイコンを表示しない。
  final PokerActionType? actionType;
}

/// 回答後に表示する解説。
///
/// 仕様書 5-4 のクイズ解説プロンプトの出力項目に対応する。
class QuizExplanation {
  const QuizExplanation({
    required this.shortReason,
    required this.gtoView,
    required this.practicalView,
    required this.commonMistake,
    this.relatedRangeSpotId,
  });

  /// 30〜100文字程度の短い理由。
  final String shortReason;
  final String gtoView;
  final String practicalView;
  final String commonMistake;

  /// 関連するレンジ表へのリンク先。
  final String? relatedRangeSpotId;
}

/// 1 問のクイズ。
class Quiz {
  const Quiz({
    required this.id,
    required this.category,
    required this.difficulty,
    this.situation,
    required this.question,
    required this.choices,
    required this.correctChoiceId,
    required this.explanation,
  });

  final String id;
  final QuizCategory category;
  final QuizDifficulty difficulty;

  /// 提示するゲーム状況。
  ///
  /// 用語問題のように、卓の状況を伴わない出題では null になる。
  final QuizSituation? situation;
  final String question;
  final List<QuizChoice> choices;
  final String correctChoiceId;
  final QuizExplanation explanation;

  QuizChoice get correctChoice =>
      choices.firstWhere((choice) => choice.id == correctChoiceId);

  bool isCorrect(String choiceId) => choiceId == correctChoiceId;
}
