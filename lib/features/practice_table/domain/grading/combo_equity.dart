import 'dart:math';

import '../../../../shared/models/fast_hand_evaluator.dart';
import '../../../../shared/models/playing_card.dart';

/// 相手の手札の候補 1 つずつに対する、ヒーローの勝率（引き分けは半分）。
class ComboEquities {
  const ComboEquities({
    required this.values,
    required this.isExact,
    required this.samplesPerCombo,
  });

  /// [values] の i 番目は、候補の i 番目に対する勝率（0.0〜1.0）。
  final List<double> values;

  /// 残りのボードをすべて数え上げた厳密な値か。
  ///
  /// フロップ以降は常に厳密。プリフロップだけは数え上げると重すぎる
  /// （相手の手札 1 通りにつき約 170 万通りのボード）ため、ランダムに
  /// 引いたボードで推定する。推定であることは画面に必ず明記する。
  final bool isExact;

  /// 推定のとき、相手の手札 1 通りあたりに試したボードの数。
  final int samplesPerCombo;

  /// 候補全体（すべて同じ確率）に対する勝率。
  double get mean =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  /// 推定のときの誤差の目安（平均の 2 標準誤差、0.0〜1.0）。厳密なら 0。
  double get margin {
    if (isExact || values.isEmpty) return 0;
    final p = mean.clamp(0.0, 1.0);
    final n = samplesPerCombo * values.length;
    return 2 * sqrt(p * (1 - p) / n);
  }

  /// [indexes] の候補だけに対する勝率。
  double meanOf(Iterable<int> indexes) {
    var sum = 0.0;
    var count = 0;
    for (final i in indexes) {
      sum += values[i];
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  /// プリフロップの推定で、ボード全体に使う試行回数の上限。
  static const int _preflopSampleBudget = 60000;
  static const int _preflopMinSamplesPerCombo = 300;

  static ComboEquities compute({
    required List<PlayingCard> hero,
    required List<PlayingCard> board,
    required List<List<PlayingCard>> combos,
  }) {
    final heroIdx = hero.map(FastHandEvaluator.indexOf).toList();
    final boardIdx = board.map(FastHandEvaluator.indexOf).toList();
    final used = {...heroIdx, ...boardIdx};
    final rest = [
      for (var card = 0; card < 52; card++)
        if (!used.contains(card)) card,
    ];

    if (board.isEmpty) {
      return _sampledPreflop(heroIdx, rest, combos);
    }
    final needed = 5 - board.length;
    final values = <double>[];

    // ランアウトを 2 枚までの組として平らに持つ（1 枚なら 2 枚目は -1）。
    final first = <int>[];
    final second = <int>[];
    for (final runout in _runouts(rest, needed)) {
      first.add(runout.isNotEmpty ? runout[0] : -1);
      second.add(runout.length > 1 ? runout[1] : -1);
    }

    // 7 枚の作業領域。先頭 2 枚を手札、続けてボード、最後にランアウトを入れる。
    final buffer = List<int>.filled(7, 0);
    for (var i = 0; i < boardIdx.length; i++) {
      buffer[2 + i] = boardIdx[i];
    }
    int scoreWith(int a, int b, int r0, int r1) {
      buffer[0] = a;
      buffer[1] = b;
      var n = 2 + boardIdx.length;
      if (r0 >= 0) buffer[n++] = r0;
      if (r1 >= 0) buffer[n++] = r1;
      return FastHandEvaluator.score(buffer);
    }

    // ヒーロー側の役はランアウトだけで決まる（相手の手札に依らない）ので、
    // 先に 1 回ずつ計算しておく。
    final heroScores = [
      for (var i = 0; i < first.length; i++)
        scoreWith(heroIdx[0], heroIdx[1], first[i], second[i]),
    ];

    for (final combo in combos) {
      final c0 = FastHandEvaluator.indexOf(combo[0]);
      final c1 = FastHandEvaluator.indexOf(combo[1]);
      var wins = 0.0;
      var total = 0;
      for (var i = 0; i < first.length; i++) {
        final r0 = first[i];
        final r1 = second[i];
        if (r0 == c0 || r0 == c1 || r1 == c0 || r1 == c1) continue;
        final heroScore = heroScores[i];
        final villainScore = scoreWith(c0, c1, r0, r1);
        if (heroScore > villainScore) {
          wins += 1;
        } else if (heroScore == villainScore) {
          wins += 0.5;
        }
        total++;
      }
      values.add(total == 0 ? 0 : wins / total);
    }
    return ComboEquities(values: values, isExact: true, samplesPerCombo: 0);
  }

  static ComboEquities _sampledPreflop(
    List<int> heroIdx,
    List<int> rest,
    List<List<PlayingCard>> combos,
  ) {
    if (combos.isEmpty) {
      return const ComboEquities(
        values: [],
        isExact: false,
        samplesPerCombo: _preflopMinSamplesPerCombo,
      );
    }
    final perCombo = max(
      _preflopMinSamplesPerCombo,
      _preflopSampleBudget ~/ combos.length,
    );
    // 同じ局面ならいつ開いても同じ数字が出るよう、手札から乱数の種を作る
    // （振り返り画面で数字が毎回変わると混乱するため）。
    final random = Random(heroIdx[0] * 52 + heroIdx[1]);
    final values = <double>[];
    for (final combo in combos) {
      final c0 = FastHandEvaluator.indexOf(combo[0]);
      final c1 = FastHandEvaluator.indexOf(combo[1]);
      final deck = [
        for (final card in rest)
          if (card != c0 && card != c1) card,
      ];
      var wins = 0.0;
      for (var s = 0; s < perCombo; s++) {
        // 部分的なフィッシャー–イェーツで 5 枚を引く。
        for (var i = 0; i < 5; i++) {
          final j = i + random.nextInt(deck.length - i);
          final tmp = deck[i];
          deck[i] = deck[j];
          deck[j] = tmp;
        }
        final runout = deck.sublist(0, 5);
        final heroScore = FastHandEvaluator.score([...heroIdx, ...runout]);
        final villainScore = FastHandEvaluator.score([c0, c1, ...runout]);
        if (heroScore > villainScore) {
          wins += 1;
        } else if (heroScore == villainScore) {
          wins += 0.5;
        }
      }
      values.add(wins / perCombo);
    }
    return ComboEquities(
      values: values,
      isExact: false,
      samplesPerCombo: perCombo,
    );
  }

  static Iterable<List<int>> _runouts(List<int> rest, int needed) sync* {
    switch (needed) {
      case 0:
        yield const [];
      case 1:
        for (final card in rest) {
          yield [card];
        }
      case 2:
        for (var i = 0; i < rest.length - 1; i++) {
          for (var j = i + 1; j < rest.length; j++) {
            yield [rest[i], rest[j]];
          }
        }
    }
  }
}
