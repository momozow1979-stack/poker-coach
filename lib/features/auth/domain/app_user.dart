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
  ///
  /// 匿名でもサーバーには保存される（[SyncStatusLine] 参照）。
  /// 「この端末のみ」と書くと保存状況の表示と矛盾するため、未登録である
  /// こと（＝メール・Google未登録なので、この端末以外からは戻れない）
  /// だけを表す文言にする。
  String get statusLabel {
    if (isRegistered) return email!;
    if (pendingEmail != null) return '$pendingEmail（確認メール待ち）';
    return 'ゲスト（未登録）';
  }
}

/// 認証まわりの失敗。UI にそのまま出せる日本語メッセージを持つ。
class AuthFailure implements Exception {
  const AuthFailure(
    this.message, {
    this.isAnonymousSignInDisabled = false,
    this.isIdentityAlreadyLinked = false,
  });

  final String message;

  /// Supabase 側で Anonymous sign-ins が無効になっている疑いがあるか。
  final bool isAnonymousSignInDisabled;

  /// そのGoogleアカウントが既に別のユーザーに紐づいている（＝今の端末の
  /// 匿名アカウントへは追加登録できない）失敗か。この場合、ユーザーが
  /// 本当にやりたいのは「そのGoogleアカウントの持つデータへ戻ること」
  /// なので、UI側で [AuthGateway.signInWithGoogleDirectly] を呼べる
  /// ボタンを出す。
  final bool isIdentityAlreadyLinked;

  @override
  String toString() => 'AuthFailure: $message';
}
