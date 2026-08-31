import '../../../shared/models/playing_card.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';

/// トレーナーの難易度。
enum TrainerDifficulty {
  beginner(1, '初級'),
  intermediate(2, '中級'),
  advanced(3, '上級');

  const TrainerDifficulty(this.level, this.label);

  final int level;
  final String label;
}

/// ボードの見た目の分類。シナリオ一覧で偏りを見せるために使う。
enum BoardStyle {
  dry('ドライ', 'ドローがほとんど無い、当たりにくいボード'),
  wet('ウェット', 'ストレートやフラッシュのドローが多いボード'),
  paired('ペアボード', '同じランクが2枚並んだボード'),
  monotone('モノトーン', '3枚が同じスートのボード'),
  dynamic('変化する', 'ターン・リバーで形が大きく変わるボード');

  const BoardStyle(this.label, this.description);

  final String label;
  final String description;
}

/// 選択肢の評価。
///
/// ポーカーの多くの場面には「唯一の正解」が無い。
/// [reasonable] を用意して、悪くない選択と避けたい選択を区別する。
enum TrainerVerdict {
  best('最善', 'この場面で一番おすすめできる選択です'),
  reasonable('悪くない', '最善ではありませんが、成立する選択です'),
  mistake('避けたい', 'この場面では損になりやすい選択です');

  const TrainerVerdict(this.label, this.description);

  final String label;
  final String description;

  bool get isBest => this == TrainerVerdict.best;
  bool get isMistake => this == TrainerVerdict.mistake;
}

/// 初心者向けの用語補足。設問のそばに置き、タップで意味を出す。
class TermNote {
  const TermNote({required this.term, required this.meaning});

  /// 「SPR」「レンジ有利」のような用語。
  final String term;

  /// 1〜2文の説明。専門用語を使わずに書く。
  final String meaning;
}

/// 1 つの選択肢。
class TrainerOption {
  const TrainerOption({
    required this.id,
    required this.label,
    required this.verdict,
    required this.reason,
    required this.ifChanged,
    this.endsHand = false,
  });

  final String id;

  /// 「ポットの35%ベット（2BB）」のような表示名。
  final String label;

  final TrainerVerdict verdict;

  /// なぜこの評価になるのか。選んだ直後にその場で出す本文。
  final String reason;

  /// 何が変われば、この選択の評価が変わるのか。
  ///
  /// 「唯一の正解」を丸暗記させないために、すべての選択肢に持たせる。
  final String ifChanged;

  /// これを選ぶとハンドが終わる（フォールドなど）。
  final bool endsHand;
}

/// 1 ストリート分の設問。
class TrainerSpot {
  const TrainerSpot({
    required this.street,
    this.newCards = const [],
    required this.potBb,
    required this.stackBb,
    this.toCallBb = 0,
    this.actionHistory = const [],
    required this.question,
    required this.options,
    this.hint,
    this.terms = const [],
    this.outcome,
  });

  final Street street;

  /// このストリートで新しく開くボードカード。
  final List<PlayingCard> newCards;

  /// 設問の時点でテーブル中央にあるポット。相手のベットを含む。
  final double potBb;

  /// 設問の時点での有効スタック。
  final double stackBb;

  /// コールするために払う額。0 なら相手のベットは無い。
  final double toCallBb;

  /// このストリートで、設問に至るまでに起きたこと。
  final List<String> actionHistory;

  final String question;
  final List<TrainerOption> options;

  /// 任意で開けるヒント。答えそのものは書かない。
  final String? hint;

  final List<TermNote> terms;

  /// 回答後、次のストリートへ進むまでに起きたこと。
  ///
  /// 最終ストリートでは null。
  final String? outcome;

  /// コールに必要な勝率。相手のベットが無いときは null。
  ///
  /// 計算で確定する値なので、そのまま画面に出してよい。
  double? get requiredEquity =>
      toCallBb <= 0 ? null : toCallBb / (potBb + toCallBb);

  /// スタック・ポット比（SPR）。
  double get spr => potBb <= 0 ? 0 : stackBb / potBb;

  TrainerOption optionById(String id) =>
      options.firstWhere((option) => option.id == id);
}

/// トレーニング用のハンド 1 本。
class TrainerScenario {
  const TrainerScenario({
    required this.id,
    required this.title,
    required this.goal,
    required this.difficulty,
    required this.tableType,
    required this.heroPosition,
    required this.villainPosition,
    required this.villainProfile,
    required this.heroCards,
    required this.startingStackBb,
    required this.boardStyle,
    required this.spots,
    required this.takeaway,
    this.blindsLabel = 'SB 0.5 / BB 1',
  });

  final String id;

  /// 一覧に出す短い題名。
  final String title;

  /// このハンドで身につくこと。一覧とプレイ開始時に出す。
  final String goal;

  final TrainerDifficulty difficulty;
  final TableType tableType;
  final Position heroPosition;
  final Position villainPosition;

  /// 相手のタイプ。前提が変われば最善手も変わるため必ず提示する。
  final String villainProfile;

  final List<PlayingCard> heroCards;
  final double startingStackBb;
  final BoardStyle boardStyle;
  final List<TrainerSpot> spots;

  /// 総括で読ませる、このハンドの学び。
  final String takeaway;

  final String blindsLabel;

  /// ヒーローがポジションを持っているか（フロップ以降で相手より後に行動できるか）。
  bool get heroInPosition =>
      heroPosition.isInPositionAgainst(villainPosition, tableType);

  String get positionLabel => heroInPosition ? 'IP（後に行動）' : 'OOP（先に行動）';

  /// フロップ以降のボード全体。
  List<PlayingCard> get fullBoard => [
    for (final spot in spots) ...spot.newCards,
  ];

  /// [street] までに開いているボード。
  List<PlayingCard> boardUpTo(Street street) {
    final cards = <PlayingCard>[];
    for (final spot in spots) {
      cards.addAll(spot.newCards);
      if (spot.street == street) break;
    }
    return cards;
  }

  int get spotCount => spots.length;
}
