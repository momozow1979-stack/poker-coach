import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import 'practice_event.dart';

/// 保存済みの練習ハンド 1 件。イベント列をそのまま持つので、
/// リプレイ画面はこれをそのまま [PracticeHandState.replay] に渡せる。
class PracticeHandRecord {
  const PracticeHandRecord({
    required this.id,
    required this.createdAt,
    required this.events,
    required this.endedByFold,
    required this.winner,
    required this.finalPotBb,
  });

  final String id;
  final DateTime createdAt;
  final List<PracticeEvent> events;
  final bool endedByFold;

  /// 勝者。分けなら null。
  final Actor? winner;
  final double finalPotBb;

  /// 履歴一覧に出す短い見出し。
  String get title {
    final dealt = events.first as HandDealt;
    final hero = dealt.heroCards.map((c) => c.display).join(' ');
    final outcome = winner == null
        ? '分け'
        : (winner == Actor.hero ? '勝ち' : '負け');
    return '$hero・$outcome';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'ended_by_fold': endedByFold,
    'winner': winner?.name,
    'final_pot_bb': finalPotBb,
    'events': events.map(_eventToJson).toList(),
  };

  factory PracticeHandRecord.fromJson(Map<String, dynamic> json) {
    return PracticeHandRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      endedByFold: json['ended_by_fold'] as bool,
      winner: _actorFromName(json['winner'] as String?),
      finalPotBb: (json['final_pot_bb'] as num).toDouble(),
      events: [
        for (final raw in json['events'] as List)
          _eventFromJson(raw as Map<String, dynamic>),
      ],
    );
  }

  static Actor? _actorFromName(String? name) {
    if (name == null) return null;
    return Actor.values.firstWhere((a) => a.name == name);
  }

  static Map<String, dynamic> _eventToJson(PracticeEvent event) {
    return switch (event) {
      HandDealt() => {
        'type': 'dealt',
        'table_type': event.tableType.id,
        'hero_position': event.heroPosition.label,
        'villain_position': event.villainPosition.label,
        'hero_cards': PlayingCard.encodeAll(event.heroCards),
        'villain_cards': PlayingCard.encodeAll(event.villainCards),
        'starting_stack_bb': event.startingStackBb,
      },
      BoardDealt() => {
        'type': 'board',
        'street': event.street.id,
        'cards': PlayingCard.encodeAll(event.cards),
      },
      ActionOccurred() => {
        'type': 'action',
        'street': event.street.id,
        'actor': event.actor.name,
        'action': event.action.label,
        if (event.sizeBb != null) 'size_bb': event.sizeBb,
      },
      HandFinished() => {
        'type': 'finished',
        'ended_by_fold': event.endedByFold,
        'pot_bb': event.potBb,
        'winner': event.winner?.name,
      },
    };
  }

  static PracticeEvent _eventFromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'dealt':
        return HandDealt(
          tableType: TableType.fromId(json['table_type'] as String),
          heroPosition: Position.fromLabel(json['hero_position'] as String),
          villainPosition: Position.fromLabel(
            json['villain_position'] as String,
          ),
          heroCards: PlayingCard.parseAll(
            (json['hero_cards'] as List).cast<String>(),
          ),
          villainCards: PlayingCard.parseAll(
            (json['villain_cards'] as List).cast<String>(),
          ),
          startingStackBb: (json['starting_stack_bb'] as num).toDouble(),
        );
      case 'board':
        return BoardDealt(
          street: _streetFromId(json['street'] as String),
          cards: PlayingCard.parseAll((json['cards'] as List).cast<String>()),
        );
      case 'action':
        return ActionOccurred(
          street: _streetFromId(json['street'] as String),
          actor: _actorFromName(json['actor'] as String)!,
          action: PokerActionType.fromLabel(json['action'] as String),
          sizeBb: (json['size_bb'] as num?)?.toDouble(),
        );
      case 'finished':
        return HandFinished(
          endedByFold: json['ended_by_fold'] as bool,
          potBb: (json['pot_bb'] as num).toDouble(),
          winner: _actorFromName(json['winner'] as String?),
        );
      default:
        throw FormatException('未知のイベント種別: ${json['type']}');
    }
  }

  static Street _streetFromId(String id) =>
      Street.values.firstWhere((street) => street.id == id);
}
