/// 例外をそのまま画面に出さないためのヘルパー。
///
/// `ClientException: Failed to fetch, uri=https://xxxx.supabase.co/auth/v1/signup?`
/// のような文字列を初心者に見せても、意味が分からないうえ不安にさせるだけ。
/// 接続先の URL が画面に出てしまう問題もある。
library;

/// ネットワークに繋がらないことが原因の例外か。
///
/// 例外の型は使っているクライアントによって変わるため、
/// 型ではなくメッセージの特徴で判定する。
bool looksLikeNetworkError(Object error) {
  final text = error.toString();
  const markers = [
    'Failed to fetch',
    'SocketException',
    'ClientException',
    'HttpException',
    'TimeoutException',
    'Connection closed',
    'Connection refused',
    'Network is unreachable',
    'XMLHttpRequest',
  ];
  return markers.any(text.contains);
}

/// 利用者に見せる文言。例外の中身は含めない。
///
/// [offline] はネットワーク起因のときの文言、
/// [fallback] はそれ以外のときの文言。
String friendlyErrorMessage(
  Object error, {
  required String offline,
  required String fallback,
}) => looksLikeNetworkError(error) ? offline : fallback;
