import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/poker_action.dart';
import '../../../../shared/models/starting_hand.dart';
import '../../../../shared/widgets/action_frequency_bar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/collapsible_section.dart';
import '../../../range_chart/application/range_providers.dart';
import '../../../range_chart/domain/range_action.dart';
import '../../../range_chart/domain/range_entry.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';

/// 回答後の解説。
///
/// 最初に見せるのは「正解かどうか」と「短い理由」だけにして、
/// GTO / 実戦 / よくあるミスは畳んでおく。
class QuizExplanationView extends ConsumerWidget {
  const QuizExplanationView({
    super.key,
    required this.quiz,
    required this.isCorrect,
    this.onOpenRange,
  });

  final Quiz quiz;
  final bool isCorrect;

  /// 関連するレンジ表を開く。null なら表示しない。
  final VoidCallback? onOpenRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explanation = quiz.explanation;
    final isTerm = quiz.category == QuizCategory.terminology;
    final frequency = _resolveRangeFrequency(ref, quiz);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultBanner(isCorrect: isCorrect, quiz: quiz),
        const SizedBox(height: AppSpacing.md),
        _ReasonCard(body: explanation.shortReason),
        if (frequency != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _RangeFrequencyCard(data: frequency),
        ],
        const SizedBox(height: AppSpacing.sm),
        const _MoreLabel(),
        const SizedBox(height: AppSpacing.sm),
        // 用語問題は状況を伴わないので、見出しも言葉の説明に合わせる。
        CollapsibleSection(
          icon: isTerm ? Icons.psychology_outlined : Icons.functions_rounded,
          title: isTerm ? 'なぜ大事か' : 'GTO視点',
          body: explanation.gtoView,
          accent: AppColors.info,
        ),
        CollapsibleSection(
          icon: Icons.sports_esports_rounded,
          title: isTerm ? '実戦での使いどころ' : '実戦での調整',
          body: explanation.practicalView,
          accent: AppColors.warning,
        ),
        CollapsibleSection(
          icon: Icons.error_outline_rounded,
          title: isTerm ? 'よくある勘違い' : 'よくある初心者のミス',
          body: explanation.commonMistake,
          accent: AppColors.danger,
        ),
        if (onOpenRange != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenRange,
              icon: const Icon(Icons.grid_on_rounded, size: 18),
              label: const Text('関連するレンジ表を見る'),
            ),
          ),
        ],
      ],
    );
  }
}

/// 正解 / 不正解のバナー。開いた瞬間に少し弾んで結果を印象づける。
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.isCorrect, required this.quiz});

  final bool isCorrect;
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.success : AppColors.danger;
    final banner = AppCard(
      color: color.withValues(alpha: 0.1),
      borderColor: color.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 30,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? '正解' : '不正解',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quiz.category == QuizCategory.terminology
                      ? '正解: ${quiz.correctChoice.label}'
                      : '正しいアクション: ${quiz.correctChoice.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return banner;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clamped = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.scale(scale: 0.94 + 0.06 * clamped, child: child),
        );
      },
      child: banner,
    );
  }
}

/// 最初から開いておく「理由」。ここだけ読めば次に進める分量にする。
class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                '理由',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreLabel extends StatelessWidget {
  const _MoreLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.unfold_more_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'タップでもっと詳しく',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// [QuizExplanationView] が実データを解決できたときに描画する頻度バー。
///
/// [ActionFrequencyBar] は実在するレンジ表（[RangeChart.entryFor]）の値を
/// そのまま表示するだけで、ここでは頻度を一切作らない。
class _RangeFrequencyCard extends StatelessWidget {
  const _RangeFrequencyCard({required this.data});

  final _RangeFrequencyData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grid_on_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'レンジ表での ${data.hand.code}（${data.spotTitle}）',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ActionFrequencyBar(segments: data.segments),
        ],
      ),
    );
  }
}

/// 頻度バーの描画に必要な情報。
class _RangeFrequencyData {
  const _RangeFrequencyData({
    required this.hand,
    required this.spotTitle,
    required this.segments,
  });

  final StartingHand hand;
  final String spotTitle;
  final List<ActionFrequencySegment> segments;
}

