import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/villain_style.dart';
import '../../domain/trainer_scenario.dart';
import 'scenario_builder.dart';
import 'trainer_terms.dart';

/// 上級 / OOP / ドライ・3ベットポット。
///
/// 3ベットポットは SPR が低く、オーバーペアは自然とコミット（差し切り）方向。
/// 低いドライボードで価値を積み、オーバーカードのリバーでも安い値段なら受け切る。
/// ポット: BTN open2.5→BB 3bet11→BTN call(22.5)→flop bet15(52.5)→
/// turn bet26(104.5)→river ジャム48・必要勝率 約24%。
final TrainerScenario bbQqThreeBetPot = buildScenario(
  id: 'tr015',
  title: 'BBのQQ、3ベットポットの差し切り',
  goal:
      '3ベットポット（低SPR）で、オーバーペアをどこまでコミットして良いかを、'
      'スタックとポットの比から判断できるようになります。',
  difficulty: TrainerDifficulty.advanced,
  hero: Position.bb,
  villain: Position.btn,
  heroCards: 'Qh Qs',
  villainProfile: VillainStyles.reg,
  boardStyle: BoardStyle.dry,
  spots: [
    buildSpot(
      street: Street.preflop,
      potBb: 4,
      stackBb: 100,
      toCallBb: 1.5,
      history: ['BTN が 2.5BB オープン', 'SB フォールド', 'あなた（BB）の番です'],
      question: 'QQ です。BTN のオープンにどう応じますか？',
      hint: 'QQ は最上位クラス。ただ受けるだけでなく、主導権を取る手段があります。',
      terms: [TrainerTerms.threeBetPot, TrainerTerms.spr],
      options: [
        best(
          '3ベット 11BB',
          reason:
              'QQ は3ベットでバリューを膨らませられる強さ。3ベットして'
              'ポットとレンジ主導権を取り、SPRを下げて差し切りやすくします。',
          ifChanged:
              '相手が4ベットを頻繁に返す激アグレなら、QQ でも一旦コールで受けて'
              'ポットを膨らませすぎない選択が出てきます。',
        ),
        ok(
          'コール',
          reason:
              'コールなら追加1.5BBで受けられる安い価格（必要勝率 約27%）ですが、'
              'OOPで主導権を渡すぶんフロップ以降が難しくなります。'
              'QQ なら3ベットで主導権を取るのが素直です。',
          ifChanged: 'スタックが極端に深い場合は、コールでポットを抑える価値が上がります。',
        ),
        bad(
          'フォールド',
          endsHand: true,
          reason:
              'QQ を降りる理由はまったくありません。最上位クラスのハンドで、'
              'ここで降りると BB で戦える手がほぼ無くなります。',
          ifChanged: 'これよりずっと弱い手（Q7o など）なら、降りが正解になります。',
        ),
      ],
      outcome: 'BTN がコール。3ベットポットになり、ポットは 22.5BB です。',
    ),
    buildSpot(
      street: Street.flop,
      newCards: 'Ts 6d 2c',
      potBb: 22.5,
      stackBb: 89,
      history: ['あなた（BB）から先に action です'],
      question: 'エースの無い低いボード。QQ はオーバーペアです。どうしますか？',
      hint:
          'このボードで QQ に勝っている手は多くありません。SPR も低く、'
          'ここから差し切る前提で組み立てます。',
      terms: [TrainerTerms.cbet, TrainerTerms.valueBet, TrainerTerms.spr],
      options: [
        best(
          'ベット 15BB（約2/3ポット）',
          reason:
              'A が無くQQがほぼ最強のボード。低SPRなので、しっかり打って'
              'Tx やドローから価値を取り、ターン・リバーでの差し切りに繋げます。',
          ifChanged:
              'A や K が絡む板なら相手のトップペアが増え、サイズや頻度を落とします。'
              'ここは怖いカードが無いので強く打てます。',
        ),
        ok(
          'チェック',
          reason:
              '相手のブラフを誘うチェックも一応成立しますが、価値のあるオーバーペアを'
              '低SPRで寝かせるのはもったいなく、素直に打つほうが得です。',
          ifChanged: '自分のレンジに弱い手が多くチェックで守りたい場面なら価値が上がります。',
        ),
        bad(
          'ベット 6BB（小さすぎ）',
          reason:
              '低SPRで差し切りたいのに小さく打つと、リバーまでにスタックを'
              '入れ切れず、ドローに安く引かせることにもなります。',
          ifChanged: 'ハイSPRの単発ポットなら小さいサイズも選択肢になります。',
        ),
      ],
      outcome: 'BTN がコール。ポットは 52.5BB になります。',
    ),
    buildSpot(
      street: Street.turn,
      newCards: '7h',
      potBb: 52.5,
      stackBb: 74,
      history: ['あなた（BB）から先に action です'],
      question: 'ターンはほぼブランク。QQ はまだオーバーペアです。どうしますか？',
      hint: '残りスタックとポットを見てください。もう1発でほぼ差し切れる比率です。',
      terms: [TrainerTerms.valueBet, TrainerTerms.spr],
      options: [
        best(
          'ベット 26BB（約1/2ポット）',
          reason:
              'まだ QQ が優勢で、SPRも低い。2発目を打ってリバーの差し切りへ'
              '繋げます。弱い Tx やドローから価値を取り続けられます。',
          ifChanged:
              '相手がターンでレイズしてきたら、セットや2ペアの可能性が上がり、'
              'QQ でも一度立ち止まる判断が出てきます。',
        ),
        ok(
          'チェック',
          reason:
              'ポットを抑える選択も一応成立しますが、優勢なオーバーペアで'
              'わざわざ止める理由は薄く、打って価値を積むほうが上です。',
          ifChanged: '相手が受け身でベットに一切乗ってこないなら、チェックの価値が上がります。',
        ),
      ],
      outcome: 'BTN がコール。ポットは 104.5BB になります。',
    ),
    buildSpot(
      street: Street.river,
      newCards: 'Kc',
      potBb: 152.5,
      stackBb: 48,
      toCallBb: 48,
      history: ['あなたのチェックに、BTN が残り 48BB をオールイン'],
      question: 'リバーで K が落ち、相手がオールイン。QQ は K の下になりました。どうしますか？',
      hint: 'ここまで自分から2発打ち込んでいます。残すポットと払う額の比を見てください。',
      terms: [TrainerTerms.potOdds, TrainerTerms.requiredEquity],
      options: [
        best(
          'コール（48BB）',
          reason:
              '48BB 払って最終ポット 200.5BB を取る形で、必要勝率は約24%です。'
              '4回に1回強で元が取れます。K で一部の手には負けますが、相手のレンジには'
              '崩れたドローや弱い Tx・ブラフも多く残り、QQ はそれらに勝っています。'
              'ここまでコミットした以上、この価格なら受け切ります。',
          ifChanged:
              '相手が「オールインは本物だけ」の激タイトなら降りに寄ります。'
              '相手のブラフ頻度が結論を分けます。',
        ),
        ok(
          'フォールド',
          endsHand: true,
          reason:
              '相手が受け身で、リバージャムに絶対ブラフを入れないと分かっているなら、'
              'K の下になった QQ を降りる判断も成立します。',
          ifChanged: '相手が積極的で崩れたドローを押し切るタイプなら、この価格ではコールです。',
        ),
      ],
    ),
  ],
  takeaway:
      'このハンドの軸は「3ベットポットは SPR が低く、強いオーバーペアは差し切り前提」です。\n\n'
      '低いドライボードで QQ はほぼ最強だったので、しっかり2発打って価値を積みました。\n'
      'リバーで K が落ちても、必要勝率 約24%という安い価格と、相手に残るブラフの多さから'
      '受け切りが正解でした。\n\n'
      '低SPRでは「毎ストリートいくら残るか」を先に見て、コミットするかを最初から'
      '設計しておくと、リバーで迷いません。',
);
