import 'trainer_scenario.dart';

/// トレーニング用シナリオの取得口。
///
/// 現在はアプリ同梱の固定シナリオだけを返す。
/// 将来 Supabase Edge Function で動的に生成する実装へ差し替えられるよう、
/// 画面側はこのインターフェースだけを見る。
abstract interface class TrainerScenarioRepository {
  /// 出題できるシナリオすべて。
  List<TrainerScenario> all();

  /// ID 指定で 1 本取る。見つからなければ null。
  TrainerScenario? byId(String id);
}
