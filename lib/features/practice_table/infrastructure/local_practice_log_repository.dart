import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/tendency/practice_tendency.dart';

/// 練習ハンドごとの判断の記録（傾向分析用）を端末内に保存する。
///
/// 採点（重い計算）はハンドが終わったときに 1 回だけ行い、その結果だけを
/// 残す。傾向の画面は、毎回採点し直さずにこれを集計する。
class LocalPracticeLogRepository {
  LocalPracticeLogRepository(this._store, {this.maxLogs = 200});

  final KeyValueStore _store;
  final int maxLogs;

  static const _key = 'practice_table.logs.v1';

  Future<List<PracticeHandLog>> all() async {
    final rows = await _store.getStringList(_key) ?? const [];
    final logs = <PracticeHandLog>[];
    for (final row in rows) {
      try {
        final json = jsonDecode(row);
        if (json is! Map<String, dynamic>) continue;
        final log = PracticeHandLog.fromJson(json);
        if (log != null) logs.add(log);
      } on FormatException {
        continue;
      }
    }
    return logs;
  }

  Future<void> save(PracticeHandLog log) async {
    final rows = (await _store.getStringList(_key) ?? const []).toList();
    rows.insert(0, jsonEncode(log.toJson()));
    await _store.setStringList(
      _key,
      rows.length > maxLogs ? rows.sublist(0, maxLogs) : rows,
    );
  }
}
