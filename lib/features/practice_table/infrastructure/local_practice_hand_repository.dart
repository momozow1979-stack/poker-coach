import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/practice_hand_record.dart';
import '../domain/practice_hand_repository.dart';

/// [KeyValueStore] の上に載せた、端末内だけの練習履歴保存。
///
/// 1 レコード = 1 行の JSON（[JsonLearningStore] と同じ考え方）。
/// v1 は端末内保存のみで、Supabase への同期は行わない
/// （既存の `hand_reviews`/`quiz_attempts` と違い、まだ本体の学習記録
/// 機能に統合していないため。将来サーバー保存にするなら、この
/// クラスと同じ [PracticeHandRepository] を実装するだけでよい）。
class LocalPracticeHandRepository implements PracticeHandRepository {
  LocalPracticeHandRepository(this._store, {this.maxRecords = 200});

  final KeyValueStore _store;
  final int maxRecords;

  static const _key = 'practice_table.hands.v1';

  @override
  Future<List<PracticeHandRecord>> recent({int limit = 50}) async {
    final rows = await _store.getStringList(_key) ?? const [];
    final records = <PracticeHandRecord>[];
    for (final row in rows) {
      final record = _decode(row);
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records.take(limit).toList();
  }

  @override
  Future<void> save(PracticeHandRecord record) async {
    final rows = (await _store.getStringList(_key) ?? const []).toList();
    rows.insert(0, jsonEncode(record.toJson()));
    final trimmed = rows.length > maxRecords
        ? rows.sublist(0, maxRecords)
        : rows;
    await _store.setStringList(_key, trimmed);
  }

  static PracticeHandRecord? _decode(String row) {
    try {
      final json = jsonDecode(row);
      if (json is! Map<String, dynamic>) return null;
      return PracticeHandRecord.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
