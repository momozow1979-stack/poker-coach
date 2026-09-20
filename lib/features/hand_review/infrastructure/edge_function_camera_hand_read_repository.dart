import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/camera_hand_read_repository.dart';
import '../domain/read_hand_result.dart';

/// Supabase Edge Function `POST /read-hand`(Claude Vision)を呼ぶ実装。
///
/// 画像は base64 にして送る。APIキーは Edge Function 側のシークレットにあり、
/// アプリからは一切触らない。
class EdgeFunctionCameraHandReadRepository implements CameraHandReadRepository {
  const EdgeFunctionCameraHandReadRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ReadHandResult> read({
    required Uint8List imageBytes,
    required String mediaType,
  }) async {
    final res = await _client.functions.invoke(
      'read-hand',
      body: {'image_base64': base64Encode(imageBytes), 'media_type': mediaType},
    );
    final data = res.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        throw StateError('read-hand error: ${map['error']}');
      }
      return ReadHandResult.fromJson(map);
    }
    throw StateError('read-hand: 予期しないレスポンス形式です');
  }
}
