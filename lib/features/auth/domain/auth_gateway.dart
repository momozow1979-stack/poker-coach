import 'app_user.dart';

/// 認証の入り口。Supabase 実装とオフライン実装を差し替えられるようにする。
///
/// テストでは通信しない [OfflineAuthGateway] を使う。
abstract class AuthGateway {
  /// サインイン状態の変化。
  Stream<AppUser?> get changes;

  AppUser? get currentUser;

  /// セッションが無ければ匿名サインインする。
  ///
  /// 失敗しても例外は投げず null を返す（オフラインでもアプリは動く）。
  /// 失敗理由は [lastFailure] に入る。
  Future<AppUser?> ensureSignedIn();

  /// 直近の失敗。成功したら null に戻る。
  AuthFailure? get lastFailure;

  /// 匿名アカウントにメール／パスワードを付与して昇格させる。user_id は維持される。
  Future<AppUser> registerEmail({
    required String email,
    required String password,
  });

  /// 既存アカウントにログインする（別端末からの復帰）。
  Future<AppUser> signIn({required String email, required String password});

  /// サインアウトし、匿名セッションを取り直す。
  Future<void> signOut();
}

/// 通信しないダミー。テストと、Supabase 初期化に失敗したときに使う。
class OfflineAuthGateway implements AuthGateway {
  @override
  Stream<AppUser?> get changes => const Stream.empty();

  @override
  AppUser? get currentUser => null;

  @override
  AuthFailure? get lastFailure => null;

  @override
  Future<AppUser?> ensureSignedIn() async => null;

  @override
  Future<AppUser> registerEmail({
    required String email,
    required String password,
  }) async => throw const AuthFailure('オフラインのため登録できません。');

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async => throw const AuthFailure('オフラインのためログインできません。');

  @override
  Future<void> signOut() async {}
}
