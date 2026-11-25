import 'package:ai_poker_coach/features/gto_strategy/application/gto_flop_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // アセットの実読み込み（rootBundle経由）にはプラットフォームチャンネルが
  // 必要なので、バインディングだけ初期化する。testWidgets は使わない——
  // 本体がFakeAsyncゾーンに包まれ、実ファイルI/Oを伴う待ち受けと相性が悪く、
  // 実際に10分タイムアウトするのを確認した。
  TestWidgetsFlutterBinding.ensureInitialized();

  // `matchupIds` には本番計算・統合がまだのマッチアップ（例: hj_utg_6max）も
  // 含まれており、そのアセットは同梱されていない。rootBundle.loadString は
  // アセット未同梱のとき Exception ではなく FlutterError（Error系）を投げる
  // ため、`on Exception` だけで捕まえると一部マッチアップの失敗で
  // プロバイダ全体が失敗し、画面が真っ白になる（実機でこの不具合を確認）。
  // ここでは実際のアセットバンドル（オーバーライド無し）に対して読み込み、
  // 一部が未同梱でも catalog 全体が失敗しないことを固定する。
  test('gtoMatchupCatalogProvider は未同梱のマッチアップがあっても失敗しない', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final catalog = await container.read(gtoMatchupCatalogProvider.future);

    // btn_bb は同梱済みなので必ず含まれる。
    expect(catalog.map((s) => s.matchupId), contains('btn_bb'));
    // 未同梱のマッチアップは単に含まれないだけで、例外にはならない。
    expect(catalog.length, lessThan(matchupIds.length));
  });
}
