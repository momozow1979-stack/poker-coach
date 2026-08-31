import 'table_type.dart';

/// ポジション。6MAX / 9MAX の両方を 1 つの enum で表現する。
enum Position {
  utg('UTG', 'アーリー'),
  utg1('UTG+1', 'アーリー'),
  mp('MP', 'ミドル'),
  lj('LJ', 'ミドル'),
  hj('HJ', 'レイト'),
  co('CO', 'レイト'),
  btn('BTN', 'レイト'),
  sb('SB', 'ブラインド'),
  bb('BB', 'ブラインド');

  const Position(this.label, this.groupLabel);

  /// UI 表示・AI 入力で使う短縮名。
  final String label;

  /// 「アーリー」「レイト」などのグループ名。初心者向けの補足に使う。
  final String groupLabel;

  static const List<Position> sixMaxOrder = [
    Position.utg,
    Position.hj,
    Position.co,
    Position.btn,
    Position.sb,
    Position.bb,
  ];

  static const List<Position> nineMaxOrder = [
    Position.utg,
    Position.utg1,
    Position.mp,
    Position.lj,
    Position.hj,
    Position.co,
    Position.btn,
    Position.sb,
    Position.bb,
  ];

  /// プリフロップの行動順。UTG から始まり、ブラインドが最後になる。
  static List<Position> orderFor(TableType tableType) => switch (tableType) {
    TableType.sixMax => sixMaxOrder,
    TableType.nineMax => nineMaxOrder,
  };

  /// フロップ以降の行動順。SB から始まり、BTN が最後になる。
  ///
  /// 「どちらが後に行動できるか（IP / OOP）」はこちらで判定する。
  /// プリフロップの順番で比べると、BTN が BB より先に見えてしまう。
  static List<Position> postflopOrderFor(TableType tableType) {
    final seats = orderFor(tableType);
    final start = seats.indexOf(Position.sb);
    return [
      for (var i = 0; i < seats.length; i++) seats[(start + i) % seats.length],
    ];
  }

  /// フロップ以降で [other] より後に行動できるか。
  bool isInPositionAgainst(Position other, TableType tableType) {
    final order = postflopOrderFor(tableType);
    return order.indexOf(this) > order.indexOf(other);
  }

  static Position fromLabel(String label) =>
      Position.values.firstWhere((position) => position.label == label);
}
