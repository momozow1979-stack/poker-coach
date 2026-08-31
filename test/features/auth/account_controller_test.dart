import 'package:ai_poker_coach/features/auth/application/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  ({ProviderContainer container, FakeAuthGateway auth}) build() {
    final auth = FakeAuthGateway();
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    return (container: container, auth: auth);
  }

  group('AccountController', () {
    test('初回は匿名サインインで即座に使える状態になる', () async {
      final env = build();
      final user = await env.container
          .read(accountProvider.notifier)
          .ensureSignedIn();

      expect(user, isNotNull);
      expect(user!.isAnonymous, isTrue);
      expect(user.statusLabel, contains('ゲスト'));
      expect(env.container.read(accountProvider)?.id, user.id);
    });

    test('メール登録しても user_id は変わらない（履歴が引き継がれる）', () async {
      final env = build();
      final anonymous = await env.container
          .read(accountProvider.notifier)
          .ensureSignedIn();

      final registered = await env.container
          .read(accountProvider.notifier)
          .registerEmail(email: 'player@example.com', password: 'password');

      expect(registered.id, anonymous!.id);
      expect(registered.isRegistered, isTrue);
      expect(registered.statusLabel, 'player@example.com');
    });

    test('別アカウントにログインすると user_id が変わる', () async {
      final env = build();
      final anonymous = await env.container
          .read(accountProvider.notifier)
          .ensureSignedIn();

      final signedIn = await env.container
          .read(accountProvider.notifier)
          .signIn(email: 'other@example.com', password: 'password');

      expect(signedIn.id, isNot(anonymous!.id));
    });

    test('ログアウトすると匿名セッションに戻る', () async {
      final env = build();
      final account = env.container.read(accountProvider.notifier);
      await account.ensureSignedIn();
      await account.registerEmail(
        email: 'player@example.com',
        password: 'password',
      );

      await account.signOut();

      expect(env.container.read(accountProvider)?.isAnonymous, isTrue);
    });

    test('匿名サインインが無効なら、理由が取れて例外にはならない', () async {
      final env = build();
      env.auth.anonymousSignInEnabled = false;

      final user = await env.container
          .read(accountProvider.notifier)
          .ensureSignedIn();

      expect(user, isNull);
      final failure = env.container.read(accountProvider.notifier).lastFailure;
      expect(failure?.isAnonymousSignInDisabled, isTrue);
    });
  });
}
