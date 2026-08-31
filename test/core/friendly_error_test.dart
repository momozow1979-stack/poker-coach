import 'package:ai_poker_coach/core/errors/friendly_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('例外を利用者向けの文言に変える', () {
    test('通信できないときの例外をネットワーク起因と判定する', () {
      const cases = [
        'ClientException: Failed to fetch, uri=https://example.supabase.co/auth/v1/signup?',
        'SocketException: Connection refused (OS Error: ...)',
        'TimeoutException after 0:00:10.000000',
        'Connection closed before full header was received',
      ];
      for (final text in cases) {
        expect(looksLikeNetworkError(text), isTrue, reason: text);
      }
    });

    test('それ以外の例外はネットワーク起因と判定しない', () {
      expect(
        looksLikeNetworkError('FormatException: unexpected token'),
        isFalse,
      );
      expect(looksLikeNetworkError(StateError('bad state')), isFalse);
    });

    test('文言に例外の中身を含めない', () {
      const raw =
          'ClientException: Failed to fetch, uri=https://example.supabase.co/auth/v1/signup?';
      final message = friendlyErrorMessage(
        raw,
        offline: 'いまネットワークに接続できていません。',
        fallback: 'サインインできませんでした。',
      );
      expect(message, 'いまネットワークに接続できていません。');
      // 接続先の URL が画面に出ないこと。
      expect(message, isNot(contains('supabase.co')));
      expect(message, isNot(contains('ClientException')));
    });

    test('ネットワーク起因でなければ fallback を返す', () {
      expect(
        friendlyErrorMessage(
          'FormatException',
          offline: 'offline',
          fallback: 'fallback',
        ),
        'fallback',
      );
    });
  });
}
