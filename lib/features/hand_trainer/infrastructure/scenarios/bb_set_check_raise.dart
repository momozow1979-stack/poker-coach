import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/villain_style.dart';
import '../../domain/trainer_scenario.dart';
import 'scenario_builder.dart';
import 'trainer_terms.dart';

/// 中級 / OOP / ウェット。
///
/// フロップでセットを引いたが、ドローの多いボード。スロープレイではなく
/// チェックレイズで「価値＋守り」を同時に取りにいく判断を学ぶ。
/// ポット: open2.5→BB call(5.5)→flop 相手3.5c-bet(必要勝率約28%)→
/// CR13でcall(31.5)→turn bet21(73.5)→river value bet。
final TrainerScenario bbSetCheckRaise = buildScenario(
  id: 'tr016',
  title: 'BBの66、ドローボードでセットを引いたら',
  goal:
      'ウェットなボードでセットを引いたとき、スロープレイに逃げず'
      'チェックレイズで価値と守りを同時に取る判断ができるようになります。',
  difficulty: TrainerDifficulty.intermediate,
  hero: Position.bb,
  villain: Position.btn,
  heroCards: '6c 6d',
  villainProfile: VillainStyles.reg,
  boardStyle: BoardStyle.wet,
  spots: [
    buildSpot(
      street: Street.preflop,
      potBb: 4,
      stackBb: 100,
      toCallBb: 1.5,
      history: ['BTN が 2.5BB オープン', 'SB フォールド', 'あなた（BB）の番です'],
      question: '66 です。BTN のオープンにどうしますか？',
      hint: '小さいペアは「セットを引いて大きく勝つ」ために安く見にいく手。値段を見ます。',
      terms: [TrainerTerms.potOdds, TrainerTerms.requiredEquity],
      options: [
        best(
          'コール（1.5BB）',
          reason:
              '追加1.5BBで受けられる安い価格（必要勝率 約27%）。66 は3ベットには'
              '向かないぶん、コールで安く見て「セットを引いたら大きく取る」手です。',
          ifChanged: '相手がとても降りやすいなら、たまにブラフ3ベットに回す選択も出ます。',
        ),
        bad(
          'フォールド',
          endsHand: true,
          reason:
              '約27%で受けられ、セット時の爆発力もある 66 を降りるのはもったいない。'
              'BB は安く受けられる席です。',
          ifChanged: 'これがもっと弱い手や、相手のレイズが極端に大きいなら降りもあります。',
        ),
        bad(
          '3ベット',
          reason:
              '66 で3ベットしても、コールされると弱いオーバーカードのボードに'
              'なりやすく扱いづらい。ここはコールで安く受けるのが素直です。',
          ifChanged: '相手が3ベットに過剰フォールドするなら、ブラフ3ベットの価値が上がります。',
        ),
      ],
      outcome: 'BTN がコール。ポットは 5.5BB になります。',
    ),
    buildSpot(
      street: Street.flop,
      newCards: '9h 6s 2h',
      potBb: 9,
      stackBb: 97.5,
      toCallBb: 3.5,
      history: ['あなた（BB）チェック', 'BTN が 3.5BB ベット'],
      question: 'セット（666）を引きました。ただしハートが2枚。どうしますか？',
      hint:
          'ドローの多いボードです。ゆっくり隠すより、今ポットを大きくして'
          '相手のドローから料金を取ることを考えます。',
      terms: [
        TrainerTerms.checkRaise,
        TrainerTerms.wetBoard,
        TrainerTerms.valueBet,
      ],
      options: [
        best(
          'チェックレイズ 13BB',
          reason:
              'セットは最強クラス。ドローが多い板では、チェックレイズで今のうちに'
              'ポットを膨らませ、フラッシュドローなどから料金を取りつつ守ります。'
              'スタックを積み上げてリバーの大きな勝ちに繋げます。',
          ifChanged:
              '乾いた板で相手にドローが少ないなら、あえてコールで隠して'
              'ターン以降に払わせるスロープレイの価値が上がります。',
        ),
        ok(
          'コール（3.5BB）',
          reason:
              'コールで受けるスロープレイも一応成立（約28%どころか大幅に上回る勝率）。'
              'ただしドローの多い板では、安くカードを見せてまくられるリスクがあり、'
              'チェックレイズで守りながら価値を取るほうが上です。',
          ifChanged:
              '相手がアグレッシブで、こちらがコールするとターンも撃ってくるタイプなら、'
              'コールで泳がせる価値が上がります。',
        ),
        bad(
          'フォールド',
          endsHand: true,
          reason:
              'セットを降りるのは論外です。この板でほぼ最強のハンドを捨てることに'
              'なります。',
          ifChanged: '降りが正解になるのは、これがずっと弱い手のときだけです。',
        ),
      ],
      outcome: 'BTN がコール。ポットは 31.5BB になります。',
    ),
    buildSpot(
      street: Street.turn,
      newCards: '2c',
      potBb: 31.5,
      stackBb: 84.5,
      history: ['あなた（BB）から先に action です'],
      question: 'ボードがペアになり、あなたはフルハウス（6と2）に。どうしますか？',
      hint: 'もう相手にほぼ勝てません。あとは「いかに多く払わせるか」だけです。',
      terms: [TrainerTerms.valueBet],
      options: [
        best(
          'ベット 21BB（約2/3ポット）',
          reason:
              'フルハウスでほぼ最強。相手のフラッシュ完成やトップペアから最大限'
              '払わせるため、大きめに打って価値を積みます。',
          ifChanged:
              '相手が受け身で大きいベットに降りるタイプなら、サイズを少し落として'
              '払える範囲を残す調整もあります。',
        ),
        ok(
          'チェック',
          reason:
              'チェックで相手に撃たせる作戦も一応成立しますが、フルハウスの'
              '価値を取り逃すリスクがあり、自分から打つほうが素直に得です。',
          ifChanged:
              '相手がアグレッシブでチェックに必ず撃ってくるなら、チェックで'
              '誘う価値が上がります。',
        ),
      ],
      outcome: 'BTN がコール。ポットは 73.5BB になります。',
    ),
    buildSpot(
      street: Street.river,
      newCards: 'Kd',
      potBb: 73.5,
      stackBb: 63.5,
      history: ['あなた（BB）から先に action です'],
      question: 'リバーはブランク。フルハウスのまま、最後の1発をどうしますか？',
      hint: 'ほぼ確実に勝っています。残りスタックをどう取り切るかだけを考えます。',
      terms: [TrainerTerms.valueBet, TrainerTerms.nuts],
      options: [
        best(
          'ベット 45BB（大きめの価値ベット）',
          reason:
              'ほぼ最強のフルハウス。相手のフラッシュや弱いフルハウス、意地の'
              'ブラフキャッチから最大限に取りにいくため、大きく打ちます。',
          ifChanged:
              '相手が「大きいと降りるが小さいと払う」タイプなら、サイズを落として'
              '確実に払わせる調整もあります。',
        ),
        ok(
          'チェック',
          reason:
              '相手にブラフを打たせる誘いも成立はしますが、最強クラスの手で'
              '自分から取りにいかないのは、期待値をわざわざ捨てる行為に近いです。',
          ifChanged:
              '相手が「チェックされると必ず打つ」タイプなら、チェックで誘って'
              'より多く取れることがあります。',
        ),
      ],
    ),
  ],
  takeaway:
      'このハンドの軸は「ウェットな板でセットを引いたら、隠すより攻める」です。\n\n'
      'ドローの多いフロップでは、チェックレイズで今のうちにポットを膨らませ、'
      '相手のドローから料金を取りつつ守るのが基本でした。\n'
      'ターンでフルハウスに伸び、あとは毎ストリート大きく打って価値を最大化しました。\n\n'
      '「強い手ほどゆっくり」ではありません。ボードが濡れているほど、'
      '強い手は早く・大きく打って料金を取り、まくられる隙を消すのがコツです。',
);
