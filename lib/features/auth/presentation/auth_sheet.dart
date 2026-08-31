import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../profile/application/learning_providers.dart';
import '../application/auth_providers.dart';
import '../domain/app_user.dart';

/// 登録 / ログインの入力シート。
enum AuthSheetMode {
  register('メールで登録', 'この端末の学習履歴を、そのままアカウントに引き継ぎます。', '登録する'),
  signIn('ログイン', '登録済みのアカウントに入り直します。この端末の未登録の履歴は置き換わります。', 'ログインする');

  const AuthSheetMode(this.title, this.description, this.submitLabel);

  final String title;
  final String description;
  final String submitLabel;
}

Future<void> showAuthSheet(BuildContext context, AuthSheetMode mode) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AuthSheet(mode: mode),
    ),
  );
}

class _AuthSheet extends ConsumerStatefulWidget {
  const _AuthSheet({required this.mode});

  final AuthSheetMode mode;

  @override
  ConsumerState<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<_AuthSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@')) {
      setState(() => _error = 'メールアドレスを確認してください。');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'パスワードは6文字以上にしてください。');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final sync = ref.read(learningSyncControllerProvider.notifier);
      // 別アカウントに入ると、この端末の未送信ぶんは行き場を失う。
      // 先に今のアカウントへ送り切ってから切り替える。
      await sync.syncNow();

      final account = ref.read(accountProvider.notifier);
      final user = switch (widget.mode) {
        AuthSheetMode.register => await account.registerEmail(
          email: email,
          password: password,
        ),
        AuthSheetMode.signIn => await account.signIn(
          email: email,
          password: password,
        ),
      };
      // 切り替え後のアカウントの履歴を取り直す。
      await sync.syncNow();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_successMessage(user))));
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      if (mounted) setState(() => _error = '処理に失敗しました（$error）。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _successMessage(AppUser user) {
    if (widget.mode == AuthSheetMode.signIn) return 'ログインしました。';
    if (user.isRegistered) return 'アカウントを登録しました。学習履歴はそのまま引き継がれています。';
    return '確認メールを送りました。メール内のリンクを開くと登録が完了します。';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.mode.description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                hintText: '6文字以上',
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? '処理中…' : widget.mode.submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
