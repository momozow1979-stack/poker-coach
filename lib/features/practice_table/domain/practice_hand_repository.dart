import 'practice_hand_record.dart';

/// 練習ハンドの履歴を保存・取得する。
abstract interface class PracticeHandRepository {
  Future<List<PracticeHandRecord>> recent({int limit = 50});

  Future<void> save(PracticeHandRecord record);
}
