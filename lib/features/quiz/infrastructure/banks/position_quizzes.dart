import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// ポジションの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class PositionQuizzes {
  static List<Quiz> get all => _quizzes;

  static Quiz _q({
    required String id,
    required QuizDifficulty difficulty,
    Street street = Street.preflop,
    required Position hero,
    Position? villain,
    required String heroCards,
    String board = '',
    double stackBb = 100,
    double potBb = 1.5,
    TableType tableType = TableType.sixMax,
    String villainProfile = VillainProfile.reg,
    List<String> history = const [],
    required String question,
    required List<String> choices,
    required int correctIndex,
    required String shortReason,
    required String gtoView,
    required String practicalView,
    required String commonMistake,
    String? relatedRangeSpotId,
  }) {
    return buildQuiz(
      id: id,
      category: QuizCategory.position,
      difficulty: difficulty,
      street: street,
      hero: hero,
      villain: villain,
      heroCards: heroCards,
      board: board,
      stackBb: stackBb,
      potBb: potBb,
      tableType: tableType,
      villainProfile: villainProfile,
      history: history,
      question: question,
      choices: choices,
      correctIndex: correctIndex,
      shortReason: shortReason,
      gtoView: gtoView,
      practicalView: practicalView,
      commonMistake: commonMistake,
      relatedRangeSpotId: relatedRangeSpotId,
    );
  }

  static final List<Quiz> _quizzes = [
    // ── 初級 ──────────────────────────────────────────────
    _q(
      id: 'ps001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.sb,
      villain: Position.bb,
      heroCards: 'Kc 9d',
      villainProfile: VillainProfile.reg,
      history: ['全員フォールドで SB のあなたの番'],
      question: '6MAX・100BB の SB です。K9o でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 3BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'SB vs BB のヘッズアップでは、相手が 1 人しかいないので'
          'K9o は十分強いハンドです。'
          'フロップ以降は不利なので、プリフロップで主導権を取ります。',
      gtoView:
          'SB のレイズレンジが広くなるのは、'
          '「降ろす相手が BB 1 人だけ」だからです。'
          'ポジションは不利ですが、参加人数の少なさがそれを補います。',
      practicalView:
          'BB が 3Bet を多用する相手ならレンジを締め、'
          'BB が降りやすい相手ならさらに広げます。',
      commonMistake:
          'SB でリンプしてしまうミスです。'
          'リンプすると BB に無料でフロップを見せたうえ、'
          '不利なポジションで戦うことになります。',
      relatedRangeSpotId: '6max_sb_open',
    ),
    _q(
      id: 'ps002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac 7d',
      street: Street.flop,
      board: 'Kd 8c 3h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。BTN でフロップを迎えました。ポジションがあることの最大の利点はどれですか。',
      choices: [
        '毎回強いハンドが配られること',
        '相手のアクションを見てから自分の行動を決められること',
        'ブラインドを払わなくていいこと',
        '必ずベットできること',
      ],
      correctIndex: 1,
      shortReason:
          'ポジションがあると、'
          '相手がチェックしたのかベットしたのかを見てから決められます。'
          '情報が 1 手ぶん多い状態で判断できるのが最大の利点です。',
      gtoView:
          '同じハンドでも、'
          'ポジションがあるほうが実際に取れる勝率が上がります。'
          '見かけの勝率が同じでも、'
          '情報の多い側のほうがそれを実現しやすいためです。',
      practicalView:
          'ポジションがあるからこそ、'
          '「相手がチェックしたら打つ、打ってきたら安く見る」という'
          '使い分けができます。'
          '不利な側は、その使い分けを先に決めておく必要があります。',
      commonMistake:
          'ポジションを「順番の話」だと軽く見てしまうミスです。'
          'プリフロップのレンジが位置ごとに変わるのは、'
          'すべてこの情報差が理由です。',
    ),
    _q(
      id: 'ps003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.utg,
      heroCards: 'Ah Qc',
      villainProfile: VillainProfile.unknown,
      history: ['全員フォールドで UTG のあなたの番'],
      question: '6MAX・100BB。同じ AQo でも、UTG のほうが BTN より慎重に扱う理由はどれですか。',
      choices: [
        'UTG のほうが後ろに残っている人数が多いから',
        'UTG のほうがブラインドに近いから',
        'AQo は UTG では弱くなるから',
        'UTG はレイズが禁止されているから',
      ],
      correctIndex: 0,
      shortReason:
          'UTG は後ろに 5 人残っています。'
          '誰か 1 人でも強い手を持っていれば苦しくなるので、'
          'その確率のぶんだけレンジを狭くします。',
      gtoView:
          'オープンレンジの広さは、'
          'ほぼ「後ろに何人残っているか」だけで決まります。'
          'ハンド自体の強さは変わらず、'
          '変わるのは通過しなければならない人数です。',
      practicalView:
          'AQo は UTG でもオープンできる強さですが、'
          '3Bet されたときの扱いは BTN のときより慎重になります。'
          '後ろが多いほど、強いレンジに当たる確率が上がるためです。',
      commonMistake:
          'ハンドの強さだけでレンジを覚えてしまうミスです。'
          '同じハンドでも、ポジションによって扱いが変わります',
      relatedRangeSpotId: '6max_utg_open',
    ),
    _q(
      id: 'ps004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.utg,
      heroCards: '7h 6h',
      potBb: 4,
      villainProfile: VillainProfile.tightAggressive,
      history: [
        'UTG（タイトなレギュラー。オープンは 15% 程度）raise 2.5BB',
        'HJ fold',
        'あなた（CO）の番。後ろには BTN・SB・BB の 3 人が残っている',
      ],
      question: '6MAX・100BB の CO です。タイトな UTG のオープンに 76s でどうしますか。',
      choices: ['Fold', 'Call', '3Bet', 'All-in'],
      correctIndex: 0,
      shortReason:
          'コールしても後ろに 3 人残っており、'
          'レイズで割り込まれる危険があります。'
          'しかも相手はタイトなレンジなので、'
          '76s が安く 5 枚見られる展開になりにくい状況です。',
      gtoView:
          'スーテッドコネクターの価値は'
          '「安くフロップを見て、当たったら大きく取る」ことにあります。'
          '後ろに人が残っていると、'
          'その「安く」という前提が崩れます。',
      practicalView:
          '同じ 76s でも、BTN でブラインドがタイトなら'
          'コールできる場面です。'
          '相手が広くオープンしている場合も条件が変わります。',
      commonMistake:
          '「スーテッドコネクターは何でも参加できる」と考えるミスです。'
          '安く見られる場面でこそ価値が出るハンドで、'
          '高い値段では割に合いません。',
      relatedRangeSpotId: '6max_co_open',
    ),
    _q(
      id: 'ps005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jc Th',
      street: Street.flop,
      board: 'Kd 8c 3h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'フロップはあなた（BB）から先に行動する'],
      question: '6MAX・100BB。BB でフロップを迎えました。不利なポジションで基本方針となるのはどれですか。',
      choices: [
        '強い手も弱い手もまとめてチェックし、相手の行動を見てから決める',
        '毎回自分から大きくベットして主導権を取る',
        '弱い手だけチェックし、強い手は必ずベットする',
        'すべてフォールドする',
      ],
      correctIndex: 0,
      shortReason:
          '不利なポジションでは、'
          '行動が手の強さと 1 対 1 で結びつくと簡単に読まれます。'
          'まとめてチェックしておけば、'
          '相手はこちらのレンジを絞れません。',
      gtoView:
          'これを「チェックレンジ」と呼びます。'
          '強い手も弱い手も同じ行動に混ぜることで、'
          '相手はチェックを見ても情報を得られなくなります。',
      practicalView:
          '相手がチェックに対してほとんど打ってこない受け身なタイプなら、'
          '自分から打つ回を増やす調整が有効です。'
          '基本形はあくまで、攻めてくる相手に対するものです。',
      commonMistake:
          '「強い手は必ず打つ」と決めてしまうミスです。'
          'その癖がつくと、'
          'チェックした瞬間に弱いと決めつけられて攻められます。',
    ),
    _q(
      id: 'ps006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      heroCards: 'Qd 8d',
      villainProfile: VillainProfile.reg,
      history: ['UTG〜CO は全員フォールド'],
      question: '6MAX・100BB の BTN です。Q8s でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          '残りはブラインド 2 人だけで、'
          'フロップ以降は必ず最後に動けます。'
          'Q8s はスーテッドで伸びしろもあり、'
          'BTN からなら十分オープンできます。',
      gtoView:
          'BTN のレンジが最も広くなるのは、'
          '「通過すべき相手が 2 人」かつ'
          '「ポジションが確定している」という条件が重なるためです。',
      practicalView:
          'ブラインドが 3Bet を多用する相手なら、'
          'こうした境界付近のハンドから外していきます。',
      commonMistake:
          '同じ Q8s を UTG からもオープンしてしまうミスです。'
          'BTN で参加できることと、'
          'どこからでも参加できることは別です。',
      relatedRangeSpotId: '6max_btn_open',
    ),
    _q(
      id: 'ps007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.sb,
      heroCards: '9c 7d',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['全員フォールド', 'SB raise 3BB'],
      question: '6MAX・100BB。SB のオープンに BB で 97o。他のポジション相手より広く守れる理由はどれですか。',
      choices: [
        'SB 相手のときだけ、BB がフロップ以降で後に動けるから',
        'SB のレンジがいつも弱いから',
        'BB はブラインドを払っているから',
        'SB はレイズできないから',
      ],
      correctIndex: 0,
      shortReason:
          'BB は通常どのポジション相手でもフロップ以降は先に動きますが、'
          'SB 相手のときだけは後に動けます。'
          'ポジションが逆転するので、'
          '同じ値段でも守れる範囲が広がります。',
      gtoView:
          'BB のディフェンス範囲は'
          '「値段」と「ポジション」の掛け算で決まります。'
          'SB 相手はその両方が有利なので、最も広く守れます。',
      practicalView:
          'SB が極端にタイトなレンジしかオープンしないなら、'
          '同じ値段でも降りる寄りに調整します。',
      commonMistake:
          '「BB はいつも不利」と思い込んで、'
          'SB 相手にも同じように降りすぎるミスです。',
    ),
    _q(
      id: 'ps008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.hj,
      heroCards: 'Ad Td',
      tableType: TableType.nineMax,
      villainProfile: VillainProfile.reg,
      history: ['9人テーブル。UTG から LJ まで全員フォールド'],
      question: '9MAX・100BB の HJ です。ATs でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 3BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          '9MAX でも、HJ まで回れば後ろに残るのは 4 人です。'
          'ATs はスーテッドでナッツフラッシュも狙え、'
          'この人数なら十分オープンできます。',
      gtoView:
          '大事なのはテーブルの人数ではなく、'
          '自分より後ろに何人残っているかです。'
          '9MAX の HJ は、6MAX の HJ とほぼ同じ条件になります。',
      practicalView:
          '9MAX は参加者が多いぶんルースなテーブルになりやすく、'
          '後ろが降りにくいならレンジを少し締めます。',
      commonMistake:
          '「9MAX だから全部タイトに」と'
          '機械的に締めてしまうミスです。'
          'アーリーが降りた後は、人数に関係なく広く戦えます。',
      relatedRangeSpotId: '9max_hj_open',
    ),
    _q(
      id: 'ps009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '5h 4h',
      street: Street.flop,
      board: 'Ac Kd 7s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。BTN で AK7 のフロップ。BB がチェックしました。この情報から言えることはどれですか。',
      choices: [
        '相手は必ず何も持っていない',
        '相手のレンジには強い手も弱い手も残っているが、こちらは打つか打たないかを選べる',
        '相手は必ず強い手を持っている',
        'チェックからは何も分からない',
      ],
      correctIndex: 1,
      shortReason:
          '相手のチェックには強い手も弱い手も混ざります。'
          '重要なのは、'
          'その状態を見てから「打つか打たないか」を選べる立場にいることです。',
      gtoView:
          'ポジションの価値は「相手の情報が分かる」ことに加え、'
          '「自分の選択肢が最後まで残っている」ことにあります。'
          '不利な側は先に選ばなければなりません。',
      practicalView:
          'AK7 はこちらのレンジに有利なボードなので、'
          'チェックを見たら小さく打って広く降ろせます。'
          '相手が打ってきていたら、また別の判断になります。',
      commonMistake:
          '「チェック＝弱い」と決めつけてしまうミスです。'
          '強い手をチェックに混ぜてくる相手には通用しません。',
    ),
    _q(
      id: 'ps010',
      difficulty: QuizDifficulty.beginner,
      hero: Position.sb,
      villain: Position.btn,
      heroCards: 'Ah Qd',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'あなた（SB）の番。BB がまだ後ろに残っている'],
      question: '6MAX・100BB の SB です。BTN のオープンに AQo。コールと 3Bet のどちらが適していますか。',
      choices: [
        'Fold',
        'Call。安く見たいから',
        '3Bet。コールすると BB を安く参加させ、しかも 2 人に対して不利なポジションになるから',
        'All-in',
      ],
      correctIndex: 2,
      shortReason:
          'SB でコールすると、'
          'BB が良いオッズで参加できてしまいます。'
          'しかもフロップ以降は 2 人を相手に、'
          'ずっと先に動くことになります。',
      gtoView:
          'SB は「後ろにまだ BB が残っている」という点で、'
          '単純に不利なポジション以上に扱いが難しい場所です。'
          'コールを減らし、3Bet かフォールドに寄せるのが基本になります。',
      practicalView:
          'BTN が広くオープンする相手なら、'
          'AQo の 3Bet はバリューとして十分成立します。',
      commonMistake:
          'SB を「BB と同じようなもの」と考えてコールしてしまうミスです。'
          'BB は最後に行動できますが、SB は違います。',
    ),
    _q(
      id: 'ps011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.utg,
      heroCards: '8c 8d',
      tableType: TableType.nineMax,
      villainProfile: VillainProfile.unknown,
      history: ['9人テーブル。UTG のあなたに最初のアクションが回ってきた'],
      question: '9MAX・100BB の UTG です。88 でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 3BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          '88 はポケットペアの中では中位で、'
          'セットになれば非常に強く、'
          '降ろせればそのまま勝てます。'
          '9MAX の UTG でもオープンできる強さです。',
      gtoView:
          'ポケットペアは「支配されにくい」という利点があります。'
          'オフスートのブロードウェイと違い、'
          '相手に同じ手を持たれてキッカー負けする形がありません。',
      practicalView:
          '後ろに攻撃的な 3Bet を多用する相手が多いなら、'
          '中位のポケットペアは扱いが難しくなります。'
          'それでも UTG からオープンできる下限には入ります。',
      commonMistake:
          '「9MAX の UTG は AA・KK・AK だけ」と'
          '極端に締めてしまうミスです。'
          'そこまで狭いと、レンジが読まれて利益が出ません。',
      relatedRangeSpotId: '9max_utg_open',
    ),
    _q(
      id: 'ps012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      heroCards: 'Kd Jc',
      villainProfile: VillainProfile.reg,
      history: ['UTG・HJ ともにフォールド。CO のあなたの番'],
      question: '6MAX・100BB の CO です。KJo でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          '後ろは BTN とブラインド 2 人の 3 人だけです。'
          'KJo は 9MAX の UTG では降りるハンドですが、'
          'CO からなら十分オープンできます。',
      gtoView:
          '同じ KJo でも、'
          '通過すべき人数が 8 人か 3 人かで意味がまったく変わります。'
          'ポジションが「ハンドの強さを変える」わけではなく、'
          '「必要な強さの基準を変える」と考えてください。',
      practicalView:
          'BTN が非常に攻撃的で 3Bet を多用する相手なら、'
          'KJo のような支配されやすいハンドは扱いにくくなります。',
      commonMistake:
          'すべてのポジションで同じレンジを使ってしまうミスです。'
          'レンジ表がポジションごとに分かれているのには理由があります。',
      relatedRangeSpotId: '6max_co_open',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'ps013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qd 9d',
      street: Street.turn,
      board: 'Kc 8h 4s 2d',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。BTN で何も無い Q9s。ポジションがあることで取れる選択肢はどれですか。',
      choices: [
        'ここでチェックして、リバーで相手の出方を見てから決められる',
        'ポジションがあるので必ずベットしなければならない',
        'ポジションがあるとチェックできない',
        'ポジションはターン以降には関係ない',
      ],
      correctIndex: 0,
      shortReason:
          'チェックしておけば、'
          'リバーで相手が打ってきたら降り、'
          'チェックしてきたらブラフする、という使い分けができます。'
          '不利な側にはこの使い分けができません。',
      gtoView:
          'ポジションの価値は「毎回打てること」ではなく、'
          '「打つか打たないかを最後に決められること」です。'
          'チェックも立派な選択肢として使えます。',
      practicalView:
          'Q9s は 2 回打っても降ろせる相手が少ない状況です。'
          'チェックしてリバーの安いブラフに回すほうが、'
          '同じチップでより高い成功率を狙えます。',
      commonMistake:
          '「ポジションがあるから毎回打つ」と'
          '自動化してしまうミスです。'
          'それでは情報の優位を使っていることになりません。',
    ),
    _q(
      id: 'ps014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.co,
      heroCards: 'Ah Jh',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BTN・SB はフォールド', 'あなた（BB）の番'],
      question: '6MAX・100BB の BB です。CO のオープンに AJs。3Bet とコールのどちらが適していますか。',
      choices: [
        'Fold',
        'Call。安く見たいから',
        '3Bet。フロップ以降ずっと不利なポジションになるので、プリフロップで主導権を取りたいから',
        'All-in',
      ],
      correctIndex: 2,
      shortReason:
          'コールするとフロップ以降ずっと先に動くことになります。'
          'AJs は 3Bet できる強さがあるので、'
          'ポジションの不利をプリフロップの主導権で補います。',
      gtoView:
          '不利なポジションでは、'
          'ハンドの強さを実際の勝率に変えにくくなります。'
          '3Bet して相手のレンジを狭めておくと、'
          'フロップ以降の判断が楽になります。',
      practicalView:
          '相手が 3Bet に対して 4Bet を多用するタイプなら、'
          'AJs の 3Bet は減らします。'
          'コールに回して安くフロップを見る形に切り替えます。',
      commonMistake:
          '「強い手だから安く見て育てよう」と'
          'コールしてしまうミスです。'
          '不利なポジションでは、'
          'ポットが大きくなるほど扱いが難しくなります。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
    _q(
      id: 'ps015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.btn,
      heroCards: 'Ks Qs',
      street: Street.flop,
      board: 'Kd 7c 2h',
      potBb: 6.5,
      villainProfile: VillainProfile.reg,
      history: ['CO（あなた）raise 2.5BB', 'BTN call', 'ブラインドはフォールド', 'あなたから先に行動する'],
      question:
          '6MAX・100BB。CO でオープンし BTN にコールされました。トップペアですが、ポジションはありません。方針はどれですか。',
      choices: [
        'ポジションが無いぶん、余計なポットを膨らませないよう慎重に進める',
        'ポジションが無いので毎回オールインする',
        'ポジションは関係ないので、いつも通り 3 回打つ',
        'すべてチェックする',
      ],
      correctIndex: 0,
      shortReason:
          'BTN にコールされた時点で、'
          '残り 3 ストリートすべて先に動くことになります。'
          '相手は毎回こちらの行動を見てから決められるので、'
          '大きなポットほど不利が効いてきます。',
      gtoView:
          '不利なポジションでは、'
          '同じハンドでも実際に取れる勝率が下がります。'
          'その差を埋めるために、'
          'ポットサイズを抑える方向に調整します。',
      practicalView:
          'KQ のトップペアは価値がありますが、'
          '3 ストリート打ち続けてスタックを入れるハンドではありません。'
          '2 回打ってリバーはチェックする、といった進め方が現実的です。',
      commonMistake:
          '「トップペアだから最後まで攻める」と'
          'ポジションを考えずに進めてしまうミスです。'
          '同じハンドでも、BTN と CO では扱いが変わります。',
    ),
    _q(
      id: 'ps016',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.sb,
      heroCards: 'Ts 9s',
      villainProfile: VillainProfile.overFolder,
      history: ['全員フォールド', 'BB は降りやすい相手'],
      question: '6MAX・100BB の SB です。降りやすい BB 相手に T9s。どうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 3BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'BB が降りやすいなら、'
          'そのままブラインドを取れる回が増えます。'
          'T9s は降ろせなくてもフロップで戦えるので、'
          '二重の意味でレイズが得です。',
      gtoView:
          'SB のレンジの広さは「BB がどれだけ守るか」で決まります。'
          '守りが弱いほど、'
          'レイズだけで取れるポットが増えて広げられます。',
      practicalView:
          'BB が広く守ってくる相手なら、'
          '不利なポジションで戦う回が増えるのでレンジを締めます。'
          '相手の守り方を見てから調整するスポットです。',
      commonMistake:
          '「SB は不利だから常にタイトに」と'
          '固定してしまうミスです。'
          '相手が降りやすいなら、不利なポジションでも広げる価値があります。',
      relatedRangeSpotId: '6max_sb_open',
    ),
    _q(
      id: 'ps017',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '8h 8c',
      street: Street.flop,
      board: 'Qd 7s 3c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'あなた（BB）から先に行動する'],
      question: '6MAX・100BB。BB で 88、Q73 のフロップ。不利なポジションでの進め方として適切なのはどれですか。',
      choices: [
        'チェックして相手の出方を見る（チェックコールの準備）',
        '自分から大きくベットして主導権を取る',
        'フォールドする',
        'オールインする',
      ],
      correctIndex: 0,
      shortReason:
          '88 は Q に負けていますが、'
          '相手の何も無い手には勝っています。'
          '不利なポジションで自分から打つと、'
          '強い手だけが残ってしまいます。',
      gtoView:
          '中程度の強さのハンドは、'
          '不利なポジションでは受けに回すのが基本です。'
          'ベットは「降ろしたい相手」か'
          '「払ってほしい相手」がいるときに使います。',
      practicalView:
          '相手が小さいベットを高頻度で打ってくるタイプなら、'
          '88 でチェックコールし続ける価値が高くなります。'
          '相手のブラフを受け止める役割です。',
      commonMistake:
          '「打たないと弱いと思われる」と'
          '自分から打ってしまうミスです。'
          '不利なポジションでは、'
          '打つほど選択肢を先に使い切ることになります。',
    ),
    _q(
      id: 'ps018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.hj,
      villain: Position.btn,
      heroCards: 'Ad Qs',
      potBb: 12.5,
      villainProfile: VillainProfile.reg,
      history: ['HJ（あなた）raise 2.5BB', 'CO fold', 'BTN 3Bet 9BB', 'ブラインドはフォールド'],
      question: '6MAX・100BB。HJ でオープンしたら BTN に 3Bet されました。AQo でどうしますか。',
      choices: ['Fold', 'Call', '4Bet 21BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          'AQo は強いですが、'
          '4Bet すると降りるのは AQo より弱い手ばかりで、'
          '残るのは AA・KK・AK など負けているレンジです。'
          'コールしてフロップを見ます。',
      gtoView:
          '相手にポジションを取られている状況では、'
          'レンジを狭める動き（4Bet）が'
          '自分の不利を大きくすることがあります。'
          'コールでレンジを広く保つほうが扱いやすくなります。',
      practicalView:
          'BTN が 3Bet を乱発するタイプなら 4Bet の価値が上がります。'
          '3Bet が最強クラスしかない相手ならフォールドも十分ありえます。',
      commonMistake:
          '「AQ は強いから 4Bet」と'
          '手の絶対的な強さだけで決めてしまうミスです。'
          '重要なのは、その動きに対して相手が何を残すかです。',
    ),
    _q(
      id: 'ps019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.co,
      heroCards: 'Jh Jd',
      potBb: 6.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG fold', 'HJ fold', 'CO raise 2.5BB', 'あなた（BTN）の番'],
      question: '6MAX・100BB の BTN です。CO のオープンに JJ。3Bet とコールのどちらが適していますか。',
      choices: [
        'Fold',
        'Call。ポジションがあるので安くフロップを見たい',
        '3Bet。ポジションがあるうえ強い手なので、ブラインドを降ろしつつポットを作る',
        'All-in',
      ],
      correctIndex: 2,
      shortReason:
          'JJ は CO のオープンレンジに対して明確に勝っています。'
          'コールするとブラインド 2 人が安く入ってくる可能性があり、'
          '多人数になるほど JJ の価値は下がります。',
      gtoView:
          'ポジションがあるときの 3Bet は、'
          '「相手を絞る」「ポットを作る」「ポジションを確定させる」の'
          '3 つを同時に達成します。',
      practicalView:
          'CO が 3Bet に対してほとんど降りないタイプなら、'
          'バリューがさらに厚くなるので迷わず 3Bet です。'
          'サイズは 7.5〜8BB 程度が標準になります。',
      commonMistake:
          '「JJ は 3Bet されると困るからコール」と'
          '先回りして守ってしまうミスです。'
          'ポジションがある状況では、攻めるほうが得です。',
    ),
    _q(
      id: 'ps020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Kd 8c',
      street: Street.river,
      board: 'Kh 9s 4d 6c 2h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンともに両者チェック', 'リバー: あなた（BB）から先に行動する'],
      question: '6MAX・100BB。BB でトップペア。両者チェックで進んだリバーで先に行動します。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'All-in'],
      correctIndex: 1,
      shortReason:
          '相手が 2 回チェックバックしたので、'
          'レンジは弱めに偏っています。'
          '小さく打てば 9x や 4x から払ってもらえます。'
          '不利なポジションでも、打つ価値があるのはこういう場面です。',
      gtoView:
          '不利なポジションでも、'
          '相手のレンジが弱いと分かっている場面では自分から打ちます。'
          '「不利だから常にチェック」ではありません。',
      practicalView:
          'ここでチェックすると、'
          '相手も弱い手でチェックバックしてしまい'
          '何も取れずに終わる回が増えます。',
      commonMistake:
          '「BB は最後まで受けるだけ」と'
          '決めてしまうミスです。'
          '相手が弱さを示したら、そこから先は自分で取りにいきます。',
    ),
    _q(
      id: 'ps021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.utg,
      villain: Position.btn,
      heroCards: 'Ac Kd',
      street: Street.flop,
      board: 'Qh 8d 3c',
      potBb: 6.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG（あなた）raise 2.5BB', 'BTN call', 'ブラインドはフォールド'],
      question: '6MAX・100BB。UTG でオープンし BTN にコールされました。Q83 で AK。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 1,
      shortReason:
          'UTG のレンジには QQ・AQ・KK・AA が多く、'
          'Q 高のボードでもレンジ有利があります。'
          'AK は 6 アウツを持っているので、'
          '小さく打って広く降ろしにいけます。',
      gtoView:
          'ポジションが無くても、'
          'レンジ有利があるボードでは打てます。'
          '判断材料はポジションだけでなく、'
          'どちらのレンジがそのボードに当たるかです。',
      practicalView:
          'BTN のコールレンジには 8x や 3x が多く含まれるので、'
          '大きく打つと降りてくれない相手が残ります。'
          '小さいサイズが噛み合います。',
      commonMistake:
          '「ポジションが無いからチェック」と'
          '一律に決めてしまうミスです。'
          'レンジ有利があるなら、不利なポジションでも打ちます。',
      relatedRangeSpotId: '6max_utg_open',
    ),
    _q(
      id: 'ps022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '9h 9c',
      street: Street.flop,
      board: 'Ts 6d 2c',
      potBb: 5.5,
      stackBb: 25,
      villainProfile: VillainProfile.reg,
      history: ['有効スタック 25BB', 'CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・有効スタック 25BB。浅いスタックのとき、ポジションの重要度はどう変わりますか。',
      choices: [
        '下がる。ストリートが少なく、情報差を活かす機会が減るから',
        '上がる。浅いほど毎回の判断が重くなるから',
        '変わらない。ポジションの価値は常に一定',
        'ポジションは浅いスタックでは存在しない',
      ],
      correctIndex: 0,
      shortReason:
          'ポジションの価値は「相手の行動を見てから決められる回数」から生まれます。'
          'スタックが浅いとベットの回数自体が減るため、'
          'その優位を使う機会も減ります。',
      gtoView:
          '深いスタックほどポストフロップの判断が増え、'
          'ポジションの差が積み上がります。'
          '逆に浅いほどプリフロップのハンドの強さが支配的になります。',
      practicalView:
          'だからこそ浅いスタックでは、'
          'スーテッドコネクターより'
          'ポケットペアや高いカードの価値が上がります。'
          '「後で活かす」余地が無いためです。',
      commonMistake:
          'スタックの深さに関係なく、'
          '同じレンジ表を使ってしまうミスです。'
          '深さが変われば、価値のあるハンドの種類も変わります。',
    ),
    _q(
      id: 'ps023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.sb,
      heroCards: 'Th 8h',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['BTN（あなた）raise 2.5BB', 'SB 3Bet 11BB', 'BB fold'],
      question: '6MAX・100BB。BTN オープンに SB が 3Bet。T8s でどうしますか。',
      choices: ['Fold', 'Call', '4Bet', 'All-in'],
      correctIndex: 0,
      shortReason:
          'T8s はオープンできる強さですが、'
          '3Bet ポットで戦うには弱すぎます。'
          'ポジションはありますが、'
          '11BB 払って戦うにはハンドの伸びしろが足りません。',
      gtoView:
          'ポジションは万能ではありません。'
          '値段が上がるほど、'
          'ポジションだけでは埋められない差が出てきます。',
      practicalView:
          '有効スタックが 200BB あるなど、'
          '当たったときの取り分が大きい状況ならコールの余地が生まれます。'
          '100BB では足りません。',
      commonMistake:
          '「ポジションがあるから続けられる」と'
          '考えてしまうミスです。'
          'ポジションは判断を助けますが、'
          '弱いハンドを強くはしません。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'ps024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ac 5c',
      street: Street.flop,
      board: '9h 6d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      question:
          '6MAX・100BB。BB で 963 のフロップ。BB が自分から打つ（ドンクベット）のが有効になるのはどんなボードですか。',
      choices: [
        '自分のレンジにしか無い強い形が多く、相手のレンジには少ないボード',
        'A や K の高いカードが並んだボード',
        '毎回打つべきなので、ボードは関係ない',
        'ドンクベットは常に間違い',
      ],
      correctIndex: 0,
      history: ['BTN raise 2.5BB', 'BB call', 'あなた（BB）から先に行動する'],
      shortReason:
          '963 のような低いボードは、'
          'BB のコールレンジ（96s・63s・99・66・33）にしか無い形が多く、'
          'BTN のオープンレンジには少ない構造です。'
          'こういうボードでは、不利なポジションからでも打つ根拠があります。',
      gtoView:
          '「自分のレンジにしか無い最強クラス」がある状態をナッツ有利と呼びます。'
          'レンジ有利（全体の強さ）とナッツ有利（頂点の強さ）は別物で、'
          '自分から打つ根拠になるのは後者です。',
      practicalView:
          '逆に AK7 のような高いボードでは、'
          '最強クラスも全体の強さも相手側にあります。'
          'そこで自分から打つと、'
          '強いレンジに向かって不利なポジションから仕掛けることになります。',
      commonMistake:
          'ドンクベットを「相手を試す動き」として使ってしまうミスです。'
          'ボード構造の裏付けが無いリードは、'
          'ただ自分のレンジを弱く見せるだけになります。',
    ),
    _q(
      id: 'ps025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.btn,
      heroCards: 'Ah Kh',
      street: Street.flop,
      board: 'Ad 9c 4s',
      potBb: 6.5,
      stackBb: 97.5,
      villainProfile: VillainProfile.reg,
      history: ['CO（あなた）raise 2.5BB', 'BTN call', 'ブラインドはフォールド'],
      question:
          '6MAX・100BB。CO でオープンし BTN にコールされました。'
          'A94 で AK のトップペア・トップキッカー。3 ストリートの計画として適切なのはどれですか。',
      choices: [
        '3 回とも大きく打ってスタックを入れ切る',
        '2 回打ち、リバーは相手の出方を見てからサイズを決める',
        'すべてチェックして相手に打たせる',
        'フロップだけ打って以降はチェックする',
      ],
      correctIndex: 1,
      shortReason:
          'AK はトップペア・トップキッカーで強いハンドですが、'
          'ポジションが無いため'
          'リバーで大きなポットに直面したときの判断が難しくなります。'
          '2 回打って情報を集めてから決めます。',
      gtoView:
          '不利なポジションでは、'
          '「最後のストリートで相手に主導権を渡す」構造になります。'
          '3 回打ち切る計画は、'
          'ポジションがある側のほうが実行しやすい形です。',
      practicalView:
          '同じ AK でも BTN 側なら 3 回打ち切れます。'
          '相手のチェックを見てからサイズを決められるためです。'
          'ポジションの有無で、同じハンドの計画が変わります。',
      commonMistake:
          '「強い手だから最後まで打つ」と'
          '最初に決め打ちしてしまうミスです。'
          '不利なポジションでは、'
          '途中で計画を変える余地を残しておく必要があります。',
    ),
    _q(
      id: 'ps026',
      difficulty: QuizDifficulty.advanced,
      hero: Position.sb,
      villain: Position.bb,
      heroCards: 'Kh Qd',
      potBb: 1.5,
      stackBb: 100,
      villainProfile: VillainProfile.reg,
      history: ['全員フォールドで SB のあなたの番'],
      question:
          '6MAX・100BB。SB でオープンするとき、'
          'BTN の 2.5BB より大きい 3BB を使うことが多い理由はどれですか。',
      choices: [
        'BB にコールされたとき必ず不利なポジションになるため、安いコールを減らしたいから',
        'SB のほうが強いハンドしか持っていないから',
        'ルールでサイズが決まっているから',
        'ポットを大きくして運任せにしたいから',
      ],
      correctIndex: 0,
      shortReason:
          'BTN がオープンした場合、'
          'コールされてもポジションを取れます。'
          'SB はコールされた瞬間に必ず不利な側になるので、'
          '相手が気軽にコールできない値段にします。',
      gtoView:
          'レイズサイズは「コールされたときに自分が有利か不利か」で変わります。'
          '不利になるなら、'
          'コールの範囲を狭めるためにサイズを上げるのが自然な調整です。',
      practicalView:
          'BB がほとんど降りない相手なら、'
          'サイズを上げてもコールされ続けます。'
          'その場合はレンジを締めるほうが効果的です。',
      commonMistake:
          'すべてのポジションで同じサイズを使ってしまうミスです。'
          'サイズはポジションと相手の守り方で決めます。',
      relatedRangeSpotId: '6max_sb_open',
    ),
    _q(
      id: 'ps027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '6c 5c',
      street: Street.turn,
      board: 'Kd 9h 4s 2c',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question:
          '6MAX・100BB。BTN で何も無い 65s。ここでチェックしておくと、'
          'リバーでどんな利点がありますか。',
      choices: [
        '相手がチェックしたらブラフ、打ってきたら降りる、と後から選べる',
        '相手が必ず降りるようになる',
        'リバーで必ず良いカードが来る',
        'チェックすると相手に強いと思われる',
      ],
      correctIndex: 0,
      shortReason:
          'ターンでチェックしておけば、'
          'リバーで相手の行動を見てから決められます。'
          '打ってしまうと、'
          'レイズされたときに降りるしかなくなります。',
      gtoView:
          'ポジションのある側は、'
          '「チェックして情報を買う」という選択が使えます。'
          '不利な側にはこの選択がなく、'
          '常に先に情報を出す側になります。',
      practicalView:
          '相手がターンのチェックバックを見て'
          'リバーで必ず打ってくるタイプなら、'
          'チェックの価値はさらに上がります。'
          '相手のブラフを受け止められるためです。',
      commonMistake:
          'ブラフを 2 回・3 回と続けるのが'
          '「攻めている」ことだと思ってしまうミスです。'
          '一度止めてリバーで仕掛け直すほうが、'
          '同じチップで高い成功率を得られる場面があります。',
    ),
    _q(
      id: 'ps028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.co,
      heroCards: '7h 6h',
      potBb: 4,
      stackBb: 200,
      villainProfile: VillainProfile.reg,
      history: ['有効スタック 200BB', 'CO raise 2.5BB', 'BTN・SB はフォールド'],
      question: '6MAX・有効スタック 200BB の BB です。CO のオープンに 76s。深いスタックで判断はどう変わりますか。',
      choices: [
        'コールしやすくなる。当たったときの取り分が増え、不利なポジションの損を埋められるから',
        'コールしにくくなる。深いほど不利なポジションの損が大きいから',
        '変わらない',
        '必ず 3Bet すべきになる',
      ],
      correctIndex: 0,
      shortReason:
          '76s は「安く見て、当たったら大きく取る」ハンドです。'
          'スタックが 200BB あると、'
          'ストレートやフラッシュが完成したときに取れる額が倍になります。',
      gtoView:
          '深いスタックは、'
          '不利なポジションの損失と'
          'ドローハンドの利益の両方を大きくします。'
          '76s のようなハンドでは、後者の効果のほうが大きく出ます。',
      practicalView:
          '同じ 200BB でも、'
          'AJo のような支配されやすいハンドは逆に扱いにくくなります。'
          '深さの恩恵を受けるのは、'
          'ナッツに近い形を作れるハンドです。',
      commonMistake:
          '「不利なポジションでは深いほど不利」と'
          '一律に考えてしまうミスです。'
          'ハンドの種類によって、深さの効き方が逆になります。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
    _q(
      id: 'ps029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.hj,
      villain: Position.bb,
      heroCards: 'Ks Js',
      street: Street.flop,
      board: 'Kc 8d 5h',
      potBb: 9,
      villainProfile: VillainProfile.reg,
      history: [
        'HJ（あなた）raise 2.5BB',
        'BTN call',
        'BB call',
        '3 人でフロップへ。BB check',
      ],
      question:
          '6MAX・100BB。3 人のポットで、あなたは真ん中の位置にいます。'
          'KJs のトップペアでどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 1,
      shortReason:
          '後ろに BTN が残っているので、'
          '大きく打つとレイズされたときに困ります。'
          '小さく打てば、8x や 5x、ドローから'
          'バリューを取りつつ損失を抑えられます。',
      gtoView:
          '3 人のポットでは、'
          '「自分より後ろに何人残っているか」が'
          'そのままリスクの大きさになります。'
          'サイズを抑えることが、そのリスクへの対応になります。',
      practicalView:
          'BTN が非常に攻撃的でレイズを多用するなら、'
          'チェックして BTN に打たせる形も有効です。'
          '真ん中の位置は、両方向のリスクを抱える難しい場所です。',
      commonMistake:
          '2 人のときと同じサイズで打ってしまうミスです。'
          '後ろに 1 人残っているだけで、'
          '「レイズされる」という新しいリスクが生まれます。',
    ),
    _q(
      id: 'ps030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qc Jc',
      street: Street.flop,
      board: 'Qh 7d 2s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'あなた（BB）から先に行動する'],
      question:
          '6MAX・100BB。BB でトップペアです。'
          'チェックレンジに強い手を混ぜておく必要があるのはなぜですか。',
      choices: [
        'チェックが弱い手だけになると、相手は打つだけで利益が出るから',
        'チェックすると必ず相手が降りるから',
        'ルールで決まっているから',
        '強い手はチェックのほうが得だから',
      ],
      correctIndex: 0,
      shortReason:
          '不利なポジションでは行動の回数が限られます。'
          '強い手を必ず打つ癖がつくと、'
          'チェックしたときのレンジが弱い手だけになり、'
          '相手は安全に攻め続けられます。',
      gtoView:
          '不利な側がチェックレンジを守るのは、'
          '「相手のベットを無条件に儲からせない」ためです。'
          'チェックの中にトップペアが混ざっていれば、'
          '相手は毎回打つわけにいかなくなります。',
      practicalView:
          '相手がチェックに対してほとんど打ってこない受け身なタイプなら、'
          '守る必要はありません。'
          '強い手は毎回打ってバリューを取りにいきます。',
      commonMistake:
          '毎回その場で一番得な行動だけを選んでしまうミスです。'
          '短期的には正しくても、'
          '行動と手の強さが 1 対 1 で結びつくと読まれます。',
    ),
  ];
}
