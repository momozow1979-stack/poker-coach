import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../shared/models/playing_card.dart';
import '../domain/solved_spot.dart';
import '../domain/solved_spot_repository.dart';
import 'in_memory_solved_spot_repository.dart';

/// アプリに同梱した `assets/solved_spots/solved_spots.json`
/// （`solver/export_solved_spots.py` の出力）を読み込むリポジトリ。
///
/// バンドル済みファイルを読むだけなのでネットワーク待ちが無く、初回読み込み
/// 後は完全にメモリ内での参照になる。実際の検索は読み込み後に
/// [InMemorySolvedSpotRepository] へ委譲する。
class AssetSolvedSpotRepository implements SolvedSpotRepository {
  AssetSolvedSpotRepository({
    this.assetPath = 'assets/solved_spots/solved_spots.json',
  });

  final String assetPath;

  InMemorySolvedSpotRepository _delegate = const InMemorySolvedSpotRepository();
  Future<void>? _loading;
  bool _loaded = false;

  @override
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final spots = [
        for (final spot in json['spots'] as List)
          SolvedSpot.fromJson(spot as Map<String, dynamic>),
      ];
      _delegate = InMemorySolvedSpotRepository(spots);
    } on Exception {
      // 同梱データが壊れていても、既存の「数値は出さない」安全策に
      // フォールバックできるよう、空のまま扱う（例外を上に投げない）。
      _delegate = const InMemorySolvedSpotRepository();
    } finally {
      _loaded = true;
    }
  }

  @override
  List<FlopDecisionMatch> firstFlopDecisionMatches({
    required List<PlayingCard> heroHand,
    required List<PlayingCard> flopBoard,
  }) => _delegate.firstFlopDecisionMatches(
    heroHand: heroHand,
    flopBoard: flopBoard,
  );
}
