import 'dart:typed_data';

import 'read_hand_result.dart';

/// テーブル写真1枚をカード読み取りにかける口。
///
/// 実装は Supabase Edge Function `POST /read-hand`(Claude Vision)経由。
/// APIキーはアプリに持たず、Edge Function のシークレットからのみ使う。
abstract interface class CameraHandReadRepository {
  Future<ReadHandResult> read({
    required Uint8List imageBytes,
    required String mediaType,
  });
}