/// クイズに紐づくレンジ表スポットと、ヒーローの具体的な2枚のカードから、
/// 実在するレンジ表の頻度データを解決する。
///
/// 次のすべてを満たすときだけ実データを返す。1つでも欠ければ null を返し、
/// 呼び出し側は頻度バーを出さずテキスト解説だけにフォールバックする
/// （存在しない頻度を捏造しない）。
/// - 解説に `relatedRangeSpotId` が設定されている
/// - その ID で実際にレンジ表が引ける（[RangeRepository.chartById]）
/// - 状況にヒーローの具体的な2枚が設定されており、[StartingHand] に変換できる
/// - レンジ表が示すアクションが、この設問の正解の選択肢
///   （[QuizChoice.actionType]、Task 1 で付与済み）と一致する
///
/// 最後の条件が肝心: `relatedRangeSpotId` は「オープンレイズ表」のような
/// “参考になる関連チャート” を指すだけで、必ずしもその設問が問う決断
/// そのもの（例: 3Bet に直面した場面、フロップのベット判断）ではない。
/// 一致を確認せずに表示すると、例えば「3Bet が正解」の設問に
/// 「オープンレイズ表では Call」という一見矛盾する数字を、
/// あたかもこの設問の答えであるかのように出してしまう。
/// そのため、正解の選択肢と食い違うときは意図的に表示しない。
_RangeFrequencyData? _resolveRangeFrequency(WidgetRef ref, Quiz quiz) {
  final spotId = quiz.explanation.relatedRangeSpotId;
  final situation = quiz.situation;
  if (spotId == null || situation == null || situation.heroCards.length != 2) {
    return null;
  }

  final chart = ref.watch(rangeChartByIdProvider(spotId));
  if (chart == null) return null;

  final hand = StartingHand.fromCards(
    situation.heroCards[0],
    situation.heroCards[1],
  );
  final entry = chart.entryFor(hand);
  final segments = _segmentsIfConsistent(entry, quiz.correctChoice.actionType);
  if (segments == null || segments.isEmpty) return null;

  return _RangeFrequencyData(
    hand: hand,
    spotTitle: chart.spot.title,
    segments: segments,
  );
}

/// [entry] が表す実際のアクションと、設問の正解 [correctActionType] が
/// 一致するときだけ区間を組み立てる。一致しなければ null
/// （＝表示しない）。MIX ハンドは、主・副いずれかが正解と一致すれば
/// 一致とみなし、両方の内訳をそのまま見せる。
List<ActionFrequencySegment>? _segmentsIfConsistent(
  RangeEntry entry,
  PokerActionType? correctActionType,
) {
  if (correctActionType == null) return null;

  final blend = entry.blend;
  if (entry.action == RangeAction.mixed) {
    if (blend == null) return null;
    final primaryType = _pokerActionFor(blend.primary);
    final secondaryType = _pokerActionFor(blend.secondary);
    if (correctActionType != primaryType &&
        correctActionType != secondaryType) {
      return null;
    }
    return [
      ActionFrequencySegment(
        actionType: primaryType,
        share: blend.primaryShare,
      ),
      ActionFrequencySegment(
        actionType: secondaryType,
        share: blend.secondaryShare,
      ),
    ];
  }

  final actionType = _pokerActionFor(entry.action);
  if (correctActionType != actionType) return null;
  return [
    ActionFrequencySegment(actionType: actionType, share: entry.frequency),
  ];
}

/// レンジ表のアクション区分をクイズ側の [PokerActionType] に対応づける。
///
/// [PokerActionType] にはプリフロップのレイズ段階（オープン / 3Bet / 4Bet）
/// の区別が無いため、いずれも raise にまとめる。
PokerActionType _pokerActionFor(RangeAction action) => switch (action) {
  RangeAction.raise ||
  RangeAction.threeBet ||
  RangeAction.fourBet => PokerActionType.raise,
  RangeAction.call => PokerActionType.call,
  RangeAction.fold => PokerActionType.fold,
  // mixed は呼び出し側（_segmentsIfConsistent）で必ず blend 経由に
  // 分岐させ、ここには来ない。
  RangeAction.mixed => PokerActionType.raise,
};
