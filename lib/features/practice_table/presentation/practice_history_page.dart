import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/practice_providers.dart';
import '../domain/practice_hand_record.dart';
import 'practice_replay_page.dart';

/// 保存済みの練習ハンドの一覧。
class PracticeHistoryPage extends ConsumerWidget {
  const PracticeHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(practiceHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('練習の履歴')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('読み込めませんでした: $error')),
        data: (records) => records.isEmpty
            ? const Center(child: Text('まだ練習したハンドがありません'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: records.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _HistoryTile(record: records[index]),
              ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final PracticeHandRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(record.title),
        subtitle: Text(
          'ポット ${record.finalPotBb}BB・${_formatDate(record.createdAt)}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PracticeReplayPage(record: record)),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
