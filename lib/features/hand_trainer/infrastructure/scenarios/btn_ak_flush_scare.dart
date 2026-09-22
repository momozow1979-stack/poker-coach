import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/villain_style.dart';
import '../../domain/trainer_scenario.dart';
import 'scenario_builder.dart';
import 'trainer_terms.dart';

/// 中級 / IP / 変化するボード。
///
/// トップペア・トップキッカーで2発打った後、リバーでフラッシュが完成。
/// 「安い値段でも、完成した相手のバリューが多すぎるなら降りる」規律を学ぶ。
/// ポット: open2.5→BB call(5.5)→flop bet3.5(12.5)→turn bet8(28.5)→
/// river はチェックに14ベットされ必要勝率 約25%。
final TrainerScenario btnAkFlushScare = buildScenario(
  id: 'tr014',
  title: 'BTNのAK、リバーでフラッシュが入ったら',
  goal:
      'トップペアで押した後、リバーでスケアカードが来たとき、'
      '値段だけでなく「相手の完成手の多さ」で降りを選べるようになります。',
  difficulty: TrainerDifficulty.intermediate,
  hero: Position.btn,
  villain: Position.bb,
  heroCards: 'Ah Ks',
  villainProfile: VillainStyles.reg,
  boardStyle: BoardStyle.dynamic,
  spots: [
    buildSpot(
      street: Street.preflop,
      potBb: 1.5,
      stackBb: 100,
      history: ['UTG〜COフォールド', 'あなた（BTN）の番です'],
      question: 'AKo です。残りは SB と BB。どうしますか？',
      hint: '最上位クラスのハンドで、しかも最も有利な席。迷う場面ではありません。',
      terms: [TrainerTerms.openRaise, TrainerTerms.ip],
      options: [
        best(
          'レイズ 2.5BB',
          reason:
              'AKo は BTN のオープンレンジの中でも上位。ポジションも最高で、'
              '主導権を持って戦えます。標準サイズで開きます。',
          ifChanged:
              '前の席から大きな3ベットが返ってくる相手なら、4ベットまで想定した'
              '組み立てに変わります。ここは全員降りているので素直に開きます。',
        ),
        bad(
          'フォールド',
          endsHand: true,
          reason:
              'AKo を BTN で降りる理由はありません。ここで降りると BTN で'
              '戦えるハンドがほぼ無くなります。',
          ifChanged: 'これよりはるかに弱いハンドなら降りが正解になります。',
        ),
        bad(
          'コール（リンプ）',
          reason:
              '強いハンドをリンプで入ると主導権を捨て、複数人を安く呼び込みます。'
              '開くならレイズに統一するのが基本です。',
          ifChanged: '複数人が既にリンプした特殊な卓なら成立する余地はあります。',
        ),
      ],
      outcome: 'SB フォールド、BB コール。ポットは 5.5BB になります。',
    ),
    buildSpot(
      street: Street.flop,
      newCards: 'Kd 9d 6c',
      potBb: 5.5,
      stackBb: 97.5,
      history: ['BB チェック'],
      question: 'トップペア・トップキッカー。ただし同スートが2枚あります。どうしますか？',
      hint:
          'ダイヤが2枚。相手のフラッシュドローやストレートドローに'
          '「安く引かせない」ことを考えます。',
      terms: [TrainerTerms.cbet, TrainerTerms.wetBoard, TrainerTerms.valueBet],
      options: [
        best(
          'ベット 3.5BB（約2/3ポット）',
          reason:
              'AK のトップペアは価値があり、かつボードにドローが多いので、'
              '少し大きめに打って相手のドローから料金を取りつつ守ります。',
          ifChanged:
              'ドローの無い乾いたボードなら、同じトップペアでも小さいサイズで'
              '広く打つ形に変わります。守るものがあるかでサイズは決まります。',
        ),
        bad(
          'チェック',
          reason:
              'ドローの多いボードでトップペアをチェックすると、相手に安く'
              'カードを見せてしまい、まくられるリスクを無料で与えます。',
          ifChanged:
              '自分のレンジにナッツ級が少なく、チェックで守りたい場面なら'
              'チェックも増えますが、TPTK 単体では打つほうが優れます。',
        ),
        bad(
          'ベット 1.5BB（小さすぎ）',
          reason:
              '小さすぎるとドローに割の良い値段を与えてしまい、'
              '守る目的を果たせません。ウェットな板では不足です。',
          ifChanged: '乾いた板なら小さいサイズが機能します。ここでは大きさが要ります。',
        ),
      ],
      outcome: 'BB がコール。ポットは 12.5BB になります。',
    ),
    buildSpot(
      street: Street.turn,
      newCards: '2s',
      potBb: 12.5,
      stackBb: 94,
      history: ['BB チェック'],
      question: 'ターンはブランク。まだトップペアです。どうしますか？',
      hint: 'ドローはまだ完成していません。「引かせない」ためにもう一発、が基本です。',
      terms: [TrainerTerms.valueBet, TrainerTerms.wetBoard],
      options: [
        best(
          'ベット 8BB（約2/3ポット）',
          reason:
              'まだドローが残っているので、2発目を打って料金を取り続けます。'
              '弱い K や引きかけの手からバリューを積み、フラッシュを安く'
              '完成させない狙いです。',
          ifChanged:
              '相手がターンでレイズしてきたら、完成した手や2ペアの可能性が上がり、'
              'AK1枚では引く判断も出てきます。',
        ),
        ok(
          'チェック',
          reason:
              'ポットを抑えてリバーを迎える判断も成立します。ただしドローが'
              '残っている以上、打って料金を取るほうが一歩上です。',
          ifChanged: '相手が受け身で、打っても弱い手が降りるだけなら、チェックの価値が上がります。',
        ),
        bad(
          'オールイン（94BB）',
          reason:
              'ポット 12.5BB にスタック 94BB を賭けるのは過大。トップペア1枚で'
              '勝っている相手を全部降ろし、負けている手にだけ払わせる形です。',
          ifChanged: 'スタックが浅ければオールインも現実的になります。SPR 次第です。',
        ),
      ],
      outcome: 'BB がコール。ポットは 28.5BB になります。',
    ),
    buildSpot(
      street: Street.river,
      newCards: 'Qd',
      potBb: 42.5,
      stackBb: 86,
      toCallBb: 14,
      history: ['あなたのチェックに、BB が 14BB ベット'],
      question: '3枚目のダイヤ（Q）でフラッシュが完成。相手から強いベットが来ました。どうしますか？',
      hint:
          '値段は安く見えます。でも「このベットに勝てている手がどれだけ残っているか」を'
          '先に考えてください。あなたはダイヤを持っていません。',
      terms: [
        TrainerTerms.potOdds,
        TrainerTerms.requiredEquity,
        TrainerTerms.blocker,
      ],
      options: [
        best(
          'フォールド',
          endsHand: true,
          reason:
              '14BB 払って最終ポット 56.5BB を取る形で、必要勝率は約25%です。'
              '一見安いですが、3枚目のダイヤでフラッシュが完成し、'
              'あなたはダイヤを1枚も持っていない（ブロッカー無し）ため、'
              '相手のベット範囲は完成フラッシュや2ペアに厚く寄ります。'
              'トップペア1枚では約25%に届かず、規律を持って降ります。',
          ifChanged:
              'あなたが A のダイヤなど強いブロッカーを持っていたり、相手が'
              'ブラフ過多のタイプなら、同じ約25%でもコールに変わります。',
        ),
        ok(
          'コール（14BB）',
          reason:
              '約25%で受けられる値段なので、相手がブラフ好きなら成立はします。'
              'ただしブロッカーが無く相手の完成手が多いこの場面では、'
              '平均的にはやや損に寄る受けです。',
          ifChanged:
              '相手が崩れたドローを必ず打ち切るタイプだと分かっているなら、'
              'この価格ではコールが正解になります。',
        ),
        bad(
          'レイズ',
          reason:
              'トップペアでレイズしても、払ってくれるのは完成フラッシュなど'
              'あなたが負けている手ばかり。ブラフにしても自分の手が強すぎて'
              'もったいなく、価値もブラフも取れません。',
          ifChanged: 'あなたがフラッシュやセットなら、レイズでバリューを伸ばせます。',
        ),
      ],
    ),
  ],
  takeaway:
      'このハンドの軸は「安い値段でも、相手の完成手が多いなら降りる」規律です。\n\n'
      'フロップ・ターンはドローが残っていたので、大きめに打って料金を取りました。\n'
      'リバーでフラッシュが完成し、しかも自分にブロッカーが無い——相手のベットに'
      '勝てている手が大きく減ったので、必要勝率 約25%でも降りが正解でした。\n\n'
      'tr013 の「降りすぎるな」と矛盾はしません。値段・ブロッカー・相手のライン、'
      'その3つを毎回見て「今日は受ける／今日は降りる」を切り替えるのがコツです。',
);
