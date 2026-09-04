import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/multi_choice_chip_group.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../profile/domain/user_profile.dart';
import '../../quiz/domain/quiz_category.dart';
import '../application/onboarding_providers.dart';
import '../domain/onboarding_answers.dart';

/// 初回起動時のオンボーディング。3ステップ:
/// ①自己申告レベル ②学びたい分野 ③まとめ。
///
/// 見た目だけの演出にせず、回答を実際にアプリの挙動へ反映する
/// （`ProfileStore` の初期レベル・「今日の10問」の出題重み）。
class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  static const _stepCount = 3;

  int _step = 0;
  PokerLevel? _level;
  final Set<QuizCategory> _focusCategories = {};
  bool _saving = false;

  static const _levelDescriptions = <PokerLevel, String>{
    PokerLevel.beginner: 'ルールは分かるが、実戦の経験はまだ少ない',
    PokerLevel.novice: '実戦はしているが、ハンドの選び方に自信がない',
    PokerLevel.intermediate: '基本のセオリーは分かる。応用の場面で迷うことがある',
    PokerLevel.advanced: 'GTOや相手のタイプに応じた調整を意識してプレイしている',
  };

  bool get _canProceed => switch (_step) {
    0 => _level != null,
    1 => _focusCategories.isNotEmpty,
    _ => true,
  };

  void _goNext() {
    if (!_canProceed) return;
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      return;
    }
    _complete();
  }

  void _goBack() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  Future<void> _complete() async {
    final level = _level;
    if (level == null || _saving) return;

    setState(() => _saving = true);
    final answers = OnboardingAnswers(
      pokerLevel: level,
      focusCategories: _focusCategories.toList(),
      completedAt: DateTime.now(),
    );
    await ref.read(onboardingAnswersProvider.notifier).complete(answers);
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    if (_step > 0)
                      IconButton(
                        onPressed: _saving ? null : _goBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _stepCount; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Container(
                                width: i == _step ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i <= _step
                                      ? AppColors.accent
                                      : AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: switch (_step) {
                    0 => _LevelStep(
                      key: const ValueKey('level'),
                      selected: _level,
                      descriptions: _levelDescriptions,
                      onSelected: (level) => setState(() => _level = level),
                    ),
                    1 => _FocusStep(
                      key: const ValueKey('focus'),
                      selected: _focusCategories,
                      onToggle: (category) => setState(() {
                        if (!_focusCategories.remove(category)) {
                          _focusCategories.add(category);
                        }
                      }),
                    ),
                    _ => _SummaryStep(
                      key: const ValueKey('summary'),
                      level: _level,
                      focusCategories: _focusCategories,
                    ),
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canProceed && !_saving ? _goNext : null,
                    child: Text(
                      _saving
                          ? 'はじめています…'
                          : _step == _stepCount - 1
                          ? 'はじめる'
                          : '次へ',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelStep extends StatelessWidget {
  const _LevelStep({
    super.key,
    required this.selected,
    required this.descriptions,
    required this.onSelected,
  });

  final PokerLevel? selected;
  final Map<PokerLevel, String> descriptions;
  final ValueChanged<PokerLevel> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          'ようこそ',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          '今のポーカーの実力を教えてください',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '出題の難易度と、最初に学ぶ内容の目安にします。'
          '後からいつでも変わっていきます。',
          style: TextStyle(
            fontSize: 13,
            height: 1.7,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < PokerLevel.values.length; i++)
          FadeSlideIn(
            delay: Duration(milliseconds: 60 * i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _LevelCard(
                level: PokerLevel.values[i],
                description: descriptions[PokerLevel.values[i]] ?? '',
                isSelected: selected == PokerLevel.values[i],
                onTap: () => onSelected(PokerLevel.values[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final PokerLevel level;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: isSelected ? AppColors.accent : AppColors.border,
      color: isSelected ? AppColors.accent.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected ? AppColors.accent : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _FocusStep extends StatelessWidget {
  const _FocusStep({super.key, required this.selected, required this.onToggle});

  final Set<QuizCategory> selected;
  final ValueChanged<QuizCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          '学びたい分野を選んでください',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '複数選べます。まだ苦手分野が分からない最初のうちは、'
          'ここで選んだ分野を優先して出題します。',
          style: TextStyle(
            fontSize: 13,
            height: 1.7,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        MultiChoiceChipGroup<QuizCategory>(
          values: QuizCategory.values,
          selected: selected,
          labelBuilder: (category) => category.label,
          onToggle: onToggle,
        ),
      ],
    );
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({
    super.key,
    required this.level,
    required this.focusCategories,
  });

  final PokerLevel? level;
  final Set<QuizCategory> focusCategories;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          size: 40,
          color: AppColors.reward,
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'プランができました',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'この内容はいつでも学習の進み具合に合わせて更新されます。',
          style: TextStyle(
            fontSize: 13,
            height: 1.7,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'レベル',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                level?.label ?? '-',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '学びたい分野',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final category in focusCategories)
                    TagChip(label: category.label, color: AppColors.info),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
