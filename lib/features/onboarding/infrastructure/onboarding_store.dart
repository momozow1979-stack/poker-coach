import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/onboarding_answers.dart';

/// オンボーディングの回答を [KeyValueStore] の上に保存する。
///
/// 学習履歴とは独立した 1 個の JSON として持つ（同期対象ではないため
/// `learning.*` のキー体系とは分けている）。
class OnboardingStore {
  OnboardingStore(this._store);

  final KeyValueStore _store;

  static const _answersKey = 'onboarding.answers.v1';

  /// 未回答、または保存データが壊れている場合は null。
  Future<OnboardingAnswers?> load() async {
    final raw = await _store.getString(_answersKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return OnboardingAnswers.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(OnboardingAnswers answers) =>
      _store.setString(_answersKey, jsonEncode(answers.toJson()));

  /// テスト・デバッグ用。オンボーディングをやり直させたいときに使う。
  Future<void> clear() => _store.remove(_answersKey);
}
