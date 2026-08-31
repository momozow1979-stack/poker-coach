import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/auth_gateway.dart';

/// Supabase Auth を使う実装。
///
/// 匿名ファースト:
/// 初回起動時に `signInAnonymously()` でセッションを作り、登録なしで使い始められる。
/// あとから `updateUser()` でメール／パスワードを付けると、user_id を保ったまま
/// 通常アカウントへ昇格する（学習履歴はそのまま引き継がれる）。
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  AuthFailure? _lastFailure;

  @override
  AuthFailure? get lastFailure => _lastFailure;

  @override
  Stream<AppUser?> get changes =>
      _client.auth.onAuthStateChange.map((event) => _map(event.session?.user));

  @override
  AppUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Future<AppUser?> ensureSignedIn() async {
    final existing = _client.auth.currentUser;
    if (existing != null) {
      _lastFailure = null;
      return _map(existing);
    }

    try {
      final response = await _client.auth.signInAnonymously();
      _lastFailure = null;
      return _map(response.user);
    } on AuthException catch (error) {
      // オフラインでも学習は続けられるようにするため、ここでは投げない。
      _lastFailure = _mapAnonymousError(error);
      return null;
    } catch (error) {
      _lastFailure = AuthFailure('サインインに失敗しました: $error');
      return null;
    }
  }

  @override
  Future<AppUser> registerEmail({
    required String email,
    required String password,
  }) async {
    // 匿名セッションが無いと updateUser できないので、先に確保する。
    await ensureSignedIn();
    if (_client.auth.currentUser == null) {
      throw _lastFailure ?? const AuthFailure('サインインできていないため登録できません。');
    }

    try {
      final response = await _client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('登録に失敗しました。時間をおいて試してください。');
      }
      _lastFailure = null;
      return _map(user)!;
    } on AuthException catch (error) {
      throw AuthFailure(_registerMessage(error));
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('ログインに失敗しました。');
      }
      _lastFailure = null;
      return _map(user)!;
    } on AuthException catch (error) {
      throw AuthFailure(_signInMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException {
      // ローカルのセッション破棄は済んでいるので、そのまま匿名を取り直す。
    }
    await ensureSignedIn();
  }

  AppUser? _map(User? user) {
    if (user == null) return null;
    final email = user.email;
    return AppUser(
      id: user.id,
      isAnonymous: user.isAnonymous,
      email: (email == null || email.isEmpty) ? null : email,
      pendingEmail: user.newEmail,
    );
  }

  /// 匿名サインインの失敗を、原因の当たりが付くメッセージに変える。
  AuthFailure _mapAnonymousError(AuthException error) {
    final status = error.statusCode;
    final disabled =
        error.code == 'anonymous_provider_disabled' ||
        status == '401' ||
        status == '422';
    if (disabled) {
      return AuthFailure(
        'Supabase 側で匿名サインインが有効になっていない可能性があります'
        '（${error.message}）。'
        'Supabase ダッシュボードの Authentication → Sign In / Providers → '
        'Anonymous sign-ins を有効にしてください。',
        isAnonymousSignInDisabled: true,
      );
    }
    return AuthFailure('サインインに失敗しました（${error.message}）。');
  }

  String _registerMessage(AuthException error) {
    return switch (error.code) {
      'email_exists' ||
      'user_already_exists' => 'このメールアドレスは既に登録されています。「ログイン」から入ってください。',
      'weak_password' => 'パスワードが弱すぎます。6文字以上で設定してください。',
      'validation_failed' => '入力内容を確認してください（${error.message}）。',
      _ => '登録に失敗しました（${error.message}）。',
    };
  }

  String _signInMessage(AuthException error) {
    return switch (error.code) {
      'invalid_credentials' => 'メールアドレスまたはパスワードが違います。',
      'email_not_confirmed' => 'メールの確認が済んでいません。確認メールのリンクを開いてください。',
      _ => 'ログインに失敗しました（${error.message}）。',
    };
  }
}
