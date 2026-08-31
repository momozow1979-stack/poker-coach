import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';

/// 設定画面。MVP では現状と今後の予定を示すだけに留めている。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _roadmap = [
    ('Phase 5', 'レンジ表の DB 連携'),
    ('Phase 6', 'Edge Function 経由の AI ハンドレビュー'),
    ('Phase 7', '学習履歴に基づく AI コーチ'),
    ('Phase 8', 'エラーハンドリング / Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'データの保存先',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '学習履歴はまず端末に保存し、通信できるタイミングで Supabase へ同期します。'
                    '圏外でもクイズは解けて、オンラインに戻ったときにまとめて送られます。'
                    'メールアドレスを登録すると、別の端末でも同じ履歴を続けられます。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI の扱いについて',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'OpenAI の API キーはアプリに埋め込みません。'
                    'AI 呼び出しは Supabase Edge Function 経由でサーバー側から行います。'
                    'また、ソルバーの厳密な頻度や EV は生成しません。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今後の実装予定',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final (phase, description) in _roadmap)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 62,
                            child: Text(
                              phase,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              description,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
