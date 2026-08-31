import 'package:ai_poker_coach/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig の起動時チェック', () {
    test('正しい公開鍵なら通る', () {
      expect(
        AppConfig.validateValues(
          url: 'https://example.supabase.co',
          publishableKey: 'sb_publishable_abcdefg',
        ),
        isEmpty,
      );
    });

    test('未指定なら両方エラーになる（＝既定値へフォールバックしない）', () {
      final errors = AppConfig.validateValues(url: '', publishableKey: '');
      expect(errors, hasLength(2));
      expect(errors.join(), contains('SUPABASE_URL'));
      expect(errors.join(), contains('SUPABASE_PUBLISHABLE_KEY'));
    });

    test('秘密鍵を渡したら起動させない', () {
      final errors = AppConfig.validateValues(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_secret_dangerous',
      );
      expect(errors, hasLength(1));
      expect(errors.single, contains('秘密鍵'));
    });

    test('http:// は弾く', () {
      final errors = AppConfig.validateValues(
        url: 'http://example.supabase.co',
        publishableKey: 'sb_publishable_abcdefg',
      );
      expect(errors.single, contains('https://'));
    });

    test('旧形式の anon JWT も受け付ける', () {
      expect(
        AppConfig.validateValues(
          url: 'https://example.supabase.co',
          publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig',
        ),
        isEmpty,
      );
    });

    test('形式が想定外の鍵は弾く', () {
      final errors = AppConfig.validateValues(
        url: 'https://example.supabase.co',
        publishableKey: 'not-a-key',
      );
      expect(errors.single, contains('形式'));
    });

    test('テスト実行時はモックシードが無効', () {
      expect(AppConfig.useMockSeed, isFalse);
    });
  });
}
