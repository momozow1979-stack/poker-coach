import '../../../shared/models/hand_strength.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/street.dart';
import '../../range_chart/domain/range_action.dart';
import '../../range_chart/domain/range_repository.dart';
import '../domain/board_texture.dart';
import '../domain/hand_flow.dart';
import '../domain/hand_read.dart';
import '../domain/hand_review_input.dart';
import '../domain/hand_review_repository.dart';
import '../domain/hand_review_result.dart';
import '../domain/solved_spot_repository.dart';

/// バックエンド接続前に使うローカル解析。
///
/// ここで出す数値は、すべてカードと入力額から確定するもの、または
/// [SolvedSpotRepository] にある実際に学習済みのスポットの実測値だけに限る。
/// それ以外のソルバーの頻度や EV は生成しない。
class MockHandReviewRepository implements HandReviewRepository {
  const MockHandReviewRepository(
    this._rangeRepository,
    this._solvedSpotRepository,
  );

  final RangeRepository _rangeRepository;
  final SolvedSpotRepository _solvedSpotRepository;

  @override
  Future<HandReviewResult> review(HandReviewInput input) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _solvedSpotRepository.ensureLoaded();
    return analyze(input);
  }

  /// テストからも呼べる同期版。
  HandReviewResult analyze(HandReviewInput input) {
    final flow = HandFlow(input);
    final notes = _Notes();
    var score = 72;

    score += _reviewPreflop(input, notes);
    score += _reviewStreets(input, flow, notes);
    score += _reviewPrices(input, flow, notes);

    if (notes.good.isEmpty) {
      notes.good.add(
        '最後まで自分のラインを決めて打ち切れています。'
        '判断の良し悪しより先に、ハンドを言葉にできていることが上達の入り口です。',
      );
    }
    final hasIssue = notes.improve.isNotEmpty;
    if (!hasIssue) {
      notes.improve.add(
        '大きな問題は見当たりません。'
        '次は同じ場面で「相手のレンジに何が残っているか」を口に出して確認してみてください。',
      );
    }

    return HandReviewResult(
      score: score.clamp(30, 97),
      summary: _summary(input, flow, notes.improve.first, hasIssue: hasIssue),
      goodPoints: notes.good,
      mainImprovement: notes.improve.first,
      streetAnalysis: _streetAnalysis(input, flow),
      gtoView: _gtoView(input),
      practicalAdjustment: _practicalAdjustment(input),
      alternativeLines: notes.alternatives.isEmpty
          ? const ['同じ場面でチェックを選んだ場合、相手の弱いハンドにブラフの余地を残せます。']
          : notes.alternatives,
      nextFocus: _nextFocus(notes.topics, notes.improve.first),
      relatedQuizTopics: notes.topics.toList(),
    );
  }

  // ------------------------------------------------------------- プリフロップ ----

  int _reviewPreflop(HandReviewInput input, _Notes notes) {
    if (input.heroHand.length != 2) return 0;
    final hand = StartingHand.fromCards(input.heroHand[0], input.heroHand[1]);
    final heroActions = input.preflop
        .where((action) => action.isHero)
        .toList(growable: false);
    if (heroActions.isEmpty) return 0;

    final first = heroActions.first;
    var delta = 0;

    // 誰も入っていないところへのコールはリンプ。
    final isLimp =
        first.action == PokerActionType.call && input.preflop.first.isHero;
    if (isLimp) {
      notes.topics.add('preflop');
      notes.improve.add(
        'プリフロップでリンプ（コールだけで参加）しています。'
        '${input.heroPosition.label} から入るなら、まずレイズで主導権を取る形に統一しましょう。'
        'リンプは、相手を降ろす機会と主導権の両方を捨てる動きです。',
      );
      notes.alternatives.add(
        '同じハンドで 2.5BB にレイズしていれば、'
        '後ろを降ろせる可能性が出るうえ、フロップ以降も自分から打てました。',
      );
      return delta - 8;
    }

    final chart = _rangeRepository.chartFor(
      input.tableType,
      input.heroPosition,
    );
    final recommended = chart?.entryFor(hand).action;
    if (recommended == null) return delta;

    final raised = first.action.isAggressive;
    if (raised) {
      switch (recommended) {
        case RangeAction.raise:
        case RangeAction.threeBet:
        case RangeAction.fourBet:
          notes.good.add(
            '${hand.code} は ${input.heroPosition.label} のレンジにきちんと入っているハンドです。'
            'プリフロップの入り方は問題ありません。',
          );
          delta += 6;
        case RangeAction.mixed:
          notes.good.add(
            '${hand.code} は ${input.heroPosition.label} では境界線上のハンドです。'
            'レイズ自体は間違いではありませんが、卓が荒れているときは外してかまいません。',
          );
        case RangeAction.call:
          notes.topics.add('preflop');
          notes.improve.add(
            '${hand.code} は ${input.heroPosition.label} では'
            'レイズよりコール寄りのハンドです。レンジ表で位置づけを確認しておきましょう。',
          );
          delta -= 4;
        case RangeAction.fold:
          notes.topics.addAll(['preflop', 'position']);
          notes.improve.add(
            '${hand.code} は ${input.heroPosition.label} のオープンレンジには入りません。'
            'ポジションが悪いほど参加ハンドを絞るのが基本です。'
            'ここを絞るだけで、フロップ以降の難しい判断がまとめて減ります。',
          );
          delta -= 10;
      }
    } else if (first.action == PokerActionType.call) {
      if (recommended == RangeAction.fold) {
        notes.topics.add('preflop');
        notes.improve.add(
          '${hand.code} で参加していますが、'
          '${input.heroPosition.label} からはレンジ外です。',
        );
        delta -= 8;
      } else if (recommended == RangeAction.raise) {
        notes.topics.add('preflop');
        notes.improve.add('${hand.code} はレイズできる強さです。コールで入ると主導権を渡してしまいます。');
        delta -= 5;
      } else {
        notes.good.add('${hand.code} でのコールは妥当な選択です。');
      }
    }
    return delta;
  }

  // ------------------------------------------------------------ ストリート ----

  int _reviewStreets(HandReviewInput input, HandFlow flow, _Notes notes) {
    var delta = 0;
    final texture = BoardTexture.of(input.board);
    if (texture == null) return delta;

    for (final street in [Street.flop, Street.turn, Street.river]) {
      final board = input.boardUpTo(street);
      if (board.length < 3) continue;
      final actions = input.actionsOf(street);
      if (actions.isEmpty) continue;

      final read = HandRead.of(input.heroHand, board);
      final heroActions = actions.where((action) => action.isHero);

      // 完成している強い手をリバーで打たずに終えた場合の取り逃し。
      if (street == Street.river &&
          read.strength.category.power >= HandCategory.twoPair.power) {
        final bet = heroActions.any((a) => a.action.isAggressive);
        final facedBet = actions.any((a) => !a.isHero && a.action.isAggressive);
        if (!bet && !facedBet) {
          notes.topics.add('value_bluff');
          notes.improve.add(
            'リバーで${read.label}を持ちながら、'
            '一度も自分から打っていません。'
            'この強さは、相手の弱い手から払ってもらうための手です。'
            '打たなければ、そのぶんは取り逃しになります。',
          );
          notes.alternatives.add(
            'リバーでポットの半分ほど打っていれば、'
            '相手の中途半端な手から追加で取れた可能性があります。',
          );
          delta -= 7;
        }
      }

      // 1ペア以下でスタックを大きく入れている場合。
      final wentAllIn = heroActions.any(
        (a) => a.action == PokerActionType.allIn,
      );
      if (wentAllIn &&
          read.strength.category.power <= HandCategory.onePair.power &&
          !read.hasDraw) {
        notes.topics.add('bet_sizing');
        notes.improve.add(
          '${street.label}で${read.label}のままオールインしています。'
          '1ペア以下は、相手に降りてもらうか、'
          '安く見せ合いに持ち込むかで価値を出す手です。'
          'スタック全部を賭けると、払ってくれるのは自分が負けている手だけになります。',
        );
        delta -= 8;
      }
    }

    // ベットサイズとボードの噛み合い。
    // 額が入っているときだけ、実際のポット比率で判断する。
    for (final bet in flow.heroBets) {
      if (bet.street == Street.preflop) continue;
      final board = input.boardUpTo(bet.street);
      final boardTexture = BoardTexture.of(board);
      if (boardTexture == null) continue;
      final percent = (bet.potFraction * 100).round();

      if (boardTexture.wetness == BoardWetness.dry && bet.potFraction >= 0.6) {
        notes.topics.add('bet_sizing');
        notes.improve.add(
          '${bet.street.label}の${boardTexture.wetness.label}ボードで、'
          'ポットの約$percent%を打っています。'
          'ドローの少ないボードでは、相手はそもそもあまり当たっていません。'
          '大きく打つと、払ってくれるはずの弱い手から先に降りてしまいます。',
        );
        final small = (bet.potBeforeBb / 3 * 2).round() / 2;
        notes.alternatives.add(
          '同じ場面でポットの3分の1ほど'
          '（${HandAction.formatBb(small)}BB）に落とすと、'
          '相手の弱い手を残したままプレッシャーをかけられます。',
        );
        delta -= 6;
      }

      if (boardTexture.wetness == BoardWetness.wet && bet.potFraction <= 0.4) {
        notes.topics.add('bet_sizing');
        notes.improve.add(
          '${bet.street.label}の${boardTexture.wetness.label}ボードで、'
          'ポットの約$percent%しか打っていません。'
          '相手のドローに安くカードを与えることになります。'
          '守るものがあるボードではサイズを上げます。',
        );
        final big = (bet.potBeforeBb * 0.75 * 2).round() / 2;
        notes.alternatives.add(
          '同じ場面でポットの4分の3ほど'
          '（${HandAction.formatBb(big)}BB）に上げると、'
          'ドローから見て割に合わない値段にできます。',
        );
        delta -= 6;
      }
    }

    // 仕掛けた回数の偏り。
    final heroPostflop = [
      ...input.flop.actions,
      ...input.turn.actions,
      ...input.river.actions,
    ].where((action) => action.isHero).toList(growable: false);

    final aggressive = heroPostflop.where((a) => a.action.isAggressive).length;
    if (heroPostflop.isNotEmpty && aggressive == 0) {
      notes.topics.add('value_bluff');
      notes.improve.add(
        'フロップ以降、一度も自分から仕掛けていません。'
        '相手のベットに合わせるだけだと、'
        '相手が打たなかった回のポットを取り逃します。',
      );
      delta -= 5;
    } else if (aggressive >= 2) {
      notes.good.add('複数のストリートで自分から仕掛けられています。ラインに一貫性があるのは良い点です。');
      delta += 4;
    }

    if (texture.isMonotone) {
      notes.topics.add('flop');
      notes.alternatives.add(
        'モノトーンのボードでは、'
        'フラッシュを持っていない側はポットを小さく保つラインも有力です。',
      );
    }
    if (texture.isHighCardBoard && input.heroPosition == Position.bb) {
      notes.topics.add('flop');
      notes.alternatives.add(
        'BB でハイカードのボードのときは、'
        'こちらのレンジが不利になりやすいのでチェックを厚めにするのが基本です。',
      );
    }

    return delta;
  }

  // -------------------------------------------------------------- 値段 ----

  /// ヒーローが直面したコールの値段を、必要勝率で検証する。
  int _reviewPrices(HandReviewInput input, HandFlow flow, _Notes notes) {
    var delta = 0;
    for (final faced in flow.heroFacedBets) {
      final board = input.boardUpTo(faced.street);
      if (board.length < 3) continue;

      final required = faced.requiredEquity;
      final equity = ExactEquity.between(
        hero: input.heroHand,
        villain: input.villainHand,
        board: board,
      );
      final percent = (required * 100).round();

      if (faced.chosen == PokerActionType.fold) {
        if (equity != null && equity.value > required) {
          notes.topics.add('pot_odds');
          notes.improve.add(
            '${faced.street.label}で '
            '${HandAction.formatBb(faced.toCallBb)}BB のコールを降りていますが、'
            '必要だった勝率は約$percent%でした。'
            '相手の手札から計算すると、この時点でのあなたの勝率は'
            '${equity.percent}%あったので、コールが正解でした。',
          );
          delta -= 8;
        } else if (required <= 0.25) {
          notes.topics.add('pot_odds');
          notes.improve.add(
            '${faced.street.label}で '
            '${HandAction.formatBb(faced.toCallBb)}BB のコールを降りています。'
            '必要な勝率は約$percent%と安い値段でした。'
            'この値段で降りる場面は、そう多くありません。',
          );
          delta -= 4;
        }
      } else if (faced.chosen == PokerActionType.call) {
        if (equity != null && equity.value >= required) {
          notes.good.add(
            '${faced.street.label}のコールは値段に合っていました。'
            '必要な勝率は約$percent%で、実際の勝率は${equity.percent}%でした。',
          );
          delta += 5;
        } else if (equity != null) {
          notes.topics.add('pot_odds');
          notes.improve.add(
            '${faced.street.label}のコールは値段に対して足りていませんでした。'
            '必要な勝率が約$percent%だったのに対し、'
            '相手の手札から計算した実際の勝率は${equity.percent}%です。',
          );
          delta -= 5;
        } else {
          // 相手の手札が分からないときは、値段だけを示して判断材料にしてもらう。
          final read = HandRead.of(input.heroHand, board);
          notes.good.add(
            '${faced.street.label}のコールに必要だった勝率は約$percent%です。'
            'そのときのあなたは${read.label}でした。'
            'この2つを毎回比べる癖がつくと、コールの判断がぶれなくなります。',
          );
        }
      }
    }
    return delta;
  }

  // ------------------------------------------------------------ 文章生成 ----

  String _summary(
    HandReviewInput input,
    HandFlow flow,
    String mainImprovement, {
    required bool hasIssue,
  }) {
    final head =
        '${input.heroPosition.label} からの${input.lastStreetLabel}までのハンドです。';
    final pot = flow.finalPotBb;
    final potPart = pot == null ? '' : '最終ポットは ${HandAction.formatBb(pot)}BB。';
    if (!hasIssue) {
      return '$head$potPart 目立った問題は見当たりません。'
          'この形は自信を持って同じように打って大丈夫です。';
    }
    return '$head$potPart ${mainImprovement.split('。').first}。'
        'ここを直すと、同じ形のハンドがまとめて良くなります。';
  }

  /// ストリートごとに「何を持っていて、いくらの判断だったか」を書く。
  Map<String, String> _streetAnalysis(HandReviewInput input, HandFlow flow) {
    final result = <String, String>{};

    result['preflop'] = input.preflop.isEmpty
        ? 'プリフロップのアクションが未入力です。'
        : 'アクション: ${input.preflop.join(' → ')}。'
              '${input.heroHand.length == 2 ? '${StartingHand.fromCards(input.heroHand[0], input.heroHand[1]).code} で参加しています。' : ''}';

    for (final street in [Street.flop, Street.turn, Street.river]) {
      final board = input.boardUpTo(street);
      final key = street.id;
      if (board.length < _boardSizeOf(street)) {
        result[key] = '${street.label}まで到達していません。';
        continue;
      }

      final lines = <String>[
        'ボード: ${board.map((card) => card.display).join(' ')}',
      ];

      if (input.heroHand.length == 2) {
        final read = HandRead.of(input.heroHand, board);
        lines.add('あなた: ${read.label}');
        if (read.draws.isNotEmpty) {
          lines.add('ドロー: ${read.draws.join('、')}');
        }
        if (read.improvingCards > 0) {
          final remaining = 52 - 2 - board.length;
          final chance = (read.improvingCards / remaining * 100).round();
          lines.add(
            'あと1枚でストレート以上になるカードは ${read.improvingCards} 枚'
            '（残り $remaining 枚のうち、次の1枚で当たる確率は約$chance%）',
          );
        }

        final equity = ExactEquity.between(
          hero: input.heroHand,
          villain: input.villainHand,
          board: board,
        );
        if (equity != null) {
          lines.add(
            'この時点での勝率: ${equity.percent}%'
            '（相手の ${input.villainHand.map((c) => c.display).join(' ')} に対して、'
            '残りのカードを全部数えた正確な値）',
          );
        }
      }

      final actions = input.actionsOf(street);
      lines.add(
        actions.isEmpty ? 'アクション未入力。' : 'アクション: ${actions.join(' → ')}',
      );

      for (final faced in flow.heroFacedBets.where(
        (bet) => bet.street == street,
      )) {
        lines.add(
          '${HandAction.formatBb(faced.toCallBb)}BB のコールに'
          '必要だった勝率: 約${(faced.requiredEquity * 100).round()}%'
          '（${HandAction.formatBb(faced.toCallBb)} ÷ '
          '${HandAction.formatBb(faced.potBb + faced.toCallBb)}）',
        );
      }

      result[key] = lines.join('\n');
    }

    if (input.villainHand.length == 2) {
      result['river'] =
          '${result['river']}\n\n'
          '※ 勝率は相手の手札が分かっているから出せる数字です。'
          'その場では見えていなかったので、'
          '「結果的にどうだったか」の確認に使ってください。';
    }

    return result;
  }

  static int _boardSizeOf(Street street) => switch (street) {
    Street.preflop => 0,
    Street.flop => 3,
    Street.turn => 4,
    Street.river => 5,
  };

  String _gtoView(HandReviewInput input) {
    final texture = BoardTexture.of(input.board);
    if (texture == null) {
      return 'プリフロップは、ポジションごとに決まったレンジからどれだけ外れていないかがすべてです。'
          'このアプリでは厳密な頻度は扱わず、覚えやすい目安だけを示します。';
    }

    if (input.heroHand.length == 2 && input.flop.cards.length == 3) {
      final matches = _solvedSpotRepository.firstFlopDecisionMatches(
        heroHand: input.heroHand,
        flopBoard: input.flop.cards,
      );
      if (matches.isNotEmpty) return _gtoViewFromSolvedSpots(matches);
    }

    final buffer = StringBuffer()
      ..write('このボードは${texture.wetness.label}に分類されます。')
      ..write('レンジ全体で見たときにどちら側が強いかを先に判断し、')
      ..write('有利な側は小さく高頻度、不利な側はチェックを厚く、という骨格で考えます。');
    if (texture.isMonotone) {
      buffer.write('3枚が同じスートなので、フラッシュを持てるかどうかが判断を大きく変えます。');
    } else if (texture.isPaired) {
      buffer.write('ボードがペアになっているぶん、どちらも当たりにくく、レンジ有利がそのまま効きます。');
    }
    buffer.write('正確なソルバーの頻度は入力から求まらないので、ここでは数値を示しません。');
    return buffer.toString();
  }

  /// 実際に CFR ソルバーで解いたスポットが見つかった場合の GTO 解説。
  ///
  /// 相手のレンジは「学習時に仮定したレンジ」であることを毎回明示する
  /// （実際の相手がそのレンジ通りとは限らないため）。複数のスポットが
  /// 一致した場合は、それぞれの仮定つきで全件を示す。
  String _gtoViewFromSolvedSpots(List<FlopDecisionMatch> matches) {
    final buffer = StringBuffer();
    for (final match in matches) {
      final checkPct = _percentOf(match.strategy, 'x');
      final betPct = _percentOf(match.strategy, 'b');
      buffer.write(
        '相手のレンジを ${match.villainRangeNotation} と仮定すると、'
        'このフロップでの最初の判断はチェック$checkPct%・ベット$betPct%という頻度です。'
        'CFR+で${match.iterationsTrained}回自己対戦させた実測値で、'
        '学習後に測定した厳密exploitability（0に近いほど正確）は'
        '${match.measuredExactExploitability}でした。',
      );
    }
    buffer.write('実際の相手のレンジがこの仮定と異なれば、正しい頻度も変わります。');
    return buffer.toString();
  }

  static int _percentOf(Map<String, double> strategy, String action) =>
      ((strategy[action] ?? 0) * 100).round();

  String _practicalAdjustment(HandReviewInput input) {
    return switch (input.villainProfile) {
      VillainProfile.tight =>
        '相手がタイトなので、ブラフの成功率が上がります。'
            '一方でコールしてきたときは本物であることが多いので、薄いバリューは減らします。',
      VillainProfile.loose =>
        '相手がルーズなので、バリューを厚く、ブラフを薄くします。'
            '相手のレンジが広いぶん、こちらの中程度のハンドの価値も上がります。',
      VillainProfile.passive =>
        '相手が受け身なので、相手からのベットは強さのサインとして重く見ます。'
            'こちらから仕掛ける回を増やすのが有効です。',
      VillainProfile.aggressive =>
        '相手が攻撃的なので、強いハンドでチェックして打たせる形が機能します。'
            'ブラフキャッチの基準も少し緩めてかまいません。',
      VillainProfile.unknown =>
        '相手の情報がないので、まずは標準的なラインを選ぶのが安全です。'
            '数ハンド観察して、降りやすいか / 降りにくいかだけでも掴んでおきましょう。',
    };
  }

  String _nextFocus(Set<String> topics, String mainImprovement) {
    if (topics.contains('pot_odds')) {
      return 'コールの前に「必要な勝率」を出す癖をつけましょう。'
          '払う額 ÷ 払ったあとのポット、の割り算だけです。'
          'この数字と自分の手の強さを比べれば、迷う場面がかなり減ります。';
    }
    if (topics.contains('preflop')) {
      return 'まずはプリフロップのレンジを固めましょう。'
          'レンジ表で自分のポジションを1つ選び、上下の境界だけ覚えるところから始めてください。';
    }
    if (topics.contains('bet_sizing')) {
      return 'ボードの質感とベットサイズの結びつきを練習しましょう。'
          '「ドライなら小さく、ウェットなら大きく」を基準として持っておくと迷いが減ります。';
    }
    if (topics.contains('value_bluff')) {
      return '「このベットはバリューかブラフか」を毎回言葉にしてから打つ練習をしましょう。';
    }
    return mainImprovement;
  }
}

/// レビュー生成中に集める材料。
class _Notes {
  final List<String> good = [];
  final List<String> improve = [];
  final List<String> alternatives = [];
  final Set<String> topics = {};
}
