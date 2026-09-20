import 'dart:typed_data';

import '../../../shared/models/playing_card.dart';
import '../domain/camera_hand_read_repository.dart';
import '../domain/read_hand_result.dart';

/// Edge Function / APIキー無しで動かすためのダミー読み取り。
///
/// 端末やキーが未設定でも確認画面のUIを試せるよう、固定の結果を返す。
class MockCameraHandReadRepository implements CameraHandReadRepository {
  const MockCameraHandReadRepository();

  @override
  Future<ReadHandResult> read({
    required Uint8List imageBytes,
    required String mediaType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    ReadHandCard c(
      String code,
      ReadCardRole role, {
      int? order,
      int? cluster,
      double conf = 0.95,
    }) => ReadHandCard(
      card: PlayingCard.parse(code),
      confidence: conf,
      suggested: role,
      boardOrder: order,
      cluster: cluster,
    );
    return ReadHandResult(
      cards: [
        c('Ah', ReadCardRole.me, conf: 0.98),
        c('Js', ReadCardRole.me, conf: 0.96),
        c('Qs', ReadCardRole.board, order: 1),
        c('7d', ReadCardRole.board, order: 2),
        c('2c', ReadCardRole.board, order: 3),
        c('9h', ReadCardRole.board, order: 4),
        c('Ts', ReadCardRole.board, order: 5, conf: 0.9),
        c('Kd', ReadCardRole.villain, cluster: 1),
        c('Ks', ReadCardRole.villain, cluster: 1),
        c('8c', ReadCardRole.villain, cluster: 2),
        c('8d', ReadCardRole.villain, cluster: 2),
      ],
    );
  }
}
