import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/villain_style.dart';
import '../../domain/trainer_scenario.dart';
import 'scenario_builder.dart';
import 'trainer_terms.dart';

/// 中級 / IP / ドライ。
///
/// トップセットで迎えたドライな最終盤面。ほぼ最強かつ相手のレンジが「そこそこ強いが
/// 最強ではない」手に偏るとき、オーバーベット（ポット超えの大きさ）で最大限に取る。
/// ポット: open2.5→BB call(5.5)→flop bet3.5(12.5)→turn bet8(28.5)→river オーバーベット。
final TrainerScenario btnSetOverbet = buildScenario(
  id: 'tr017',
  title: 'BTNのAA、リバーのオーバーベット',
  goal:
      'ほぼ最強の手で、相手が「強いが最強ではない」手に偏る盤面のとき、'
      'オーバーベットで価値を最大化する判断ができるようになります。',
  difficulty: TrainerDifficulty.intermediate,
  hero: Position.btn,
  villain: Position.bb,
  heroCards: 'Ah Ad',
  villainProfile: VillainStyles.reg,
  boardStyle: BoardStyle.dry,
  spots: [
    buildSpot(
      street: Street.preflop,
      potBb: 1.5,
      stackBb: 100,
      history: ['UTG〜COフォールド', 'あなた（BTN）の番です'],
      question: 'AA です。残りは SB と BB。どうしますか？',
      hint: '最強のスターティングハンド。BTN で主導権を取ります。',
      terms: [TrainerTerms.openRaise, TrainerTerms.ip],
      options: [
        best(
          'レイズ 2.5BB',
          reason:
              'AA は最強の手。BTN からレイズして主導権を取り、ポストフロップを'
              '有利に進めます。標準サイズで開きます。',
          ifChanged: '相手が3ベット多用なら、4ベットで大きく育てる組み立てに変わります。',
        ),
        bad(
          'コール（リンプ）',
          reason:
              '最強の手をリンプで隠すと主導権と価値を両方取り逃します。'
              'AA は素直にレイズして育てます。',
          ifChanged: '複数人が既にリンプした特殊卓なら、後追いリンプの余地はあります。',
        ),
        bad(
          'フォールド',
          endsHand: true,
          reason:
              'AA は 169 種類で最強のスターティングハンド。ここで降りる理由は'
              '一切なく、参加しないと勝ちようがありません。',
          ifChanged:
              'AA を降りる状況は現実には存在しません。どんなに弱い相手でも'
              '最強の手はプレーします。',
        ),
      ],
      outcome: 'SB フォールド、BB コール。ポットは 5.5BB になります。',
    ),
    buildSpot(
      street: Street.flop,
      newCards: 'Ac 8d 3s',
      potBb: 5.5,
      stackBb: 97.5,
      history: ['BB チェック'],
      question: 'トップセット（AAA）です。乾いたボード。どうしますか？',
      hint: 'ほぼ最強。ドローも無い板なので、価値を取ることだけを考えます。',
      terms: [TrainerTerms.cbet, TrainerTerms.valueBet, TrainerTerms.dryBoard],
      options: [
        best(
          'ベット 3.5BB（約2/3ポット）',
          reason:
              'トップセットは最強クラス。乾いた板でも、相手の A や 8・ポケットペアから'
              '少しずつ払わせるため、素直に価値ベットします。育てて後の大きな一撃に繋げます。',
          ifChanged: '相手がとても受け身なら、チェックで1回撃たせてから取る調整も一応あります。',
        ),
        ok(
          'チェック',
          reason:
              '相手のブラフを誘うチェックも成立はしますが、乾いた板では素直に'
              '打ってポットを育てるほうが分かりやすく得です。',
          ifChanged: '自分のレンジに弱い手が多くチェックで守りたい場面なら価値が上がります。',
        ),
        bad(
          'オールイン（97.5BB）',
          reason:
              'ポット 5.5BB にスタック丸ごとは過大。相手のほぼ全員が降り、'
              'せっかくの最強手で小さいポットしか取れません。',
          ifChanged: 'スタックが極端に浅ければ、早いオールインも現実的になります。',
        ),
      ],
      outcome: 'BB がコール。ポットは 12.5BB になります。',
    ),
    buildSpot(
      street: Street.turn,
      newCards: '2c',
      potBb: 12.5,
      stackBb: 94,
      history: ['BB チェック'],
      question: 'ターンはブランク。まだトップセットです。どうしますか？',
      hint: 'ボードは相変わらず乾いていて、あなたはほぼ最強。価値を積み続けます。',
      terms: [TrainerTerms.valueBet],
      options: [
        best(
          'ベット 8BB（約2/3ポット）',
          reason:
              'まだほぼ最強。2発目を打ってポットを育て、リバーで大きく取る準備をします。'
              '弱い A やポケットペアから払わせられます。',
          ifChanged: '相手がターンで急に受けを強めるなら、サイズを調整して払える範囲を残します。',
        ),
        ok(
          'チェック',
          reason:
              'ポットを抑える選択も一応成立しますが、乾いた板で最強クラスを'
              '寝かせる理由は薄く、打って積むほうが上です。',
          ifChanged: '相手がチェックに必ず撃つタイプなら、チェックで誘う価値が上がります。',
        ),
      ],
      outcome: 'BB がコール。ポットは 28.5BB になります。',
    ),
    buildSpot(
      street: Street.river,
      newCards: 'Kd',
      potBb: 28.5,
      stackBb: 86,
      history: ['BB チェック'],
      question: 'リバーで K。ストレートもフラッシュも無い盤面で、あなたはトップセット。どうしますか？',
      hint:
          'K は相手の Kx を強く見せかけます。あなたはほぼ最強で、相手は'
          '「強いが最強ではない」手（Kx・弱いA・2ペア）に偏ります。',
      terms: [TrainerTerms.valueBet, TrainerTerms.polarized, TrainerTerms.nuts],
      options: [
        best(
          'オーバーベット 40BB（ポット超え）',
          reason:
              'ストレートもフラッシュも無く、あなたのトップセットはほぼ最強。'
              'リバーの K で相手は Kx や2ペアを強く感じて払いやすくなります。'
              '最強級かつ相手が中位の手に偏る典型的なオーバーベット局面なので、'
              'ポットを超える大きさで最大限に取りにいきます。',
          ifChanged:
              '盤面にストレートやフラッシュが完成していて、あなたの手が最強で'
              'なくなるなら、オーバーベットは危険になり普通のサイズに落とします。',
        ),
        ok(
          'ベット 14BB（約1/2ポット）',
          reason:
              '普通サイズでも価値は取れますが、この最強級＆相手が払いやすい盤面では'
              '小さすぎて、取れるはずの価値を残してしまいます。',
          ifChanged:
              '相手が「大きいと降りるが小さいと払う」タイプなら、むしろ小さめが正解に'
              'なります。相手の性質でサイズを決めます。',
        ),
        bad(
          'チェック',
          reason:
              'ほぼ最強の手をチェックで通すのは、最大の価値チャンスを捨てる行為です。'
              '相手が自分から大きく払ってくれる保証はありません。',
          ifChanged:
              '相手が極端にアグレッシブで、チェックすれば必ず大きく撃ってくると'
              '読めるなら、チェックレイズ狙いのチェックが成立します。',
        ),
      ],
    ),
  ],
  takeaway:
      'このハンドの軸は「最強級 × 相手が中位の手に偏る盤面 = オーバーベット」です。\n\n'
      'フロップ・ターンは乾いた板で素直に価値を積み、リバーは K が相手の Kx を'
      '強く見せる盤面だったので、ポットを超える大きさで最大限に取りにいきました。\n\n'
      'オーバーベットは「自分がほぼ最強」で「相手に払える中位の手が多い」ときの武器です。'
      '逆に自分の手が最強でない盤面では危険なので、条件を必ず確認してから使います。',
);
