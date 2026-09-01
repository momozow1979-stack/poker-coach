import 'package:ai_poker_coach/features/hand_review/domain/hand_read.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlayingCard> cards(String value) => PlayingCard.parseAll(value.split(' '));

void main() {
  group('手の呼び名', () {
    test('トップペアとキッカーを言い当てる', () {
      final read = HandRead.of(cards('Ah Qs'), cards('Ad 7c 2s'));
      expect(read.label, 'A のトップペア（キッカー Q）');
    });

    test('セカンドペアを言い当てる', () {
      final read = HandRead.of(cards('7h 6s'), cards('Ad 7c 2s'));
      expect(read.label, contains('セカンドペア'));
    });

    test('ポケットペアのオーバーペアとアンダーペアを区別する', () {
      expect(
        HandRead.of(cards('Kh Kd'), cards('9c 7d 2s')).label,
        contains('オーバーペア'),
      );
      expect(
        HandRead.of(cards('8h 8d'), cards('Qc 7d 2s')).label,
        contains('アンダーペア'),
      );
    });

    test('手札2枚が絡むスリーカードはセットと呼ぶ', () {
      expect(HandRead.of(cards('7h 7d'), cards('7c 9d 2s')).label, '7 のセット');
      expect(HandRead.of(cards('7h Ad'), cards('7c 7d 2s')).label, '7 のスリーカード');
    });
  });

  group('ドロー', () {
    test('フラッシュドローを見つける', () {
      final read = HandRead.of(cards('9d 8d'), cards('7d 6c 2d'));
      expect(read.draws.any((d) => d.contains('フラッシュドロー')), isTrue);
    });

    test('両側が伸びるストレートドローを枚数つきで見つける', () {
      final read = HandRead.of(cards('9d 8c'), cards('7h 6s 2c'));
      final straight = read.draws.firstWhere((d) => d.contains('ストレート'));
      expect(straight, contains('両側'));
      // 5 と 10 で完成するので、残っているのは 8 枚。
      expect(straight, contains('8枚'));
    });

    test('98s で 7 6 2 のフラッシュドロー付きなら、伸びるカードは15枚', () {
      // ♦ が9枚、5 と 10 が8枚、うち5♦と10♦は重複するので 9 + 6 = 15。
      final read = HandRead.of(cards('9d 8d'), cards('7d 6c 2d'));
      expect(read.improvingCards, 15);
    });

    test('リバーではドローを出さない', () {
      final read = HandRead.of(cards('9d 8d'), cards('7d 6c 2d Kh 3s'));
      expect(read.draws, isEmpty);
      expect(read.improvingCards, 0);
    });
  });

  group('正確な勝率', () {
    test('リバーでは勝ち負けが確定する', () {
      final equity = ExactEquity.between(
        hero: cards('Ah Qs'),
        villain: cards('Kh Jd'),
        board: cards('Ad 7c 2s Kc 9h'),
      )!;
      // A のトップペア vs K のペア。ヒーローの勝ち。
      expect(equity.percent, 100);
      expect(equity.total, 1);
    });

    test('ターンでは残り1枚を全部数える', () {
      final equity = ExactEquity.between(
        hero: cards('Ah Ad'),
        villain: cards('Kh Kd'),
        board: cards('2c 7d 9s 3h'),
      )!;
      // 残り44枚のうち K の2枚だけ負ける。
      expect(equity.total, 44);
      expect(equity.lose, 2);
      expect(equity.win, 42);
    });

    test('フロップでは残り2枚の組み合わせを全部数える', () {
      final equity = ExactEquity.between(
        hero: cards('Ah Ad'),
        villain: cards('Kh Kd'),
        board: cards('2c 7d 9s'),
      )!;
      // 45枚から2枚を選ぶ組み合わせ。
      expect(equity.total, 45 * 44 ~/ 2);
      expect(equity.value, greaterThan(0.9));
    });

    test('プリフロップは重すぎるので計算しない（数字を装わない）', () {
      final equity = ExactEquity.between(
        hero: cards('Ah Ad'),
        villain: cards('Kh Kd'),
        board: const [],
      );
      expect(equity, isNull);
    });

    test('相手のハンドが分からなければ計算しない', () {
      final equity = ExactEquity.between(
        hero: cards('Ah Ad'),
        villain: const [],
        board: cards('2c 7d 9s'),
      );
      expect(equity, isNull);
    });
  });
}
