import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:flutter_test/flutter_test.dart';

/// [PokerActionTypeVisuals] の健全性チェック。
///
/// 「新しいアクション種別を追加したのに、色・アイコンを対応させ忘れる」
/// という抜け漏れを、実行時の switch 網羅性チェック（enum に漏れがあると
/// コンパイルエラーになる）とは別に、テストとしても固定しておく。
void main() {
  group('PokerActionTypeVisuals', () {
    test('すべてのアクション種別に色が割り当てられている', () {
      for (final action in PokerActionType.values) {
        expect(action.color, isNotNull, reason: action.name);
      }
    });

    test('すべてのアクション種別にアイコンが割り当てられている', () {
      for (final action in PokerActionType.values) {
        expect(action.icon, isNotNull, reason: action.name);
      }
    });

    test('色は色だけに頼らないよう、種別ごとに異なる', () {
      // 色が全く同じだと、隣り合うアクションが見分けられなくなる。
      final colors = PokerActionType.values.map((a) => a.color).toSet();
      expect(colors, hasLength(PokerActionType.values.length));
    });

    test('アイコンも種別ごとに異なる', () {
      final icons = PokerActionType.values.map((a) => a.icon).toSet();
      expect(icons, hasLength(PokerActionType.values.length));
    });
  });
}
