/// サインイン中のユーザー。
///
/// 匿名ユーザーとメール登録済みユーザーで `id` は変わらない。
/// 匿名アカウントにメール／パスワードを付与すると、同じ `id` のまま昇格する。
class AppUser {
  const AppUser({
    required this.id,
    required this.isAnonymous,
    this.email,
    this.pendingEmail,
  });

  final String id;
  final bool isAnonymous;

  /// 確定済みのメールアドレス。匿名のうちは null。
  final String? email;

  /// 確認メール待ちのアドレス。確認が済むと [email] に移る。
  final String? pendingEmail;

  bool get isRegistered => !isAnonymous && email != null;

  /// 画面に出す状態ラベル。
  String get statusLabel {
    if (isRegistered) return email!;
    if (pendingEmail != null) return '$pendingEmail（確認メール待ち）';
    return 'ゲスト（この端末のみ）';
  }
}

/// 認証まわりの失敗。UI にそのまま出せる日本語メッセージを持つ。
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.isAnonymousSignInDisabled = false});

  final String message;

  /// Supabase 側で Anonymous sign-ins が無効になっている疑いがあるか。
  final bool isAnonymousSignInDisabled;

  @override
  String toString() => 'AuthFailure: $message';
}
