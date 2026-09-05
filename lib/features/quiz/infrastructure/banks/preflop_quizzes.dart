import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// プリフロップの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class PreflopQuizzes {
  static List<Quiz> get all => _quizzes;

  static Quiz _q({
    required String id,
    required QuizDifficulty difficulty,
    required Position hero,
    Position? villain,
    required String heroCards,
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
      category: QuizCategory.preflop,
      difficulty: difficulty,
      street: Street.preflop,
      hero: hero,
      villain: villain,
      heroCards: heroCards,
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
      tagActionTypes: true,
    );
  }

  static final List<Quiz> _quizzes = [
    // ── 初級 ──────────────────────────────────────────────
    _q(
      id: 'pf001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.utg,
      heroCards: 'Ad 9c',
      villainProfile: VillainProfile.unknown,
      history: ['全員フォールドで、UTG のあなたに最初のアクションが回ってきた'],
      question: '6MAX・100BB の UTG です。A9o でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 0,
      shortReason:
          'UTG は後ろに 5 人残る一番不利なポジションです。'
          'A9o は参加してくる相手の AK・AQ・AJ に支配されている形が多く、'
          '勝つときは小さく負けるときは大きくなります。',
      gtoView:
          'オープンレンジは「後ろに何人残っているか」で決まります。'
          'UTG は 5 人ぶんの参加リスクを背負うため最も狭くなり、'
          'オフスートのエースは AJo 前後が下限になります。',
      practicalView:
          '後ろが極端にタイトで、ほとんど誰も参加してこないテーブルなら'
          'A9o のオープンも成立します。相手が降りやすいほど広げられます。',
      commonMistake:
          '「A が付いているから強い」と考えてしまうミスです。'
          'エース自体は強いですが、キッカーが弱いオフスートエースは'
          '「相手も A を持っているときに必ず負けている」形になりがちです。',
      relatedRangeSpotId: '6max_utg_open',
    ),
    _q(
      id: 'pf002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      heroCards: 'Kh Th',
      villainProfile: VillainProfile.reg,
      history: ['UTG〜CO は全員フォールド'],
      question: '6MAX・100BB の BTN です。KTs でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'BTN は残りがブラインド 2 人だけで、フロップ以降は必ず最後に動けます。'
          'KTs はその中でも上位のハンドなので、レイズして主導権を取ります。',
      gtoView:
          'BTN のオープンレンジは全ポジションで最も広くなります。'
          '「降ろせる相手が 2 人しかいない」ことと「ポジションが確約されている」ことが理由で、'
          'KTs はその中でも上のほうに位置します。',
      practicalView:
          'ブラインドが 3Bet を多用する相手でも KTs は降りる必要のない強さです。'
          'ブラインドが受け身なら、さらに広げてかまいません。',
      commonMistake:
          'リンプ（コールだけで参加）してしまうミスです。'
          'リンプは主導権を渡すうえ、ブラインドに安くフロップを見せてしまいます。',
      relatedRangeSpotId: '6max_btn_open',
    ),
    _q(
      id: 'pf003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.utg,
      heroCards: 'As Kd',
      villainProfile: VillainProfile.reg,
      history: ['全員フォールドで、UTG のあなたに最初のアクションが回ってきた'],
      question: '6MAX・100BB の UTG です。AKo でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'AKo は UTG のレンジでも最上位クラスです。'
          '100BB あるので、レイズしてポットを作りながらフロップ以降も戦えます。',
      gtoView:
          '強いハンドほど「相手のレンジを狭めながらポットを大きくする」動きが得です。'
          'レイズはその両方を同時に達成します。',
      practicalView:
          'All-in が正解になるのは有効スタックが十数 BB まで浅いときです。'
          '100BB でオールインすると、コールしてくれるのは AA・KK だけになってしまいます。',
      commonMistake:
          '「強すぎるから相手を逃したくない」とリンプしてしまうミスです。'
          '一番強いレンジのときこそ、素直に大きいポットを作りにいきます。',
      relatedRangeSpotId: '6max_utg_open',
    ),
    _q(
      id: 'pf004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.hj,
      heroCards: 'Qc Jc',
      villainProfile: VillainProfile.reg,
      history: ['UTG フォールド。HJ のあなたの番'],
      question: '6MAX・100BB の HJ です。QJs でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'QJs はスーテッドでつながっており、フラッシュもストレートも狙えます。'
          '後ろが 4 人でも十分オープンできる強さです。',
      gtoView:
          'スーテッドであることは「同じ 2 枚のオフスート版」より明確に価値が高くなります。'
          'フラッシュという降ろされにくい強い完成形が増えるためです。',
      practicalView:
          '後ろのプレイヤーが 3Bet を連発してくるなら、'
          'こうした境界付近のハンドから外していきます。',
      commonMistake:
          'QJs と QJo を同じ強さだと思ってしまうミスです。'
          'スーテッドかどうかは、参加できるポジションが 1 つ変わる程度の差になります。',
    ),
    _q(
      id: 'pf005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '7d 2c',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'SB fold'],
      question: '6MAX・100BB の BB です。BTN のオープンに 72o でどうしますか。',
      choices: ['Fold', 'Call', '3Bet', 'All-in'],
      correctIndex: 0,
      shortReason:
          'BB はすでに 1BB 払っているので値段は安いですが、'
          '72o は最も弱いハンドで、しかもフロップ以降ずっと先に行動する側になります。'
          '安くても参加する価値がありません。',
      gtoView:
          '「安いから守る」という考え方には限界があります。'
          'ポットオッズが良くても、勝てる形をほとんど作れないハンドは'
          '手にした権利を実現できず、参加するほど損をします。',
      practicalView:
          'BB のディフェンスは「値段」と「フロップ以降で戦えるか」の両方で決めます。'
          '同じ値段でも 72s や 76o なら守れます。',
      commonMistake:
          '「BB は安いから何でも守る」と覚えてしまうミスです。'
          '守るべきなのは、フロップで何かを作れる可能性があるハンドだけです。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
    _q(
      id: 'pf006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.utg,
      heroCards: 'Kd Jh',
      tableType: TableType.nineMax,
      villainProfile: VillainProfile.unknown,
      history: ['9人テーブル。UTG のあなたに最初のアクションが回ってきた'],
      question: '9MAX・100BB の UTG です。KJo でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 3BB', 'All-in'],
      correctIndex: 0,
      shortReason:
          '9MAX の UTG は後ろに 8 人も残っています。'
          'KJo は誰かが参加してきた時点で AK・AQ・KQ に負けている形が多く、'
          '人数が増えるほどその危険が積み上がります。',
      gtoView:
          '同じハンドでも、6MAX の UTG と 9MAX の UTG では意味が変わります。'
          '後ろの人数が増えるほど「誰か 1 人は強い」確率が上がるため、レンジは狭くなります。',
      practicalView:
          '参加者の多いルースなテーブルほど、アーリーからのオープンは締めます。'
          '逆に全員がタイトなら少しだけ広げられます。',
      commonMistake:
          '6MAX で覚えたレンジを 9MAX にそのまま持ち込むミスです。'
          'ポジション名が同じでも、後ろの人数が違えば別のスポットです。',
      relatedRangeSpotId: '9max_utg_open',
    ),
    _q(
      id: 'pf007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.utg,
      heroCards: 'Ah Ac',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', 'HJ fold'],
      question: '6MAX・100BB の CO です。UTG のオープンに AA でどうしますか。',
      choices: ['Fold', 'Call', '3Bet 8BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'AA は最強のハンドです。100BB あるうちに 3Bet でポットを育てておかないと、'
          '一番勝っている場面で大きなポットを作れません。',
      gtoView:
          '最も強いハンドは、最も大きなポットで勝ちたいハンドです。'
          'プリフロップで積む金額が増えるほど、フロップ以降の各ベットも大きくなります。',
      practicalView:
          'All-in は 100BB では大きすぎます。'
          '相手が降りてしまい、2.5BB しか取れません。',
      commonMistake:
          '「トラップしたい」とコールしてしまうミスです。'
          'コールすると後ろの 3 人に安く入られ、'
          'AA が多人数戦で負ける確率まで上げてしまいます。',
    ),
    _q(
      id: 'pf008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      heroCards: '5h 5s',
      villainProfile: VillainProfile.reg,
      history: ['UTG・HJ ともにフォールド。CO のあなたの番'],
      question: '6MAX・100BB の CO です。55 でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'CO は後ろが 3 人だけで、レイズすればそのまま全員降りてポットを取れることもあります。'
          '55 はセットになれば強く、降ろせても勝ちという二段構えです。',
      gtoView:
          '小さいポケットペアの価値は「セットになる可能性」と'
          '「そのまま降ろせる可能性」の合計です。'
          'レイズは後者を丸ごと手に入れる動きです。',
      practicalView:
          '後ろがコールばかりでほとんど降りない相手なら、'
          '降ろす価値が減るぶん、セットになることに期待する比重が上がります。',
      commonMistake:
          '「小さいペアは安く見たい」とリンプしてしまうミスです。'
          'リンプは降ろす可能性をゼロにするうえ、複数人を呼び込みます。',
      relatedRangeSpotId: '6max_co_open',
    ),
    _q(
      id: 'pf009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      heroCards: 'Js 4d',
      villainProfile: VillainProfile.reg,
      history: ['UTG〜CO は全員フォールド'],
      question: '6MAX・100BB の BTN です。J4o でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in'],
      correctIndex: 0,
      shortReason:
          'BTN のレンジは広いですが、無制限ではありません。'
          'J4o は 2 枚がつながらず、スーテッドでもなく、'
          'フロップで作れる強い形がほとんどありません。',
      gtoView:
          '広いレンジの下限を決めるのは「フロップ以降で何を作れるか」です。'
          'ポジションがあっても、作れる形がなければ利益は出ません。',
      practicalView:
          'ブラインドが極端に降りやすい相手なら、'
          'ブラインドを奪う目的だけで広げる余地はあります。'
          'ただしコールされた後は捨てる前提のプレイになります。',
      commonMistake:
          '「BTN は何でもレイズしていい」と極端に覚えてしまうミスです。'
          'BTN が広いのは理由があってのことで、下限は存在します。',
      relatedRangeSpotId: '6max_btn_open',
    ),
    _q(
      id: 'pf010',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      heroCards: 'Kc Qd',
      villainProfile: VillainProfile.reg,
      history: ['UTG・HJ ともにフォールド。CO のあなたの番'],
      question: '6MAX・100BB の CO で KQo。オープンレイズのサイズはどれが標準ですか。',
      choices: ['Raise 1.1BB（ミニレイズ）', 'Raise 2.5BB', 'Raise 6BB', 'Raise 12BB'],
      correctIndex: 1,
      shortReason:
          '狙いはブラインドの 1.5BB を取ることです。'
          '2.5BB は「降りない相手には十分高く、外したときの損は小さい」バランスの取れたサイズです。',
      gtoView:
          'オープンサイズは「リスクとリターンの比」で決まります。'
          '12BB 払って 1.5BB を取りにいくと、成功してもほとんど増えず、'
          '失敗したときの損だけが大きくなります。',
      practicalView:
          'ブラインドがコールしすぎる相手なら、'
          'サイズを上げて強いレンジから多く取りにいく調整が有効です。'
          'オンラインの標準は 2〜2.5BB、ライブでは 3BB 前後が多く使われます。',
      commonMistake:
          'ミニレイズにしてしまうミスです。'
          '安すぎるとブラインドがほぼ全ハンドでコールでき、'
          'レイズした意味（レンジを狭める）が消えます。',
      relatedRangeSpotId: '6max_co_open',
    ),
    _q(
      id: 'pf011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      heroCards: 'Td 9d',
      tableType: TableType.nineMax,
      villainProfile: VillainProfile.reg,
      history: ['9人テーブル。UTG から CO まで全員フォールド'],
      question: '9MAX・100BB の BTN です。T9s でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 3BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          '9MAX でも、BTN まで回れば残りはブラインド 2 人だけです。'
          'この時点で状況は 6MAX の BTN と同じになり、T9s は十分オープンできます。',
      gtoView:
          'ポジションの強さを決めるのは「テーブルの人数」ではなく'
          '「自分より後ろに残っている人数」です。'
          '全員降りた後の BTN は、6MAX でも 9MAX でも同じ条件になります。',
      practicalView:
          'ブラインドがタイトなら、さらに広げてブラインドを奪いにいけます。'
          '逆に BB がよく守る相手ならレンジは締めます。',
      commonMistake:
          '「9MAX だから全部タイトに」と機械的に締めてしまうミスです。'
          'アーリーが降りた後のレイトポジションは、人数に関係なく広く戦えます。',
      relatedRangeSpotId: '9max_btn_open',
    ),
    _q(
      id: 'pf012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.utg,
      heroCards: '3c 3d',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', '他は全員フォールド'],
      question: '6MAX・100BB の BB です。UTG のオープンに 33 でどうしますか。',
      choices: ['Fold', 'Call', '3Bet 11BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          'あと 1.5BB 払えば 4BB のポットに参加でき、'
          'BB なのでこれ以上レイズされる心配もありません。'
          'セットになれば UTG の強いレンジから大きく取れます。',
      gtoView:
          'BB は「最後に行動するので値段が確定している」という利点があります。'
          '安く見て、当たったときだけ大きくするハンドに向いた場所です。',
      practicalView:
          '有効スタックが浅いとセットになったときの取り分が減るため、'
          '20BB 程度しかない場合はこのコールの価値が下がります。',
      commonMistake:
          '33 で 3Bet してしまうミスです。'
          '3Bet すると UTG の弱い部分が降りてしまい、'
          '残るのは 33 が負けているハンドばかりになります。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'pf013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'As 5s',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'SB fold'],
      question: '6MAX・100BB の BB です。BTN のオープンに A5s でどうしますか。',
      choices: ['Fold', 'Call', '3Bet 11BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'A5s は 3Bet ブラフに最も向いた形です。'
          'A を持っていることで相手の AA・AK・AQ の組み合わせを減らし、'
          'コールされてもフラッシュとストレート（A2345）に向かえます。',
      gtoView:
          '3Bet レンジは「強いバリュー」と「ブロッカーを持つ弱め」の二層で作ります。'
          '中間の強さのハンドはコールに回し、'
          'A5s のように自分では勝ちにくいがブロッカーが効くハンドを上の層に混ぜます。',
      practicalView:
          '相手が 4Bet を多用するタイプなら 3Bet ブラフは減らします。'
          '逆にコールばかりで降りない相手なら、'
          '降ろす効果が消えるのでコールしてフロップを見るほうが得です。',
      commonMistake:
          'A5s を「弱いエース」と考えて毎回フォールドしてしまうミスです。'
          '3Bet ブラフに求められるのは手の強さではなく、'
          'ブロッカーと、コールされたときの伸びしろです。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
    _q(
      id: 'pf014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.btn,
      heroCards: 'Ah Qd',
      potBb: 13,
      villainProfile: VillainProfile.reg,
      history: ['CO（あなた）raise 2.5BB', 'BTN 3Bet 9BB', 'ブラインドは両方フォールド'],
      question: '6MAX・100BB。CO でオープンしたところ BTN に 3Bet されました。AQo でどうしますか。',
      choices: ['Fold', 'Call', '4Bet 22BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          'AQo は強いですが、4Bet すると降りてくれるのは AQo より弱い手だけで、'
          '残るのは AA・KK・AK など負けているレンジです。'
          'コールしてフロップを見るのが素直です。',
      gtoView:
          '4Bet は「相手のレンジを、自分がまだ勝っている部分ごと降ろしてしまう」動きです。'
          'AQo のような上位だが最上位ではないハンドは、'
          'レンジを狭めないコールのほうが噛み合います。',
      practicalView:
          'BTN が 3Bet を乱発するタイプなら 4Bet の価値が上がり、'
          '3Bet が最強クラスしかない相手ならフォールドも十分ありえます。'
          '相手の 3Bet レンジの広さが、そのまま判断を動かします。',
      commonMistake:
          '「AQ は強いから 4Bet」と手の絶対的な強さだけで決めてしまうミスです。'
          '重要なのは、その動きに対して相手が何を残すかです。',
    ),
    _q(
      id: 'pf015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.utg,
      heroCards: 'Qh Qs',
      potBb: 6.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', 'CO call 2.5BB', 'あなた（BTN）の番'],
      question: '6MAX・100BB の BTN です。UTG オープン + CO コールに QQ でどうしますか。',
      choices: ['Fold', 'Call', '3Bet（スクイーズ）12BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'すでに 2 人が 2.5BB ずつ入れていて、取りにいく価値のあるポットができています。'
          'QQ は今ほぼ最強なので、ポットを大きくしつつ'
          'ブラインドを安く入らせないためにレイズします。',
      gtoView:
          '複数人が参加した後の 3Bet（スクイーズ）は、'
          '「すでに置かれているチップの量」がそのまま動機になります。'
          '取れる額が増えているぶん、通常の 3Bet より広く行えます。',
      practicalView:
          'CO がコールしすぎるタイプなら、'
          'スクイーズのサイズを上げてバリューを厚く取りにいきます。',
      commonMistake:
          'QQ でコールして 4 人でフロップを見てしまうミスです。'
          '多人数になるほど、オーバーペアが最後まで勝っている確率は下がります。',
    ),
    _q(
      id: 'pf016',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.mp,
      heroCards: 'Ad Tc',
      potBb: 2.5,
      tableType: TableType.nineMax,
      villainProfile: VillainProfile.loosePassive,
      history: ['MP がリンプ（1BB コールのみ）', 'LJ・HJ はフォールド'],
      question: '9MAX・100BB の CO です。ルース・パッシブなリンパーがいます。ATo でどうしますか。',
      choices: ['Fold', 'Call（オーバーリンプ）', 'Raise 4.5BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'リンプするレンジは弱く広いので、ATo は明確に勝っています。'
          '大きめにレイズして他を降ろし、弱い相手と 1 対 1 を作りにいきます。',
      gtoView:
          'レイズには「バリュー」と「参加人数を減らす」という 2 つの役割があります。'
          '弱い相手が 1 人いるときは、後者の価値が特に大きくなります。',
      practicalView:
          'サイズを通常の 2.5BB ではなく 4.5BB 程度に上げるのは、'
          'リンパーが 2.5BB ではまず降りず、'
          '後ろのプレイヤーにも安い参加を許してしまうためです。',
      commonMistake:
          '一緒にリンプしてしまうミスです。'
          '一番弱い相手と 2 人で戦えるはずの場面で、'
          '5 人参加の運任せなポットにしてしまいます。',
    ),
    _q(
      id: 'pf017',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      heroCards: 'Ah Jc',
      stackBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['有効スタック 20BB', 'UTG〜CO は全員フォールド'],
      question: '6MAX・有効スタック 20BB の BTN です。AJo でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2BB', 'All-in 20BB'],
      correctIndex: 2,
      shortReason:
          '20BB はまだフロップを戦えるスタックです。'
          '2BB のレイズならブラインドを降ろせることも多く、'
          '3Bet された場合に降りるという選択肢も残せます。',
      gtoView:
          'オールインが標準になるのは、レイズしてから降りる余地がなくなる深さ'
          '（おおむね 10〜15BB 以下）です。'
          '20BB ではまだレイズ・フォールドという選択肢が生きています。',
      practicalView:
          'ブラインドが頻繁にオールインを返してくる相手なら、'
          '2BB オープンの価値が下がるためレンジを締めます。',
      commonMistake:
          '「浅いからとりあえずオールイン」と決めてしまうミスです。'
          '20BB を賭けて 1.5BB を取りにいく動きで、'
          'コールされるときはほぼ負けています。',
    ),
    _q(
      id: 'pf018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.sb,
      villain: Position.bb,
      heroCards: 'Ac 8d',
      stackBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['有効スタック 12BB', '全員フォールドで SB のあなたの番'],
      question: '6MAX・有効スタック 12BB の SB です。A8o でどうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'All-in 12BB'],
      correctIndex: 3,
      shortReason:
          '12BB では、レイズして降りる余地がほとんどありません。'
          'A8o は BB のコールレンジに対して十分戦える強さなので、'
          '降ろす価値と当たったときの勝率をまとめて取りにいきます。',
      gtoView:
          'スタックが浅いほど「レイズ後にフォールドする」選択肢の価値が下がります。'
          '選択肢が減った結果、オールインとフォールドの二択に収束していきます。',
      practicalView:
          'BB がほとんどコールしない相手なら、'
          'オールインの成功率が上がるのでさらに広げられます。'
          '逆に何でもコールする相手なら、勝てるハンドだけに絞ります。',
      commonMistake:
          '浅いスタックでリンプしてしまうミスです。'
          '降ろす機会を捨てたうえ、不利なポジションでフロップを迎えることになります。',
      relatedRangeSpotId: '6max_sb_open',
    ),
    _q(
      id: 'pf019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kh Ks',
      potBb: 14,
      villainProfile: VillainProfile.reg,
      history: ['BTN（あなた）raise 2.5BB', 'SB fold', 'BB 3Bet 11BB'],
      question: '6MAX・100BB。BTN オープンに BB が 3Bet してきました。KK でどうしますか。',
      choices: ['Fold', 'Call', '4Bet 24BB', 'All-in 100BB'],
      correctIndex: 2,
      shortReason:
          'KK は 4Bet してポットを膨らませたいハンドです。'
          '24BB 程度なら相手の QQ・JJ・AK も続けてくれるので、'
          '負けている AA だけを相手にせずに済みます。',
      gtoView:
          '4Bet のサイズは「相手にどこまで続けてほしいか」で決めます。'
          '大きすぎると AA しか残らず、小さすぎると相手に良いオッズを与えます。',
      practicalView:
          '相手が 3Bet ブラフを多用するタイプなら、'
          '4Bet に対してさらに返してくる分だけ利益が増えます。'
          '3Bet が最強クラスしかない相手なら、KK でもコールに寄せる判断があります。',
      commonMistake:
          '100BB でいきなりオールインしてしまうミスです。'
          'コールしてくれるのは AA だけになり、'
          '勝っている相手（QQ・JJ・AK）を全部逃がします。',
    ),
    _q(
      id: 'pf020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.sb,
      heroCards: 'Jd 8c',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['全員フォールド', 'SB raise 3BB'],
      question: '6MAX・100BB。SB の 3BB オープンに BB で J8o。どうしますか。',
      choices: ['Fold', 'Call', '3Bet 10BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          '2BB 払って 6BB のポットを争うので、必要な勝率は 2÷6 ＝ 約33% です。'
          'しかも SB vs BB は BB が後に動ける唯一のスポットで、'
          'J8o でも十分その勝率を実現できます。',
      gtoView:
          'BB のディフェンスは「値段」と「ポジション」の掛け算で決まります。'
          'SB 相手のときだけは BB が後に動けるため、'
          '他のポジション相手より大幅に広く守れます。',
      practicalView:
          'SB が極端にタイトなレンジしかオープンしないなら、'
          '同じ値段でも降りる寄りに調整します。',
      commonMistake:
          '「BB はいつも不利」と思い込んで降りすぎるミスです。'
          'SB 相手のときだけはポジションが逆転します。',
    ),
    _q(
      id: 'pf021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.utg,
      heroCards: '7s 6s',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: [
        'UTG raise 2.5BB',
        'HJ・CO はフォールド',
        'ブラインドは 2 人ともタイトで、スクイーズはほぼしてこない',
      ],
      question: '6MAX・100BB の BTN です。UTG のオープンに 76s でどうしますか。',
      choices: ['Fold', 'Call', '3Bet 9BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          'BTN なのでフロップ以降は必ず最後に動けます。'
          '76s はストレートやフラッシュという「相手に見えない強い形」を作れるので、'
          '100BB の深さなら当たったときの取り分が値段に見合います。',
      gtoView:
          'コールで参加できるかどうかは、ポジションと'
          '「後ろから割り込まれる危険」で決まります。'
          'BTN で、しかもブラインドがスクイーズしてこないなら条件が揃います。',
      practicalView:
          '同じ 76s でも、CO でコールすると後ろに 3 人残るため条件が悪くなります。'
          'ブラインドがスクイーズを多用する相手でも、'
          'コールの価値は大きく下がります。',
      commonMistake:
          '「スーテッドコネクターはどこからでも参加できる」と考えるミスです。'
          '安く見られてポジションがあるときにだけ価値が出るハンドです。',
    ),
    _q(
      id: 'pf022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.sb,
      villain: Position.btn,
      heroCards: '7h 6h',
      potBb: 14,
      villainProfile: VillainProfile.reg,
      history: ['SB（あなた）raise 3BB', 'BB fold', 'BTN 3Bet 10BB'],
      question: '6MAX・100BB。SB でオープンしたら BTN に 3Bet されました。76s でどうしますか。',
      choices: ['Fold', 'Call', '4Bet 24BB', 'All-in'],
      correctIndex: 0,
      shortReason:
          '76s は「安く見て当たったら大きく」というハンドですが、'
          '3Bet 後のポットは安くありません。'
          'しかも SB なのでフロップ以降ずっと先に動く側で、当たらなかった回に降ろす手段もありません。',
      gtoView:
          '同じハンドでも、ポジションが変われば価値が変わります。'
          '76s が BTN で機能するのは「最後に動ける」からで、'
          'その前提が消えると成立しません。',
      practicalView:
          '有効スタックが 200BB あるなど、当たったときの取り分が跳ね上がる状況なら'
          'コールの余地が生まれます。100BB では足りません。',
      commonMistake:
          '「一度レイズしたから引けない」と考えてコールしてしまうミスです。'
          'すでに入れた 3BB は、これからの判断とは無関係です。',
    ),
    _q(
      id: 'pf023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.utg,
      heroCards: '6d 5d',
      villainProfile: VillainProfile.unknown,
      history: ['オンラインの低レート（レーキが重い）', '全員フォールドで UTG のあなたの番'],
      question: '6MAX・100BB の UTG です。レーキの重い低レートで 65s。どうしますか。',
      choices: ['Fold', 'Call（リンプ）', 'Raise 2.5BB', 'Raise 5BB'],
      correctIndex: 0,
      shortReason:
          '65s は「安く入って当たったときに大きく取る」ハンドですが、'
          'UTG では後ろに 5 人残り、当たらない回にポットを取る手段もありません。'
          'レーキが重いほど、こうした僅差のハンドは赤字側に落ちます。',
      gtoView:
          'レーキはポットが動くたびに引かれるため、'
          '「わずかに勝っているだけ」のハンドから先に利益が消えます。'
          'レーキの重い環境ほど、境界線上のハンドは降りる側に寄ります。',
      practicalView:
          '同じ 65s でも、BTN や CO からなら降ろす手段があるためオープンできます。'
          'レーキの軽い高レートでは UTG からの下限も少し広がります。',
      commonMistake:
          '「スーテッドコネクターはどこでも儲かる」と覚えてしまうミスです。'
          'このハンドの利益は、ポジションと値段の条件が揃ってはじめて出ます。',
      relatedRangeSpotId: '6max_utg_open',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'pf024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.btn,
      heroCards: 'Ad 5d',
      potBb: 13,
      villainProfile: VillainProfile.reg,
      history: ['CO（あなた）raise 2.5BB', 'BTN 3Bet 9BB', 'ブラインドは両方フォールド'],
      question: '6MAX・100BB。CO オープンに BTN が 3Bet。A5s でどうしますか。',
      choices: ['Fold', 'Call', '4Bet 21BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'A を持っていることで、相手の 4Bet に耐える AA・AK・AQ の組み合わせが減ります。'
          'コール続行するには弱すぎ、しかも不利なポジションなので、'
          '降ろす目的の 4Bet に回すのが最も価値が出ます。',
      gtoView:
          '4Bet ブラフに選ぶべきなのは「相手の続行レンジをブロックしていて、'
          'かつコールでは使いづらいハンド」です。'
          'A5s はエースブロッカーを持ち、コールされてもフラッシュと A2345 に向かえます。',
      practicalView:
          '相手が 4Bet にほとんど降りないタイプなら、この 4Bet は成立しません。'
          'その場合は素直にフォールドします。'
          '4Bet ブラフは「相手が降りる」ことが前提の動きです。',
      commonMistake:
          '4Bet ブラフに 76s のような「降ろせても価値のない」ハンドを選ぶミスです。'
          'ブロッカーがないハンドは、相手が続行する確率をまったく下げられません。',
    ),
    _q(
      id: 'pf025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.co,
      heroCards: 'As Kh',
      potBb: 12.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', 'HJ fold', 'CO 3Bet 8.5BB', 'あなた（BTN）の番'],
      question: '6MAX・100BB の BTN です。UTG オープンに CO が 3Bet。AKo でどうしますか。',
      choices: ['Fold', 'Call', '4Bet 20BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'AKo は 2 人のレンジ相手でも上位にいるハンドです。'
          'コールするとブラインドまで安く入れてしまい、'
          'しかも UTG がまだ 4Bet できる状態が残ります。'
          '自分から 4Bet して主導権とポジションを両取りします。',
      gtoView:
          '割り込みの 3Bet（スクイーズ）に対する 4Bet は、'
          '「後ろにまだ動く人が残っているか」で価値が変わります。'
          'ここで動かないと、UTG のアクションを待つ側に回ることになります。',
      practicalView:
          'CO が UTG のオープンに対してタイトにしか 3Bet しない相手なら、'
          'AKo でもコールに寄せる判断がありえます。'
          '3Bet レンジの広さがそのまま答えを動かします。',
      commonMistake:
          'AK を「コールして様子を見る」ハンドとして扱うミスです。'
          '3 人が絡む場面でコールすると、最も避けたい'
          '「弱いレンジのまま多人数でフロップ」という形になります。',
    ),
    _q(
      id: 'pf026',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.utg,
      heroCards: '5c 5h',
      potBb: 4,
      stackBb: 200,
      villainProfile: VillainProfile.tightAggressive,
      history: ['有効スタック 200BB', 'UTG raise 2.5BB', 'HJ・CO はフォールド'],
      question: '6MAX・有効スタック 200BB の BTN です。タイトな UTG のオープンに 55。どうしますか。',
      choices: ['Fold', 'Call', '3Bet 9BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          '55 がフロップでセットになる確率は約 12%（およそ 8.5 回に 1 回）です。'
          '当たらない回は捨てる前提でも、200BB という深さなら'
          '当たった回にタイトな相手の強いレンジから大きく取れます。',
      gtoView:
          '小さいポケットペアのコールは「セットになったときに'
          'どれだけ払わせられるか」で成立します。'
          '必要な取り分の目安は、支払う額のおよそ 10〜15 倍です。',
      practicalView:
          '同じ 55 でも有効スタックが 40BB しかなければ、'
          'セットになっても取れる額が足りずフォールドが正解になります。'
          '深さがそのまま答えを変える代表例です。',
      commonMistake:
          '3Bet してしまうミスです。'
          '55 で 3Bet すると、降りるのは 55 に負けている手ばかりで、'
          '続けてくるのは 55 が勝てないハンドばかりになります。',
    ),
    _q(
      id: 'pf027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.hj,
      villain: Position.btn,
      heroCards: '9d 9h',
      potBb: 18.5,
      villainProfile: VillainProfile.reg,
      history: [
        'UTG raise 2.5BB',
        'HJ（あなた）call 2.5BB',
        'BTN 3Bet 12BB（スクイーズ）',
        'ブラインドと UTG はフォールド',
      ],
      question: '6MAX・100BB。UTG にコールした直後、BTN にスクイーズされました。99 でどうしますか。',
      choices: ['Fold', 'Call', '4Bet 28BB', 'All-in'],
      correctIndex: 0,
      shortReason:
          'あと 9.5BB 払う必要があり、残る有効スタックは約 88BB です。'
          'セット狙いに必要な「支払いの 10 倍以上を取り返せる」条件を満たしません。'
          'しかも相手より先に動く側で、レンジも弱く見られています。',
      gtoView:
          'コールで参加した時点で、こちらのレンジからは最上位が抜けています。'
          'その「上限が見えている」レンジで、'
          '強いレンジ相手に不利なポジションから戦うのは不利が重なります。',
      practicalView:
          'BTN が明らかにスクイーズを多用する相手なら、'
          '99 で 4Bet して降ろしにいく調整もありえます。'
          'ただしその場合も、コールで受けるのは避けます。',
      commonMistake:
          '「ポケットペアだからセットを見にいく」と機械的にコールするミスです。'
          'セット狙いが成立するかどうかは、値段と残りスタックの比で決まります。',
    ),
    _q(
      id: 'pf028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.utg,
      heroCards: 'Qd 8c',
      potBb: 4,
      villainProfile: VillainProfile.tightAggressive,
      history: ['UTG（タイトなレギュラー）raise 2.5BB', '他は全員フォールド'],
      question: '6MAX・100BB の BB です。タイトな UTG のオープンに Q8o。どうしますか。',
      choices: ['Fold', 'Call', '3Bet 11BB', 'All-in'],
      correctIndex: 0,
      shortReason:
          '必要な勝率は 1.5÷5.5 ＝ 約27% で、Q8o の見かけの勝率はそれを超えます。'
          'ですが Q8o が Q や 8 でペアを作ったとき、'
          'タイトな相手のレンジ（AQ・KQ・AA〜TT）にはほぼ負けています。',
      gtoView:
          '見かけの勝率と、実際に取れる勝率は別物です。'
          '「当たったときに負けている」形が多いハンドは、'
          '不利なポジションではその差がさらに広がります。',
      practicalView:
          '同じ Q8o でも、相手が BTN から広くオープンしている場面なら守れます。'
          '相手のレンジが狭いほど、支配される危険が増します。',
      commonMistake:
          'ポットオッズの計算だけで判断してしまうミスです。'
          '計算はあくまで出発点で、'
          'その勝率をフロップ以降で実際に取れるかどうかまで含めて考えます。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
    _q(
      id: 'pf029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.utg,
      heroCards: '6h 5h',
      potBb: 9,
      villainProfile: VillainProfile.loosePassive,
      history: [
        'UTG raise 2.5BB',
        'HJ call 2.5BB',
        'CO call 2.5BB',
        'あなた（BTN）の番。ブラインドは 2 人ともタイト',
      ],
      question: '6MAX・100BB の BTN です。3 人が参加している状況で 65s。どうしますか。',
      choices: ['Fold', 'Call', '3Bet 14BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          '2.5BB 払って 9BB のポットに、最後に動ける立場で参加できます。'
          '65s が作るストレートとフラッシュは相手から見えにくく、'
          '人数が多いほど支払ってくれる相手も増えます。',
      gtoView:
          '多人数のポットでは、ハンドの価値の順位が入れ替わります。'
          'AJo のような支配されやすいハンドは価値を落とし、'
          '65s のような「作れば圧倒的に強い」ハンドは価値を上げます。',
      practicalView:
          'ブラインドがスクイーズを多用する相手なら、'
          '2.5BB のつもりが 14BB になる危険があるためコールの価値が下がります。',
      commonMistake:
          '「人数が多いから強い手だけで参加する」と一律に締めてしまうミスです。'
          '締めるべきは支配されやすいオフスートのブロードウェイで、'
          'スーテッドコネクターは逆に価値が上がります。',
    ),
    _q(
      id: 'pf030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qc Qd',
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'SB fold'],
      question:
          '6MAX・100BB の BB です。BTN の 2.5BB オープンに QQ で 3Bet します。サイズはどれが適切ですか。',
      choices: ['3Bet 5BB', '3Bet 7.5BB', '3Bet 11BB', '3Bet 30BB'],
      correctIndex: 2,
      shortReason:
          '3Bet の後もずっと先に動く側なので、'
          'ポジションの不利を値段で埋める必要があります。'
          '11BB 程度まで上げると、相手が良いオッズで気軽にコールできなくなります。',
      gtoView:
          '3Bet サイズは、自分にポジションがあるかどうかで変わります。'
          'ポジションがあるときは小さめ（オープンの 3 倍程度）、'
          'ないときは大きめ（4 倍以上）にして、相手のコール範囲を狭めます。',
      practicalView:
          '相手が 3Bet にほとんど降りないタイプなら、'
          'QQ のような強いハンドではサイズをさらに上げてバリューを取りにいきます。',
      commonMistake:
          '5BB のような小さい 3Bet にしてしまうミスです。'
          'BTN は良いオッズとポジションの両方を得るため、'
          '広いレンジで気軽にコールしてきます。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
  ];
}
