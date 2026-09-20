import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router.dart';
import '../application/hand_review_providers.dart';
import '../domain/camera_hand_assignment.dart';

/// テーブル写真からカードを読み取り、役割を確認・修正してレビュー入力に反映する画面。
///
/// 撮影 → Edge Function `/read-hand`(Claude Vision) → 位置で自動仕分け →
/// この画面で確認・修正 → 既存のレビュー入力へ。詳細は docs/camera-hand-read.md。
class CameraHandReadPage extends ConsumerStatefulWidget {
  const CameraHandReadPage({super.key});

  @override
  ConsumerState<CameraHandReadPage> createState() => _CameraHandReadPageState();
}

enum _Phase { intro, loading, review, error }

class _CameraHandReadPageState extends ConsumerState<CameraHandReadPage> {
  _Phase _phase = _Phase.intro;
  List<AssignedCard> _assignments = [];
  List<String> _warnings = [];
  String _error = '';

  Future<void> _capture(ImageSource source) async {
    setState(() => _phase = _Phase.loading);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) {
        setState(() => _phase = _Phase.intro);
        return;
      }
      final bytes = await file.readAsBytes();
      final mediaType = file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final result = await ref
          .read(cameraHandReadRepositoryProvider)
          .read(imageBytes: bytes, mediaType: mediaType);
      setState(() {
        _assignments = initialAssignments(result);
        _warnings = result.warnings;
        _phase = _assignments.isEmpty ? _Phase.error : _Phase.review;
        if (_assignments.isEmpty) {
          _error = 'カードを読み取れませんでした。もう一度、明るい場所で撮影してください。';
        }
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.error;
        _error = '読み取りに失敗しました。通信環境やAPIキーの設定を確認してください。';
      });
    }
  }

  void _confirm() {
    final applied = applyAssignments(
      ref.read(handReviewFormProvider),
      _assignments,
    );
    ref.read(handReviewFormProvider.notifier).update((_) => applied);
    context.go(AppRoutes.reviewInput);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('写真からハンドを読み取る')),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _buildIntro(),
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.error => _buildError(),
          _Phase.review => _buildReview(),
        },
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'ショーダウンで、スマホを縦向きにしてテーブル全体を1枚撮影します。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '自分の2枚は画面下側に入れて撮ると、自動で「自分のハンド」として仕分けられます。'
            '読み取り後、違うカードだけ役割を選び直せます。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _capture(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('カメラで撮影'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _capture(ImageSource.gallery),
            icon: const Icon(Icons.image_outlined),
            label: const Text('写真を選ぶ'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(_error, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _phase = _Phase.intro),
            child: const Text('撮り直す'),
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'ランク・スートは自動で読み取り済みです。違うカードだけ、'
                'プルダウンで役割を選び直してください。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final w in _warnings)
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          w,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 12),
              ..._buildGroups(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _phase = _Phase.intro),
                    icon: const Icon(Icons.refresh),
                    label: const Text('撮り直す'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('レビューへ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroups() {
    final warn = hasSlotWarning(_assignments);
    final hero = _assignments.where((c) => c.slot == HandSlot.hero).toList();
    final board = _assignments
        .where(
          (c) =>
              c.slot == HandSlot.flop ||
              c.slot == HandSlot.turn ||
              c.slot == HandSlot.river,
        )
        .toList();
    final villainIndexes =
        _assignments
            .where((c) => c.slot == HandSlot.villain)
            .map((c) => c.villainIndex)
            .toSet()
            .toList()
          ..sort();
    final excluded = _assignments
        .where((c) => c.slot == HandSlot.exclude)
        .toList();

    return [
      if (warn)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
              SizedBox(width: 6),
              Expanded(child: Text('枚数が想定と違う行があります。役割を確認してください。')),
            ],
          ),
        ),
      _group('自分のハンド', hero),
      _group('場（フロップ→ターン→リバー）', board),
      for (final idx in villainIndexes)
        _group(
          '相手$idx',
          _assignments
              .where((c) => c.slot == HandSlot.villain && c.villainIndex == idx)
              .toList(),
        ),
      if (excluded.isNotEmpty) _group('除外', excluded),
    ];
  }

  Widget _group(String label, List<AssignedCard> cards) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          if (cards.isEmpty)
            const Text('—')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in cards) _cardCell(c)],
            ),
        ],
      ),
    );
  }

  Widget _cardCell(AssignedCard c) {
    final isRed = c.card.suit.isRed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            c.card.display,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isRed
                  ? Colors.red.shade600
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 76,
          child: DropdownButton<HandSlot>(
            value: c.slot,
            isDense: true,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodySmall,
            onChanged: (value) {
              if (value == null) return;
              setState(() => c.slot = value);
            },
            items: [
              for (final slot in HandSlot.values)
                DropdownMenuItem(value: slot, child: Text(slot.label)),
            ],
          ),
        ),
      ],
    );
  }
}
