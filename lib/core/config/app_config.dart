import 'package:flutter/foundation.dart';

/// 起動時に `--dart-define` から受け取る設定。
///
/// 既定値は持たない。値が無いまま起動すると、モックにフォールバックして
/// 「保存できていないのに動いているように見える」状態になるため、
/// [validate] で弾いて起動を止める。
///
/// 実行例:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
/// ```
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// 開発時にだけモックの学習履歴を流し込むためのスイッチ。
  ///
  /// `--dart-define=USE_MOCK_SEED=true` を付けたデバッグビルドでのみ有効。
  /// リリースビルドでは [kReleaseMode] が true になるため定数畳み込みで
  /// false になり、シード生成コードごと tree-shake される。
  static const _useMockSeedFlag = bool.fromEnvironment('USE_MOCK_SEED');
  static bool get useMockSeed => _useMockSeedFlag && !kReleaseMode;

  /// 公開鍵の新形式（旧 anon JWT の後継）。
  static const _publishableKeyPrefix = 'sb_publishable_';

  /// 秘密鍵。クライアントに載せてはいけない。
  static const _secretKeyPrefix = 'sb_secret_';

  /// 設定の不備を日本語で列挙する。空なら起動して良い。
  static List<String> validate() =>
      validateValues(url: supabaseUrl, publishableKey: supabasePublishableKey);

  /// [validate] の中身。テストから任意の値を検証できるように切り出している。
  static List<String> validateValues({
    required String url,
    required String publishableKey,
  }) {
    final errors = <String>[];

    if (url.isEmpty) {
      errors.add('SUPABASE_URL が指定されていません。');
    } else if (!url.startsWith('https://')) {
      errors.add('SUPABASE_URL は https:// で始まる必要があります。');
    }

    if (publishableKey.isEmpty) {
      errors.add('SUPABASE_PUBLISHABLE_KEY が指定されていません。');
    } else if (publishableKey.startsWith(_secretKeyPrefix)) {
      // 秘密鍵は RLS を無視できてしまうため、絶対にクライアントへ載せない。
      errors.add(
        'SUPABASE_PUBLISHABLE_KEY に秘密鍵 ($_secretKeyPrefix…) が指定されています。'
        'この鍵はクライアントに埋め込めません。$_publishableKeyPrefix… を指定してください。',
      );
    } else if (!publishableKey.startsWith(_publishableKeyPrefix) &&
        !publishableKey.startsWith('eyJ')) {
      errors.add(
        'SUPABASE_PUBLISHABLE_KEY の形式が想定外です。'
        '$_publishableKeyPrefix… で始まる公開鍵を指定してください。',
      );
    }

    return errors;
  }

  static bool get isValid => validate().isEmpty;
}
