import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/villain_style.dart';
import '../../domain/trainer_scenario.dart';
import 'scenario_builder.dart';
import 'trainer_terms.dart';

/// 中級 / IP / ドライ。
///
/// 中程度の強さの手（ミドルペア）で、ターンをチェックバックしてポットを抑え、
/// 安くショーダウンに向かう「ポット管理」を学ぶ。打ちすぎない技術。
/// ポット: open2.5→BB call(5.5)→flop bet2(9.5)→turn チェックバック→
/// river 相手3ベット・必要勝率 約19%で受ける。
final TrainerScenario btnPotControlCheckback = buildScenario(
  id: 'tr019',
  title: 'BTNのAT、ミドルペアの止めどき',
  goal:
      '中程度の手を「打ちすぎない」技術——ターンをチェックバックして'
      'ポットを抑え、安くショーダウンに向かう判断ができるようになります。',
  difficulty: TrainerDifficulty.intermediate,
  hero: Position.btn,
  villain: Position.bb,
  heroCards: 'Ac Td',
  villainProfile: VillainStyles.reg,
  boardStyle: BoardStyle.dry,
  spots: [
    buildSpot(
      street: Street.preflop,
      potBb: 1.5,
      stackBb: 100,
      history: ['UTG〜COフォールド', 'あなた（BTN）の番です'],
      question: 'ATs です。残りは SB と BB。どうしますか？',
      hint: 'BTN の好位置。ATs は十分オープンできる強さです。',
      terms: [TrainerTerms.openRaise, TrainerTerms.ip],
      options: [
        best(
          'レイズ 2.5BB',
          reason:
              'ATs は BTN のオープンレンジに十分入る強さ。好位置で主導権を取り、'
              '標準サイズで開きます。',
          ifChanged: '前の席から強い3ベットが多い相手なら、開くレンジ全体を少し締めます。',
        ),
        bad(
          'フォールド',
          endsHand: true,
          reason:
              'ATs を BTN で降りる理由はありません。ここで降りると BTN で戦える'
              '手が大きく減ります。',
          ifChanged:
              'これがもっと弱い手（A4o など）で、前に大きなレイズが入っているなら、'
              '降りが正解になります。',
        ),
        bad(
          'コール（リンプ）',
          reason:
              'リンプは主導権を捨てて複数人を安く呼び込みます。開くならレイズに'
              '統一するのが基本です。',
          ifChanged: '複数人が既にリンプした特殊卓なら成立の余地はあります。',
        ),
      ],
      outcome: 'SB フォールド、BB コール。ポットは 5.5BB になります。',
    ),
    buildSpot(
      street: Street.flop,
      newCards: 'Kd Ts 4c',
      potBb: 5.5,
      stackBb: 97.5,
      history: ['BB チェック'],
      question: 'ミドルペア（T）＋A キッカー。K ハイのボードです。どうしますか？',
      hint:
          'K ハイはレイズした側が有利なボード。小さく打って主導権を保ちつつ、'
          '中くらいの手の価値も少し取れます。',
      terms: [TrainerTerms.cbet, TrainerTerms.rangeAdvantage],
      options: [
        best(
          'ベット 2BB（約1/3ポット）',
          reason:
              'K ハイはレイズした側が K を多く持つ有利なボード。小さく打って'
              '相手の弱いハイカードを降ろしつつ、ミドルペアの薄い価値も取れます。',
          ifChanged:
              '相手のレンジが特にこの板に強い（BBが締まっている）なら、'
              'チェックを増やします。',
        ),
        ok(
          'チェック',
          reason:
              'ミドルペアでポットを抑えるチェックも成立します。ただし K ハイの'
              '有利な板では小さく打つほうが、価値と主導権を両取りできます。',
          ifChanged: '自分のレンジに弱い手が多くチェックで守りたいなら価値が上がります。',
        ),
        bad(
          'ベット 5BB（大きすぎ）',
          reason:
              'ミドルペアで大きく打つと、勝っている弱い手は降り、残るのは Kx など'
              'あなたが負けている手ばかり。中くらいの手には過大なサイズです。',
          ifChanged: 'あなたが Kx やセットなど強い手なら、大きいサイズが機能します。',
        ),
      ],
      outcome: 'BB がコール。ポットは 9.5BB になります。',
    ),
    buildSpot(
      street: Street.turn,
      newCards: '5h',
      potBb: 9.5,
      stackBb: 95.5,
      history: ['BB チェック'],
      question: 'ターンはブランク。ミドルペアのまま、相手はチェック。どうしますか？',
      hint:
          'ここで打つと、誰が払ってくれるかを考えてください。'
          'あなたに勝っている手ばかり残りませんか。',
      terms: [TrainerTerms.spr, TrainerTerms.potOdds],
      options: [
        best(
          'チェック（チェックバック）',
          reason:
              'ミドルペアで2発目を打っても、払ってくれるのは Kx やより強い Tx など'
              'あなたが負けている手が中心で、弱い手は降ります。ここはチェックで'
              'ポットを抑え、安くショーダウンに向かうのが得です。'
              'ポジションがあるので、無料でリバーを見られます。',
          ifChanged:
              '相手がとても受け身で、弱いペアからも払うステーションなら、'
              '薄い価値ベットの価値が上がります。',
        ),
        bad(
          'ベット 6BB',
          reason:
              'ミドルペアでのバレルは、勝っている相手を降ろし負けている相手に'
              '払わせる「逆」の形になりやすく、ポットも無駄に膨らみます。',
          ifChanged: 'あなたがトップペア以上や強いドローなら、ここで打つ価値が出ます。',
        ),
      ],
      outcome: 'あなたもチェック。無料でリバーを見て、ポットは 9.5BB のまま。',
    ),
    buildSpot(
      street: Street.river,
      newCards: '2s',
      potBb: 12.5,
      stackBb: 95.5,
      toCallBb: 3,
      history: ['BB が 3BB ベット（小さめ）'],
      question: 'リバーはブランク。相手から小さいベット。ミドルペアでどうしますか？',
      hint:
          '払う額はごくわずか。あなたのミドルペアが勝てている相手が'
          'どれだけいるかを考えます。',
      terms: [
        TrainerTerms.potOdds,
        TrainerTerms.requiredEquity,
        TrainerTerms.bluff,
      ],
      options: [
        best(
          'コール（3BB）',
          reason:
              '3BB 払って最終ポット 15.5BB を取る形で、必要勝率は約19%です。'
              '5回に1回勝てれば元が取れる安さ。ミドルペアでも、相手の空振りや'
              'より弱いペアに十分勝てるので、この価格ならコールします。'
              'ターンを抑えたおかげで、安くショーダウンできています。',
          ifChanged:
              '相手が小さいリバーベットをバリューにしか使わないタイプなら、'
              'フォールドが近づきます。',
        ),
        ok(
          'フォールド',
          endsHand: true,
          reason:
              '相手が受け身で小さいベットも強い手だけ、と分かっているなら'
              'ミドルペアを降りる判断も一応成立します。',
          ifChanged: '相手が積極的で薄いブラフを混ぜるなら、この価格ではコールが正解です。',
        ),
        bad(
          'レイズ',
          reason:
              'ミドルペアでレイズしても、払ってくれるのはあなたが負けている手'
              'ばかりで、ブラフには降りられるだけ。価値もブラフも取れません。',
          ifChanged: 'あなたがトップペア以上なら、レイズでの価値取りが視野に入ります。',
        ),
      ],
    ),
  ],
  takeaway:
      'このハンドの軸は「中くらいの手は打ちすぎず、安くショーダウンへ」です。\n\n'
      'フロップは有利な板で小さく打ちましたが、ターンはチェックバックして'
      'ポットを抑えました。ミドルペアで打ち続けると、勝っている手を降ろし'
      '負けている手に払う「逆」になりやすいからです。\n'
      'リバーは安い値段（必要勝率 約19%）で受け、薄い勝ちを拾いました。\n\n'
      'ポジションの一番の武器は「無料でカードを見られる」こと。中くらいの手は'
      'それを活かして、ポットを膨らませずに勝ちを拾うのがコツです。',
);
