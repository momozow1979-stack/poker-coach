import 'package:shared_preferences/shared_preferences.dart';

/// 文字列リストを保存できる最小限のキー・バリューストア。
///
/// 学習履歴のローカル保存はこの上に載せている。
/// 保存先を差し替えたくなったら（sqlite など）この実装を足すだけで済むように、
/// 上位のロジックはこのインターフェースにしか依存させていない。
abstract class KeyValueStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<List<String>?> getStringList(String key);

  Future<void> setStringList(String key, List<String> value);

  Future<void> remove(String key);
}

/// 端末に永続化する実装。web では localStorage、モバイルでは各 OS の設定領域。
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<List<String>?> getStringList(String key) =>
      _preferences.getStringList(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _preferences.setStringList(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// テストと、永続化を用意できなかったときのフォールバック。
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<List<String>?> getStringList(String key) async =>
      (_values[key] as List<String>?)?.toList();

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value.toList();

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
