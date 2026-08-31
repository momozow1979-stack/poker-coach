import '../../../../shared/models/playing_card.dart';
import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/trainer_scenario.dart';

/// [buildSpot] に渡す選択肢の下書き。
///
/// ID は設問の中での並び順から機械的に付けるため、
/// シナリオを書く側は文言と評価だけに集中できるようにしている。
class OptionDraft {
  const OptionDraft({
    required this.label,
    required this.verdict,
    required this.reason,
    required this.ifChanged,
    this.endsHand = false,
  });

  final String label;
  final TrainerVerdict verdict;
  final String reason;
  final String ifChanged;
  final bool endsHand;
}

/// この場面で一番おすすめできる選択。
OptionDraft best(
  String label, {
  required String reason,
  required String ifChanged,
  bool endsHand = false,
}) => OptionDraft(
  label: label,
  verdict: TrainerVerdict.best,
  reason: reason,
  ifChanged: ifChanged,
  endsHand: endsHand,
);

/// 最善ではないが成立する選択。
///
/// 「唯一の正解」を丸暗記させないために、必要な場面では必ず用意する。
OptionDraft ok(
  String label, {
  required String reason,
  required String ifChanged,
  bool endsHand = false,
}) => OptionDraft(
  label: label,
  verdict: TrainerVerdict.reasonable,
  reason: reason,
  ifChanged: ifChanged,
  endsHand: endsHand,
);

/// この場面では損になりやすい選択。
OptionDraft bad(
  String label, {
  required String reason,
  required String ifChanged,
  bool endsHand = false,
}) => OptionDraft(
  label: label,
  verdict: TrainerVerdict.mistake,
  reason: reason,
  ifChanged: ifChanged,
  endsHand: endsHand,
);

/// 1 ストリート分の設問を組み立てる。
TrainerSpot buildSpot({
  required Street street,
  String newCards = '',
  required double potBb,
  required double stackBb,
  double toCallBb = 0,
  List<String> history = const [],
  required String question,
  required List<OptionDraft> options,
  String? hint,
  List<TermNote> terms = const [],
  String? outcome,
}) {
  return TrainerSpot(
    street: street,
    newCards: PlayingCard.parseAll(splitCards(newCards)),
    potBb: potBb,
    stackBb: stackBb,
    toCallBb: toCallBb,
    actionHistory: history,
    question: question,
    options: [
      for (var i = 0; i < options.length; i++)
        TrainerOption(
          id: '${street.id}-o$i',
          label: options[i].label,
          verdict: options[i].verdict,
          reason: options[i].reason,
          ifChanged: options[i].ifChanged,
          endsHand: options[i].endsHand,
        ),
    ],
    hint: hint,
    terms: terms,
    outcome: outcome,
  );
}

/// シナリオ 1 本を組み立てる。
TrainerScenario buildScenario({
  required String id,
  required String title,
  required String goal,
  required TrainerDifficulty difficulty,
  required Position hero,
  required Position villain,
  required String heroCards,
  required String villainProfile,
  required BoardStyle boardStyle,
  required List<TrainerSpot> spots,
  required String takeaway,
  TableType tableType = TableType.sixMax,
  double stackBb = 100,
  String blindsLabel = 'SB 0.5 / BB 1',
}) {
  return TrainerScenario(
    id: id,
    title: title,
    goal: goal,
    difficulty: difficulty,
    tableType: tableType,
    heroPosition: hero,
    villainPosition: villain,
    villainProfile: villainProfile,
    heroCards: PlayingCard.parseAll(splitCards(heroCards)),
    startingStackBb: stackBb,
    boardStyle: boardStyle,
    spots: spots,
    takeaway: takeaway,
    blindsLabel: blindsLabel,
  );
}

/// `'A♥ Q♠'` ではなく `'Ah Qs'` 形式の空白区切りを配列にする。
List<String> splitCards(String cards) => cards.isEmpty
    ? const []
    : cards.split(' ').where((card) => card.isNotEmpty).toList();
