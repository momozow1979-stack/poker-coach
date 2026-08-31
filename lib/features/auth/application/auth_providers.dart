import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import '../domain/auth_gateway.dart';

/// 認証の実装。`main()` から Supabase 版に差し替える。
///
/// 既定は通信しない実装なので、テストでは何も上書きしなくても動く。
final authGatewayProvider = Provider<AuthGateway>(
  (ref) => OfflineAuthGateway(),
);

/// サインイン中のユーザー。null は「まだサインインできていない」。
class AccountController extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    final gateway = ref.watch(authGatewayProvider);
    final subscription = gateway.changes.listen(
      (user) => state = user,
      onError: (Object _) {
        // 認証ストリームのエラーでアプリを落とさない。
      },
    );
    ref.onDispose(subscription.cancel);
    return gateway.currentUser;
  }

  AuthGateway get _gateway => ref.read(authGatewayProvider);

  /// 初回起動時の匿名サインイン。失敗しても例外は投げない。
  Future<AppUser?> ensureSignedIn() async {
    final user = await _gateway.ensureSignedIn();
    state = user ?? _gateway.currentUser;
    return state;
  }

  /// 匿名アカウントにメール／パスワードを付けて昇格させる。
  Future<AppUser> registerEmail({
    required String email,
    required String password,
  }) async {
    final user = await _gateway.registerEmail(email: email, password: password);
    state = user;
    return user;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _gateway.signIn(email: email, password: password);
    state = user;
    return user;
  }

  Future<void> signOut() async {
    await _gateway.signOut();
    state = _gateway.currentUser;
  }

  /// 直近のサインイン失敗（匿名サインイン無効など）。
  AuthFailure? get lastFailure => _gateway.lastFailure;
}

final accountProvider = NotifierProvider<AccountController, AppUser?>(
  AccountController.new,
);
