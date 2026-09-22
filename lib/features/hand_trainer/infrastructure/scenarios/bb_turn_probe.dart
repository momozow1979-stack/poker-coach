import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/villain_style.dart';
import '../../domain/trainer_scenario.dart';
import 'scenario_builder.dart';
import 'trainer_terms.dart';

/// 中級 / OOP / ドライ。
///
/// フロップで相手（PFR）がチェックバックして弱さを見せた後、ターンで自分から
/// リード（プローブ）して主導権を取り返す判断を学ぶ。
/// ポット: open2.5→BB call(5.5)→flop check-check→turn probe3(11.5)→river 薄いバリュー。
final TrainerScenario bbTurnProbe = buildScenario(
  id: 'tr018',
  title: 'BBのJT、相手がチェックバックしたら',
  goal:
      'フロップで相手が打たずに弱さを見せたとき、ターンで自分からリードして'
      '主導権を取り返す「プローブ」を使えるようになります。',
  difficulty: TrainerDifficulty.intermediate,
  hero: Position.bb,
  villain: Position.btn,
  heroCards: 'Jc Tc',
  villainProfile: VillainStyles.reg,
  boardStyle: BoardStyle.dry,
  spots: [
    buildSpot(
      street: Street.preflop,
      potBb: 4,
      stackBb: 100,
      toCallBb: 1.5,
      history: ['BTN が 2.5BB オープン', 'SB フォールド', 'あなた（BB）の番です'],
      question: 'JTs（スーテッド）です。BTN のオープンにどうしますか？',
      hint: 'JTs はコネクターで後々伸びやすい手。安く受けられる価格かを見ます。',
      terms: [TrainerTerms.potOdds, TrainerTerms.requiredEquity],
      options: [
        best(
          'コール（1.5BB）',
          reason:
              '追加1.5BBで受けられる安い価格（必要勝率 約27%）。JTs は伸びしろが'
              '大きく、この価格ならディフェンスして問題ありません。',
          ifChanged:
              '相手が UTG の激タイトなオープンなら、価値が下がるので'
              'ディフェンス頻度を落とします。',
        ),
        ok(
          '3ベット',
          reason:
              'JTs をブラフ寄りの3ベットに回すのも成立します。ただし OOP の3ベットは'
              '扱いづらく、この価格ならまずコールで安く受けるのが素直です。',
          ifChanged: '相手が3ベットに過剰フォールドするなら、3ベットの価値が上がります。',
        ),
        bad(
          'フォールド',
          endsHand: true,
          reason:
              '約27%で受けられ、伸びしろも大きい JTs を降りるのはもったいない。'
              'BB は安く受けられる席です。',
          ifChanged:
              'これがずっと弱い手（J4o など）で、しかも相手のレイズが大きいなら、'
              '降りが正解になります。',
        ),
      ],
      outcome: 'BTN がコール。ポットは 5.5BB になります。',
    ),
    buildSpot(
      street: Street.flop,
      newCards: 'Jd 7s 2c',
      potBb: 5.5,
      stackBb: 97.5,
      history: ['あなた（BB）から先に action です'],
      question: 'トップペア（J）です。OOP のあなたはどうしますか？',
      hint:
          '基本、BB はレイズした側（PFR）にまずチェックで渡します。'
          '相手がどう出るかで、次の一手が決まります。',
      terms: [TrainerTerms.oop, TrainerTerms.cbet],
      options: [
        best(
          'チェック',
          reason:
              'OOP では、まずレイズした側にアクションを渡すのが基本の型です。'
              '相手が打てば受ける・降ろす判断、チェックバックなら次で主導権を'
              '取り返す、と分岐を作れます。',
          ifChanged:
              '自分のレンジが特に強い特定のボードでは、OOPから自分でリード'
              '（ドンク）する戦略もありますが、標準ボードでは基本チェックです。',
        ),
        ok(
          'ドンクベット 2BB',
          reason:
              '自分から打つ選択も一応成立しますが、通常ボードでドンクを多用すると'
              'レンジが読まれやすく、まずチェックで様子を見るほうが素直です。',
          ifChanged:
              '自分だけが持てる強い手が多いボード（低い連結など）なら、'
              'ドンクの価値が上がります。',
        ),
      ],
      outcome: 'BTN もチェック。相手は弱さを見せ、ポットは 5.5BB のままターンへ。',
    ),
    buildSpot(
      street: Street.turn,
      newCards: '5d',
      potBb: 5.5,
      stackBb: 97.5,
      history: ['あなた（BB）から先に action です'],
      question: '相手はフロップを打ちませんでした。ターンでトップペアのあなたはどうしますか？',
      hint:
          '相手がフロップを諦めた＝強い手が少ない、というサイン。'
          'ここで自分から打って主導権を取り返せます。',
      terms: [TrainerTerms.valueBet, TrainerTerms.rangeCap],
      options: [
        best(
          'プローブベット 3BB（約1/2ポット）',
          reason:
              '相手はフロップをチェックバックして「強い手が少ない」ことを示しました。'
              'トップペアのあなたが自分から打てば、弱いペアやハイカードから'
              '価値を取り、主導権も取り返せます。',
          ifChanged:
              '相手が「チェックバックからのチェックレイズ」を仕込むタイプなら、'
              'プローブは慎重にします。多くの相手にはそのまま打って得です。',
        ),
        ok(
          'チェック',
          reason:
              'もう一度チェックして様子を見る選択も成立しますが、相手が弱い今こそ'
              '価値を取りにいくべきで、チェックはチャンスを逃しやすいです。',
          ifChanged: '自分の手が弱く見せ札にしかならないなら、チェックのほうが良い場面もあります。',
        ),
      ],
      outcome: 'BTN がコール。ポットは 11.5BB になります。',
    ),
    buildSpot(
      street: Street.river,
      newCards: '8h',
      potBb: 11.5,
      stackBb: 94.5,
      history: ['あなた（BB）から先に action です'],
      question: 'リバーはブランク。まだトップペアです。最後の一手は？',
      hint:
          'まだ相手の弱いペアから払ってもらえます。「誰が払うか」を考えて'
          'サイズを決めます。',
      terms: [TrainerTerms.valueBet],
      options: [
        best(
          'ベット 4BB（薄めの価値）',
          reason:
              'トップペアは、相手の弱いペア（7x・小ペア）や意地のブラフキャッチから'
              'まだ払ってもらえます。小さめに打って薄く価値を取りにいきます。',
          ifChanged:
              '相手が「リバーは強い手にしか払わない」タイプなら、チェックで'
              'ショーダウンに回るほうが良くなります。',
        ),
        ok(
          'チェック',
          reason:
              'ショーダウンで勝ちにいくチェックも成立します。ただし弱いペアから'
              '薄く取れる場面なので、小さく打つほうが一歩上です。',
          ifChanged: '相手が受け身でまず払わないなら、チェックのほうが損をしません。',
        ),
        bad(
          'ベット 11BB（大きすぎ）',
          reason:
              '大きく打つと、払ってくれるはずの弱いペアが降り、残るのは'
              'あなたに勝っている手ばかり。薄い価値ベットには大きすぎます。',
          ifChanged: 'あなたが2ペア以上の強い手なら、大きいサイズが正解に近づきます。',
        ),
      ],
    ),
  ],
  takeaway:
      'このハンドの軸は「相手が弱さを見せたら、ターンで主導権を取り返す（プローブ）」です。\n\n'
      'フロップはOOPの型どおりチェックで相手に渡し、相手がチェックバックして'
      '弱さを見せた瞬間に、ターンから自分でリードして価値を取りにいきました。\n\n'
      '「OOPは常に受け身」ではありません。相手が諦めたサインを見たら、'
      '自分から打って主導権とポットを取り返すのがコツです。',
);
