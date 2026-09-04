import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../application/trainer_providers.dart';
import '../domain/trainer_scenario.dart';

/// トレーニングできるハンドの一覧。
class TrainerListPage extends ConsumerWidget {
  const TrainerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenarios = ref.watch(trainerScenariosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ハンドトレーナー'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.quiz),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            AppCard(
              color: AppColors.surfaceHigh,
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '1本のハンドを、プリフロップからリバーまで順に進みます。'
                      '各ストリートで「あなたならどうするか」を選ぶと、その場で解説が出ます。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 難易度ごとにまとめる。10本を1列に並べるだけだと、
            // 初心者が「どれから始めればいいか」で止まってしまう。
            for (final difficulty in TrainerDifficulty.values)
              ..._section(
                context,
                ref,
                difficulty: difficulty,
                scenarios: scenarios
                    .where((scenario) => scenario.difficulty == difficulty)
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// 難易度ごとの見出しとカード。
List<Widget> _section(
  BuildContext context,
  WidgetRef ref, {
  required TrainerDifficulty difficulty,
  required List<TrainerScenario> scenarios,
}) {
  if (scenarios.isEmpty) return const [];

  final (String title, String subtitle) = switch (difficulty) {
    TrainerDifficulty.beginner => ('まずはここから', 'ポーカーの経験がなくても進められます'),
    TrainerDifficulty.intermediate => ('慣れてきたら', 'ボードや相手によって答えが変わる場面です'),
    TrainerDifficulty.advanced => ('もう一歩', '相手が持てない手まで考える場面です'),
  };

  return [
    SectionHeader(title: title, subtitle: subtitle),
    const SizedBox(height: AppSpacing.md),
    for (var i = 0; i < scenarios.length; i++)
      FadeSlideIn(
        key: ValueKey(scenarios[i].id),
        delay: Duration(milliseconds: 60 * i),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ScenarioCard(
            scenario: scenarios[i],
            onTap: () {
              ref.read(trainerSessionProvider.notifier).start(scenarios[i].id);
              context.go(AppRoutes.trainerPlay(scenarios[i].id));
            },
          ),
        ),
      ),
    const SizedBox(height: AppSpacing.lg),
  ];
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario, required this.onTap});

  final TrainerScenario scenario;
  final VoidCallback onTap;

  Color get _difficultyColor => switch (scenario.difficulty) {
    TrainerDifficulty.beginner => AppColors.accent,
    TrainerDifficulty.intermediate => AppColors.warning,
    TrainerDifficulty.advanced => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  scenario.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PlayingCardRow(cards: scenario.heroCards, width: 30, spacing: 4),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            scenario.goal,
            style: const TextStyle(
              fontSize: 13,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TagChip(
                label: scenario.difficulty.label,
                color: _difficultyColor,
                icon: Icons.signal_cellular_alt_rounded,
              ),
              TagChip(label: scenario.positionLabel, color: AppColors.info),
              TagChip(
                label: scenario.boardStyle.label,
                color: AppColors.textSecondary,
              ),
              TagChip(
                label: '${scenario.spotCount}つの判断',
                color: AppColors.textSecondary,
                icon: Icons.route_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
