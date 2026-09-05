import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// ポットオッズの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class PotOddsQuizzes {
  static List<Quiz> get all => _quizzes;

  static Quiz _q({
    required String id,
    required QuizDifficulty difficulty,
    Street street = Street.flop,
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
      category: QuizCategory.potOdds,
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
      tagActionTypes: true,
    );
  }

  static final List<Quiz> _quizzes = [
    // ── 初級 ──────────────────────────────────────────────
    _q(
      id: 'po001',
      difficulty: QuizDifficulty.beginner,
      street: Street.river,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qc Qd',
      board: '9h 6s 2d Jc 4c',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 12BB', 'BTN がポットの 1/2 にあたる 6BB をベット'],
      question: '6MAX・100BB。ポット 12BB に対して 6BB のベットです。コールに必要な勝率はおよそ何%ですか。',
      choices: ['約20%', '約25%', '約33%', '約50%'],
      correctIndex: 1,
      shortReason:
          'コール額 6BB ÷（元のポット 12 + 相手のベット 6 + 自分のコール 6 ＝ 24BB）＝ 25%。'
          '25% 以上の確率で勝てるならコールが利益になります。',
      gtoView:
          'ベットサイズは、そのまま「コール側に必要な勝率」を決めます。'
          'サイズが大きいほど必要勝率が上がり、コールできるハンドが減ります。',
      practicalView:
          '実戦では 25% をきっちり計算するのではなく、'
          '「4 回に 1 回勝てそうか」で考えると速く判断できます。'
          'ブラフの少ない相手なら降りる寄りになります。',
      commonMistake:
          '分母に自分のコール額を入れ忘れるミスです。'
          '6 ÷ 18 ＝ 33% としてしまうと、必要勝率を高く見積もりすぎて降りすぎになります。',
    ),
    _q(
      id: 'po002',
      difficulty: QuizDifficulty.beginner,
      street: Street.river,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Jd',
      board: 'Kd 9c 5h 3s 2c',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 10BB', 'BB がポットと同額の 10BB をベット'],
      question: '6MAX・100BB。ポット 10BB にポットサイズ（10BB）のベット。必要な勝率はおよそ何%ですか。',
      choices: ['約25%', '約33%', '約40%', '約50%'],
      correctIndex: 1,
      shortReason:
          '10 ÷（10 + 10 + 10 ＝ 30）＝ 33%。'
          'ポットサイズのベットに対しては、3 回に 1 回勝てれば元が取れます。',
      gtoView:
          'ポットサイズのベットは「必要勝率 33%」と覚えておくと、'
          'リバーの判断が一気に速くなります。'
          '1/2 ポットなら 25%、2 倍のオーバーベットなら 40% です。',
      practicalView:
          '大きいベットほど必要勝率が上がるため、'
          '相手が大きく打ってきたときほど、'
          '「この相手はここでブラフをするタイプか」の見極めが重要になります。',
      commonMistake:
          '「ポットサイズだから 50% 必要」と考えてしまうミスです。'
          '相手のベットもポットに加わるため、実際に必要なのは 33% です。',
    ),
    _q(
      id: 'po003',
      difficulty: QuizDifficulty.beginner,
      street: Street.river,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Tc Td',
      board: 'As 8d 6h 4c 2s',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 20BB', 'BB がポットの 1/4 にあたる 5BB をベット'],
      question: '6MAX・100BB。ポット 20BB に 5BB の小さいベット。必要な勝率はおよそ何%ですか。',
      choices: ['約17%', '約25%', '約33%', '約40%'],
      correctIndex: 0,
      shortReason:
          '5 ÷（20 + 5 + 5 ＝ 30）＝ 約17%。'
          '6 回に 1 回勝てれば元が取れる、非常に安いコールです。',
      gtoView:
          '小さいベットは相手にとって安く仕掛けられる代わりに、'
          'こちらに非常に良いオッズを与えます。'
          'だからこそ、小さいベットには広く受けるのが基本になります。',
      practicalView:
          '必要勝率 17% は「ほとんど負けていると分かっていてもコールできる」水準です。'
          '小さいベットに対して降りすぎる癖は、'
          'そのまま相手に少額ブラフを許す穴になります。',
      commonMistake:
          '「勝っている自信がないから降りる」と判断してしまうミスです。'
          '必要なのは自信ではなく、17% を超えているかどうかです。',
    ),
    _q(
      id: 'po004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Ah 5h 2c',
      potBb: 6,
      villainProfile: VillainProfile.reg,
      history: ['フロップでフラッシュドローになった', 'ターンの 1 枚だけを考える'],
      question: '6MAX・100BB。フラッシュドロー（アウツ 9 枚）です。次の 1 枚で完成する確率はおよそ何%ですか。',
      choices: ['約9%', '約18%', '約27%', '約36%'],
      correctIndex: 1,
      shortReason:
          '残り 1 枚だけを考えるときは「アウツ × 2」で見積もります。'
          '9 × 2 ＝ 約18%（正確には 9÷47 ＝ 約19%）です。',
      gtoView:
          'アウツから確率を出すのは、ソルバーの出力ではなく単純な数え上げです。'
          '見えていないカードは 47 枚（52 − 自分の 2 枚 − ボード 3 枚）で、'
          'そのうち何枚が自分を助けるかを数えるだけです。',
      practicalView:
          '実戦では「1 枚なら ×2、2 枚見られるなら ×4」とだけ覚えておけば十分です。'
          '正確な値との差は数%しかありません。',
      commonMistake:
          '1 枚しか見られない場面で ×4 を使ってしまうミスです。'
          '確率を 2 倍に見積もることになり、コールしすぎの原因になります。',
    ),
    _q(
      id: 'po005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '9h 8h',
      board: '7c 6d 2s',
      potBb: 6,
      villainProfile: VillainProfile.reg,
      history: ['BB check', 'あなた（BTN）はストレートドローになっている'],
      question: '6MAX・100BB。98 で 762 のフロップ。ストレートのアウツは何枚ですか。',
      choices: ['4枚', '6枚', '8枚', '12枚'],
      correctIndex: 2,
      shortReason:
          '9・8・7・6 が揃っているので、T か 5 でストレートが完成します。'
          'T が 4 枚、5 が 4 枚で合計 8 枚。両端が開いた「オープンエンド」です。',
      gtoView:
          'アウツの枚数はそのままドローの強さです。'
          '8 枚のオープンエンドは、フロップからリバーまでで'
          'およそ 3 回に 1 回完成する強いドローになります。',
      practicalView:
          '8 アウツあると、フォールドエクイティと合わせて'
          'セミブラフとして十分に打てる強さになります。',
      commonMistake:
          '片側だけ数えて 4 枚と答えてしまうミスです。'
          'T でも 5 でも完成することを確認してください。',
    ),
    _q(
      id: 'po006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Jh Th',
      board: '9c 7d 2s',
      potBb: 6,
      villainProfile: VillainProfile.reg,
      history: ['BB check', 'あなた（CO）はガットショットになっている'],
      question: '6MAX・100BB。JT で 972 のフロップ。ストレートのアウツは何枚ですか。',
      choices: ['2枚', '4枚', '6枚', '8枚'],
      correctIndex: 1,
      shortReason:
          'J・T・9 と 7 があるので、間の 8 だけがストレートを完成させます。'
          '8 は 4 枚なのでアウツは 4 枚。内側が抜けた「ガットショット」です。',
      gtoView:
          '同じストレートドローでも、'
          'オープンエンド（8 枚）とガットショット（4 枚）では強さが 2 倍違います。'
          'どちらなのかを毎回確認する習慣が大切です。',
      practicalView:
          '4 アウツはそれだけでコールするには弱く、'
          'ブラフの材料として使うか、他の要素（オーバーカードやバックドア）と'
          '合わせて考えることになります。',
      commonMistake:
          '「ストレートドロー」とひとまとめにして、'
          'オープンエンドと同じ強さだと思ってしまうミスです。',
    ),
    _q(
      id: 'po007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Ah 5h 2c',
      potBb: 6,
      villainProfile: VillainProfile.reg,
      history: ['フロップでフラッシュドローになった', 'ターンとリバーの 2 枚を見られる前提で考える'],
      question: '6MAX・100BB。フラッシュドロー（アウツ 9 枚）で、2 枚とも見られる場合の完成率はおよそ何%ですか。',
      choices: ['約18%', '約27%', '約35%', '約45%'],
      correctIndex: 2,
      shortReason:
          '2 枚見られるときは「アウツ × 4」。'
          '9 × 4 ＝ 約36%（正確には約35%）です。',
      gtoView:
          'この数字が使えるのは「本当に 2 枚とも見られる」ときだけです。'
          '相手にまだベットが残っている場面では、'
          'ターンでもう一度払わされる可能性を織り込む必要があります。',
      practicalView:
          'ターンでさらに打たれる可能性が高い相手なら、'
          'ターン 1 枚ぶんの約19% で判断するほうが安全です。'
          '相手がオールインで、もう追加の支払いがない場合だけ 35% を使えます。',
      commonMistake:
          '相手にまだスタックが残っているのに 35% で計算してしまうミスです。'
          '実際にはターンでも払わされるため、想定より高くつきます。',
    ),
    _q(
      id: 'po008',
      difficulty: QuizDifficulty.beginner,
      street: Street.turn,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Ah 5h 2c 8d',
      potBb: 8,
      stackBb: 4,
      villainProfile: VillainProfile.reg,
      history: [
        'ターン時点のポットは 8BB',
        'BTN の残りスタックは 4BB で、その 4BB をオールイン',
        '追加で払わされる場面はもう無い',
      ],
      question: '6MAX。ポット 8BB に 4BB のオールイン。フラッシュドロー（9 アウツ）でどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'まず必要勝率を計算してから決める'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 4 ÷（8 + 4 + 4 ＝ 16）＝ 25%。'
          '残り 1 枚での完成率は約19% なので足りません。'
          '相手はオールインで、当たった後に追加で取れる分もありません。',
      gtoView:
          'オールインに対するコールは、'
          '必要勝率と完成率を直接比べるだけで答えが出ます。'
          '将来の駆け引きが残っていないぶん、判断が純粋な計算になります。',
      practicalView:
          '同じフラッシュドローでも、相手にスタックが残っていれば'
          '「当たったときに追加で取れる分」を足して考えられます。'
          'オールインではその上乗せがゼロになります。',
      commonMistake:
          '「安いから」と払ってしまうミスです。'
          '安いかどうかは金額ではなく、必要勝率と完成率の差で決まります。',
    ),
    _q(
      id: 'po009',
      difficulty: QuizDifficulty.beginner,
      street: Street.turn,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Ah 5h 2c 8d',
      potBb: 12,
      stackBb: 2,
      villainProfile: VillainProfile.reg,
      history: [
        'ターン時点のポットは 12BB',
        'BTN の残りスタックは 2BB で、その 2BB をオールイン',
        '追加で払わされる場面はもう無い',
      ],
      question: '6MAX。ポット 12BB に 2BB のオールイン。フラッシュドロー（9 アウツ）でどうしますか。',
      choices: ['Fold', 'Call', '完成率が 25% を超えないので Fold', 'ポットが大きいので Fold'],
      correctIndex: 1,
      shortReason:
          '必要勝率は 2 ÷（12 + 2 + 2 ＝ 16）＝ 12.5%。'
          '完成率は約19% なので上回っています。コールが利益になります。',
      gtoView:
          '前問とドローの強さはまったく同じで、変わったのはベットサイズだけです。'
          '同じハンドでも、値段が変われば答えが逆になります。',
      practicalView:
          '「このドローはコールできる／できない」とハンド単体で覚えないでください。'
          '毎回、そのときの値段と比べて決めます。',
      commonMistake:
          '前に似た場面で降りたから今回も降りる、と過去の判断を持ち込むミスです。'
          '必要勝率はベットサイズごとに毎回変わります。',
    ),
    _q(
      id: 'po010',
      difficulty: QuizDifficulty.beginner,
      street: Street.river,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kd Qs',
      board: 'Kh 8c 5d 3s 2h',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 10BB', 'BB が 5BB（ポットの 1/2）をベット'],
      question:
          '6MAX・100BB。ポット 10BB に 5BB のベット。相手のブラフが自動的に得にならないためには、'
          '自分のレンジの何%を降りずに続ける必要がありますか。',
      choices: ['約33%', '約50%', '約67%', '約75%'],
      correctIndex: 2,
      shortReason:
          'ポット ÷（ポット + ベット）＝ 10 ÷ 15 ＝ 約67%。'
          'これを下回ると、相手はどんな 2 枚でも打つだけで利益が出るようになります。',
      gtoView:
          'これは「最低限守るべき頻度（MDF）」と呼ばれます。'
          '必要勝率（コールする側の計算）とは別物で、'
          'こちらは「レンジ全体でどれだけ降りずに残すか」の話です。',
      practicalView:
          'ブラフをほとんどしない相手に対しては、'
          'この 67% を守る必要はありません。'
          'MDF はあくまで「相手が正しくブラフしてくる場合」の下限です。',
      commonMistake:
          '必要勝率 25% と混同して「25% だけ守ればいい」と考えるミスです。'
          '25% は 1 ハンドがコールできるかどうかの基準、'
          '67% はレンジ全体で降りすぎていないかの基準です。',
    ),
    _q(
      id: 'po011',
      difficulty: QuizDifficulty.beginner,
      street: Street.river,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '7c 6c',
      board: 'Ad Kh 9s 4d 2s',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 10BB', 'BB check', 'あなたは何も完成していない'],
      question: '6MAX・100BB。ポット 10BB に 5BB をブラフします。何%成功すれば元が取れますか。',
      choices: ['約25%', '約33%', '約50%', '約67%'],
      correctIndex: 1,
      shortReason:
          'ベット ÷（ポット + ベット）＝ 5 ÷ 15 ＝ 約33%。'
          '3 回に 1 回降ろせれば、それだけで損はしません。',
      gtoView:
          'ブラフの損益分岐点はベットサイズだけで決まります。'
          '小さく打つほど必要な成功率は下がり、大きく打つほど上がります。',
      practicalView:
          '相手が「1/2 ポットには 3 回に 1 回以上降りる」タイプなら、'
          'このブラフは成立します。'
          'めったに降りない相手なら、サイズを変えても成立しません。',
      commonMistake:
          '「ブラフは半分以上成功しないと意味がない」と考えるミスです。'
          '実際は 33% で十分で、それ以上ならすべて利益になります。',
    ),
    _q(
      id: 'po012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac Kd',
      board: 'Kc 8h 3d',
      potBb: 10,
      stackBb: 40,
      villainProfile: VillainProfile.reg,
      history: ['フロップ時点のポットは 10BB', '有効スタックは 40BB'],
      question: '6MAX。ポット 10BB、有効スタック 40BB。SPR（スタック・ポット比）はいくつですか。',
      choices: ['0.25', '2.5', '4', '10'],
      correctIndex: 2,
      shortReason:
          'SPR ＝ 有効スタック ÷ ポット ＝ 40 ÷ 10 ＝ 4。'
          '「あと何ポットぶん賭けられるか」を表す数字です。',
      gtoView:
          'SPR はフロップ以降の戦い方を決める最重要の数字です。'
          'SPR が小さいほど、トップペア級でもスタックを入れて良い場面が増えます。',
      practicalView:
          'SPR 1 以下ならトップペアでもオールインを検討でき、'
          'SPR 10 以上ではトップペアは慎重に扱うべきハンドになります。'
          '同じハンドの価値が SPR で変わります。',
      commonMistake:
          'ハンドの強さだけを見て、スタックの深さを考えないミスです。'
          '「トップペアは強い」は、SPR がいくつかによって正しくも間違いにもなります。',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'po013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Kh',
      board: 'Qh 7h 2c',
      potBb: 6,
      villainProfile: VillainProfile.loosePassive,
      history: [
        'BB は Q を持ったトップペアだと読める（セットやツーペアではない）',
        'あなたはナッツフラッシュドロー + 2 オーバーカード',
      ],
      question: '6MAX・100BB。相手がトップペア（Qx）だと分かっている場合、あなたのアウツは何枚ですか。',
      choices: ['9枚', '12枚', '15枚', '18枚'],
      correctIndex: 2,
      shortReason:
          'ハートが 9 枚、A が 3 枚、K が 3 枚で合計 15 枚。'
          '相手が Qx なら、A か K でペアになるだけで逆転できます。',
      gtoView:
          'アウツは「相手が何を持っているか」で変わります。'
          '同じ AKs でも、相手がセットならオーバーカードはアウツにならず、'
          'ハート 9 枚だけになります。',
      practicalView:
          '相手のハンドが読み切れないときは、'
          '控えめに数えるほうが安全です。'
          '15 アウツは 2 枚見られれば 5 割を超える、非常に強いドローです。',
      commonMistake:
          '相手のハンドを考えずに、いつも同じ枚数で数えてしまうミスです。'
          'オーバーカードがアウツになるかどうかは、相手次第で変わります。',
    ),
    _q(
      id: 'po014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Jd Tc',
      board: '9h 8h 2c',
      potBb: 6,
      villainProfile: VillainProfile.reg,
      history: [
        'あなたはオープンエンドのストレートドロー',
        'ボードにはハートが 2 枚あり、相手はフラッシュドローを持っていると読める',
      ],
      question: '6MAX・100BB。オープンエンド（8 アウツ）ですが、相手がフラッシュドローの場合の実質アウツは何枚ですか。',
      choices: ['4枚', '6枚', '8枚', '10枚'],
      correctIndex: 1,
      shortReason:
          'ストレートを完成させる Q と 7 は 8 枚ですが、'
          'そのうち Qh と 7h は相手のフラッシュも同時に完成させます。'
          '勝てるのは残り 6 枚です。',
      gtoView:
          '「完成する枚数」と「完成して勝てる枚数」は別物です。'
          '相手のドローと重なるカードは、'
          '当たった瞬間に負けるため差し引いて数えます。',
      practicalView:
          '実戦ではここまで正確に読めないことも多いので、'
          '「ボードが濡れているときはアウツを少し割り引く」という'
          '感覚を持っておくだけでも判断が改善します。',
      commonMistake:
          'アウツをそのまま数えて、完成したのに負けるケースを'
          '計算に入れないミスです。'
          'これを繰り返すと、実際より強いドローだと勘違いし続けます。',
    ),
    _q(
      id: 'po015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.utg,
      heroCards: 'Th 9h',
      board: 'Ah 6h 3c',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ時点のポットは 10BB（3 人が参加）',
        'UTG が 5BB をベット',
        'HJ が 5BB をコール',
        'あなた（BTN）の番',
      ],
      question: '6MAX・100BB。ベットに 1 人コールが入った後のコールです。必要な勝率はおよそ何%ですか。',
      choices: ['約17%', '約20%', '約25%', '約33%'],
      correctIndex: 1,
      shortReason:
          '5 ÷（10 + 5 + 5 + 5 ＝ 25）＝ 20%。'
          '間に入ったコールの 5BB もポットに加わるので、'
          '2 人だけのときより安く参加できます。',
      gtoView:
          '自分より先にコールした人が増えるほど、'
          '同じベットサイズでも必要勝率は下がります。'
          'ドローで参加しやすくなる方向に働きます。',
      practicalView:
          'ただし人数が増えるほど「完成しても負けている」確率も上がります。'
          'ナッツに近いドローほど、多人数の恩恵を素直に受けられます。',
      commonMistake:
          '相手のベット額だけを見て、'
          '間のコールをポットに数え忘れるミスです。'
          '必要勝率を高く見積もり、良いオッズのコールを降りてしまいます。',
    ),
    _q(
      id: 'po016',
      difficulty: QuizDifficulty.intermediate,
      street: Street.turn,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Ah 5h 2c 8d',
      potBb: 20,
      stackBb: 60,
      villainProfile: VillainProfile.station,
      history: ['ターン時点のポットは 20BB', 'BTN が 10BB をベット', 'コール後の残りスタックは両者 60BB'],
      question:
          '6MAX。必要勝率 25% に対し完成率は約19%。'
          'コールが元を取るには、完成したときリバーで平均いくら追加で取れる必要がありますか。',
      choices: ['約5BB', '約11BB', '約25BB', '約40BB'],
      correctIndex: 1,
      shortReason:
          '完成する 19% のときポット 30BB に加えて X を取り、'
          '外す 81% のとき 10BB を失う。'
          '0.19 ×（30 + X）＝ 0.81 × 10 を解くと X は約11BB です。',
      gtoView:
          'これが「インプライドオッズ」の正体です。'
          '目に見えるポットオッズが足りなくても、'
          '将来取れる額を足せばコールが成立することがあります。',
      practicalView:
          '相手がコーリングステーションなら、'
          'フラッシュ完成後に 11BB 取るのは難しくありません。'
          '逆にフラッシュが見えた瞬間に降りる相手なら、この上乗せは期待できません。',
      commonMistake:
          'インプライドオッズを「なんとなく多めに見積もる言い訳」に'
          '使ってしまうミスです。'
          '「いくら必要か」を先に出してから、それが現実的か確かめます。',
    ),
    _q(
      id: 'po017',
      difficulty: QuizDifficulty.intermediate,
      street: Street.turn,
      hero: Position.bb,
      villain: Position.co,
      heroCards: 'Qc Qd',
      board: 'Kh 8s 4d 3c',
      potBb: 30,
      stackBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['ポット 30BB には、途中で降りたプレイヤーの 10BB も含まれている', 'CO が残り 20BB をオールイン'],
      question: '6MAX。ポット 30BB に対し 20BB のオールイン。必要な勝率はおよそ何%ですか。',
      choices: ['約25%', '約29%', '約33%', '約40%'],
      correctIndex: 1,
      shortReason:
          '20 ÷（30 + 20 + 20 ＝ 70）＝ 約29%。'
          '降りた人が置いていった 10BB も、そのままポットの一部として計算に入ります。',
      gtoView:
          '「誰が入れたチップか」は計算に関係ありません。'
          'ポットにあるチップはすべて、'
          '今から勝ったときに取れる額として等しく扱います。',
      practicalView:
          '降りた人のチップ（デッドマネー）が多いほどオッズは良くなります。'
          '多人数のポットで最後の 2 人になった場面は、'
          'それだけでコールしやすい状況です。',
      commonMistake:
          '「自分と相手が入れた分だけ」でポットを数えるミスです。'
          'デッドマネーを数え忘れると、必要勝率を高く見積もりすぎます。',
    ),
    _q(
      id: 'po018',
      difficulty: QuizDifficulty.intermediate,
      street: Street.turn,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Th',
      board: 'Kh 7h 2c 5d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['ターンでフラッシュドローのまま', 'BB が 10BB をベット（相手にはまだスタックが残っている）'],
      question: '6MAX・100BB。ターンでフラッシュドロー（9 アウツ）。完成率の見積もりとして正しいのはどれですか。',
      choices: ['アウツ×4 で約36%', 'アウツ×2 で約19%', 'アウツ×3 で約27%', 'ドローは常に50%と考える'],
      correctIndex: 1,
      shortReason:
          'ターンからリバーは残り 1 枚だけです。'
          '見えていないカード 46 枚のうち 9 枚なので約19%。'
          '×4 が使えるのはフロップで 2 枚見られるときだけです。',
      gtoView:
          'フロップでの ×4 は「ターンとリバーの 2 枚」を合わせた数字です。'
          'ターンに来た時点で、残っているカードはもう 1 枚しかありません。',
      practicalView:
          'この取り違えは、そのまま「ターンでコールしすぎる」癖につながります。'
          'ターンは必要勝率が上がる一方で完成率が半分になる、'
          '最も降りるべき場面が増えるストリートです。',
      commonMistake:
          'フロップで覚えた 35% という数字を、'
          'ターンでもそのまま使ってしまうミスです。'
          '実際の完成率のほぼ 2 倍で判断していることになります。',
    ),
    _q(
      id: 'po019',
      difficulty: QuizDifficulty.intermediate,
      street: Street.preflop,
      hero: Position.bb,
      villain: Position.co,
      heroCards: '6c 6d',
      potBb: 4.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 3BB', 'SB fold', 'あなた（BB）はあと 2BB でコールできる'],
      question:
          '6MAX・100BB。66 で 2BB のコール。セットになる確率は約12% です。'
          'セット狙いだけで元を取るには、当たったとき平均いくら勝つ必要がありますか。',
      choices: ['約4BB', '約15BB', '約30BB', '約60BB'],
      correctIndex: 1,
      shortReason:
          '0.12 × X ＝ 0.88 × 2BB を解くと X は約15BB。'
          '有効スタックが 100BB あるので、この 15BB は十分に狙える額です。',
      gtoView:
          'ポケットペアのコールは「当たる確率が低い代わりに、'
          '当たったときの取り分が大きい」という構造です。'
          '必要額を先に出せば、成立するかどうかが機械的に判断できます。',
      practicalView:
          '同じ 66 でも有効スタックが 20BB しかなければ、'
          'セットになっても 15BB 取り切れないことが増え、成立しにくくなります。'
          'スタックが深いほどこのコールは有利になります。',
      commonMistake:
          '「ポケットペアはいつでもセット狙いでコール」と'
          '覚えてしまうミスです。'
          '必要な取り分をスタックが下回っていれば、成立していません。',
    ),
    _q(
      id: 'po020',
      difficulty: QuizDifficulty.intermediate,
      street: Street.river,
      hero: Position.co,
      villain: Position.btn,
      heroCards: 'As Jd',
      board: 'Ac 9h 6s 4d 2h',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 10BB', 'BTN がポットの 2 倍にあたる 20BB をオーバーベット'],
      question: '6MAX・100BB。ポット 10BB に 20BB のオーバーベット。レンジの何%を続ければ降りすぎになりませんか。',
      choices: ['約17%', '約33%', '約50%', '約67%'],
      correctIndex: 1,
      shortReason:
          'ポット ÷（ポット + ベット）＝ 10 ÷ 30 ＝ 約33%。'
          '大きく打たれるほど、降りてよい割合は増えます。',
      gtoView:
          '大きいベットは「相手により多く降りさせられる」代わりに、'
          '外したときの損が大きくなります。'
          'オーバーベットが成立するのは、'
          '相手のレンジに強い手が少ないと分かっているときです。',
      practicalView:
          '33% しか残さなくていいということは、'
          'オーバーベットに対しては本当に強い手だけで受ければ十分ということです。'
          'A ハイ程度で無理に受ける必要はありません。',
      commonMistake:
          '「オーバーベットされたから何か守らないと」と'
          '弱い手で受けてしまうミスです。'
          'サイズが大きいほど、降りてよい割合は増えます。',
    ),
    _q(
      id: 'po021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh Th',
      board: '9c 7d 2s',
      potBb: 6,
      villainProfile: VillainProfile.reg,
      history: ['BTN が 3BB（ポットの 1/2）をベット', 'あなたはガットショット（4 アウツ）のみ'],
      question: '6MAX・100BB。ポット 6BB に 3BB のベット。ガットショット（4 アウツ）だけでどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 3 ÷（6 + 3 + 3 ＝ 12）＝ 25%。'
          'ガットショットは 2 枚見られても約17%、'
          'ターン 1 枚なら約9% しかなく、大きく足りません。',
      gtoView:
          '4 アウツはドローとしては最弱の部類です。'
          'これ単体でコールを正当化できる値段は、'
          '相当に小さいベットに限られます。',
      practicalView:
          '同じ 4 アウツでも、オーバーカードやバックドアのフラッシュが'
          '加われば話が変わります。'
          'また相手がスタックを深く持っていて、'
          '完成時に大きく払う相手なら検討の余地が出ます。',
      commonMistake:
          '「ドローがあるからコール」と、'
          'ドローの強さを確かめずに払ってしまうミスです。'
          'ガットショットとオープンエンドでは価値が 2 倍違います。',
    ),
    _q(
      id: 'po022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah 4h',
      board: 'Kh 9h 3c',
      potBb: 6,
      stackBb: 97,
      villainProfile: VillainProfile.looseAggressive,
      history: ['BTN が 3BB をベット', 'BTN の残りスタックは 97BB あり、ターンでもほぼ確実に打ってくる相手'],
      question: '6MAX。フラッシュドローで相手はターンでも打ってくる見込みです。どの完成率で判断すべきですか。',
      choices: [
        '2枚ぶんの約35%。フロップなので 2 枚見られる',
        '1枚ぶんの約19%。ターンでまた払わされるため',
        '常に50%。ドローは五分と考える',
        'ポットオッズだけで判断し、完成率は考えない',
      ],
      correctIndex: 1,
      shortReason:
          '35% は「タダで 2 枚見られる」ときの数字です。'
          'ターンでまた打たれるなら、'
          'いま払う 3BB で買えるのはターンの 1 枚だけ。約19% で判断します。',
      gtoView:
          '2 枚見られる前提が成り立つのは、'
          '相手がオールインしている場合か、'
          'こちらがレイズして相手がチェックに回った場合などに限られます。',
      practicalView:
          '攻撃的な相手ほど、この差が効いてきます。'
          '「フロップは安いけどターンで大きく打たれる」形が最も苦しいので、'
          'フロップでレイズして主導権を取り返す選択肢も生まれます。',
      commonMistake:
          '毎回 35% で計算して、ドローを過大評価してしまうミスです。'
          '実際にはターンでも払わされるため、想定よりずっと高くつきます。',
    ),
    _q(
      id: 'po023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '9h 8h',
      board: '7h 6c 2h',
      potBb: 6,
      villainProfile: VillainProfile.reg,
      history: ['BB check', 'あなたはフラッシュドローとストレートドローの両方を持っている'],
      question: '6MAX・100BB。98 で 762（ハート 2 枚）のフロップ。アウツは合計何枚ですか。',
      choices: ['12枚', '15枚', '17枚', '20枚'],
      correctIndex: 1,
      shortReason:
          'ハートが 9 枚、ストレートの T と 5 が 8 枚。'
          'ただし Th と 5h はハートとして既に数えているので、'
          '重複 2 枚を引いて 9 + 6 ＝ 15 枚です。',
      gtoView:
          '15 アウツは 2 枚見られればおよそ 54%、'
          'つまり完成しているハンドを相手にしても五分以上あります。'
          'コンボドローが強いと言われるのはこのためです。',
      practicalView:
          'これだけエクイティがあると、'
          'セミブラフでレイズしてスタックを入れにいく選択肢が現実的になります。'
          '降ろせても良し、コールされても五分という状態です。',
      commonMistake:
          '9 + 8 ＝ 17 枚と、重複を引かずに足してしまうミスです。'
          'Th と 5h は 1 枚のカードで両方を完成させるだけなので、二重に数えられません。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'po024',
      difficulty: QuizDifficulty.advanced,
      street: Street.river,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Kc Kd',
      board: 'Ah 9s 7d 4c 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 20BB', 'BTN がポットの 2 倍にあたる 40BB をオーバーベット'],
      question: '6MAX・100BB。ポット 20BB に 40BB のオーバーベット。必要な勝率はおよそ何%ですか。',
      choices: ['約29%', '約33%', '約40%', '約50%'],
      correctIndex: 2,
      shortReason:
          '40 ÷（20 + 40 + 40 ＝ 100）＝ 40%。'
          'オーバーベットに対しては、'
          '5 回に 2 回勝てるハンドでないとコールが成立しません。',
      gtoView:
          'オーバーベットを打つ側は、'
          '「相手のレンジに 40% 勝てるハンドがほとんど残っていない」と'
          '判断したときにこのサイズを選びます。'
          'A ハイのボードで KK を持っているのは、まさにその想定の内側です。',
      practicalView:
          'この相手がオーバーベットをブラフに使わないタイプなら、'
          'KK でも降りて構いません。'
          'オーバーベットのブラフ頻度は相手によって極端に差が出ます。',
      commonMistake:
          '「KK は強いから」とハンドの絶対的な強さで払ってしまうミスです。'
          'A が落ちたボードでは KK はただのブラフキャッチャーで、'
          '40% を満たしているかが唯一の基準になります。',
    ),
    _q(
      id: 'po025',
      difficulty: QuizDifficulty.advanced,
      street: Street.river,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '8c 7c',
      board: 'Ad Kh 9s 5d 2c',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 20BB', 'BB check', 'あなたは何も完成しておらずブラフを検討している'],
      question: '6MAX・100BB。ポット 20BB でブラフします。最も高い成功率が必要になるサイズはどれですか。',
      choices: ['5BB', '10BB', '20BB', '40BB'],
      correctIndex: 3,
      shortReason:
          '必要成功率はベット ÷（ポット + ベット）。'
          '5BB なら 20%、10BB なら 33%、20BB なら 50%、40BB なら約67%。'
          '大きく打つほど、より頻繁に降ろす必要があります。',
      gtoView:
          'サイズを上げると「相手が降りる確率」は上がりますが、'
          '「必要な降り率」はそれ以上に速く上がります。'
          'だから大きいブラフは、相手が本当に降りる場面に限定して使います。',
      practicalView:
          '相手が降りやすいと分かっているときだけサイズを上げます。'
          '「大きく打てば降りるはず」という期待だけで打つと、'
          '必要成功率に届かず赤字になります。',
      commonMistake:
          '「勝ち目がないから思い切り大きく」と'
          '手の弱さに合わせてサイズを上げてしまうミスです。'
          'サイズは自分の手の弱さではなく、相手が降りる確率で決めます。',
    ),
    _q(
      id: 'po026',
      difficulty: QuizDifficulty.advanced,
      street: Street.river,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qs Jd',
      board: 'Qh 8c 5s 3d 2h',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: [
        'リバー時点のポットは 10BB',
        'BTN がポットサイズの 10BB をベット',
        'この時点であなたのレンジには 40 通りのハンドが残っている',
      ],
      question: '6MAX・100BB。ポットサイズのベットに対し、40 通りのうち何通りを続ければ降りすぎになりませんか。',
      choices: ['10通り', '13通り', '20通り', '27通り'],
      correctIndex: 2,
      shortReason:
          'ポットサイズのベットに対して守るべき割合は'
          '10 ÷（10 + 10）＝ 50%。40 通りの半分で 20 通りです。',
      gtoView:
          '守る「割合」を具体的な「通り数」に落とすと、'
          'どこまでのハンドで受けるかが決まります。'
          '強い順に 20 通り並べ、そこが受ける下限になります。',
      practicalView:
          'この計算は相手が正しくブラフしてくる前提のものです。'
          'ブラフをほとんどしない相手には、'
          '20 通りも守る必要はありません。',
      commonMistake:
          '割合だけ覚えて、実際のハンドに落とし込まないミスです。'
          '「50% 守る」と言っても、'
          '自分のレンジに何が残っているか把握していなければ実行できません。',
    ),
    _q(
      id: 'po027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '5h 4h',
      board: 'Ah Kh 7c',
      potBb: 6,
      villainProfile: VillainProfile.looseAggressive,
      history: ['BTN が 3BB をベット', 'あなたは下位のフラッシュドロー（54s）'],
      question: '6MAX・100BB。54s のフラッシュドローです。完成率だけでコールを決めてはいけない理由はどれですか。',
      choices: [
        'フラッシュが完成する確率が他のフラッシュドローより低いから',
        '完成しても、より上のフラッシュに負けて大きく払う場面があるから',
        'ポットオッズの計算式がフラッシュドローだけ違うから',
        'ポジションがないとドローは完成しないから',
      ],
      correctIndex: 1,
      shortReason:
          '完成率は 9 アウツで他のフラッシュドローと同じです。'
          '違うのは「完成した後」で、'
          '相手が上のハートを持っていると、'
          '一番大きなポットを作った上で負けます。',
      gtoView:
          'これは「リバースインプライドオッズ」と呼ばれます。'
          'インプライドオッズが「当たったとき追加で取れる額」なら、'
          'こちらは「当たったのに追加で払わされる額」です。',
      practicalView:
          'ボードに A と K のハートがある時点で、'
          '相手のレンジには Ah や Kh を含むハンドが多く残っています。'
          '同じ 9 アウツでも、Ah を自分が持っているかどうかで価値がまったく変わります。',
      commonMistake:
          'アウツの枚数だけでドローの強さを判断するミスです。'
          '「完成したときにナッツかどうか」まで含めて、はじめて価値が決まります。',
    ),
    _q(
      id: 'po028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Kh 6h 2c',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ時点のポットは 10BB',
        'BTN が 5BB をベット',
        'あなたはフラッシュドローでレイズ 18BB を検討している',
      ],
      question:
          '6MAX・100BB。ポット 10BB、相手のベット 5BB に対して 18BB へレイズします。'
          '仮にまったくエクイティが無いブラフだとしたら、何%降ろす必要がありますか。',
      choices: ['約35%', '約45%', '約55%', '約70%'],
      correctIndex: 2,
      shortReason:
          '18BB を賭けて、いま取れるのはポット 10 + 相手のベット 5 ＝ 15BB。'
          '18 ÷（18 + 15 ＝ 33）＝ 約55% です。',
      gtoView:
          'レイズはベットより多くのチップを賭けるぶん、'
          '必要な成功率も高くなります。'
          'だからこそ、レイズのブラフには'
          'コールされても戦えるエクイティを持つハンドを選びます。',
      practicalView:
          '実際にはフラッシュドローとして約35% のエクイティがあるので、'
          '55% 降ろせなくても成立します。'
          'この「降ろせなかったときの保険」がセミブラフの価値です。',
      commonMistake:
          'レイズをベットと同じ感覚で打ってしまうミスです。'
          '同じポットでも、レイズは必要成功率がはっきり高くなります。',
    ),
    _q(
      id: 'po029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.co,
      heroCards: 'Td 9c',
      board: '8h 7s 2d',
      potBb: 20,
      stackBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ時点のポットは 20BB', 'CO が残り 20BB をオールイン', '2 枚とも見られる'],
      question: '6MAX。ポット 20BB に 20BB のオールイン。オープンエンド（8 アウツ）でどう判断しますか。',
      choices: [
        '必要勝率 約33%、完成率 約32%。わずかに足りないので Fold',
        '必要勝率 約25%、完成率 約32%。足りているので Call',
        '必要勝率 約33%、完成率 約17%。大きく足りないので Fold',
        '必要勝率 約50%、完成率 約32%。足りないので Fold',
      ],
      correctIndex: 0,
      shortReason:
          '必要勝率は 20 ÷（20 + 20 + 20 ＝ 60）＝ 約33%。'
          '8 アウツで 2 枚見られる完成率は約32%（アウツ×4 の目安）。'
          'ほぼ互角で、わずかに足りません。',
      gtoView:
          'ポットサイズのオールインに 8 アウツのドロー単体で受けるのは、'
          'ちょうど損益分岐点のあたりです。'
          'ここから答えを動かすのは、'
          'オーバーカードやバックドアなど、追加のエクイティがあるかどうかです。',
      practicalView:
          'T9 が K や A に対してオーバーカードを持っていないので、'
          '追加のエクイティはほぼありません。'
          'ボードに自分のスートが 2 枚あればバックドアが足せて、答えが変わります。',
      commonMistake:
          '必要勝率か完成率のどちらかだけを出して満足してしまうミスです。'
          '両方を出して比べないと判断できません。',
    ),
    _q(
      id: 'po030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.hj,
      villain: Position.utg,
      heroCards: 'Qh Jh',
      board: 'Ah 8h 3c',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ時点のポットは 12BB（4 人が参加）',
        'UTG が 6BB をベット',
        'あなた（HJ）の番。後ろには CO と BTN の 2 人が残っている',
      ],
      question: '6MAX・100BB。後ろに 2 人残っている状態でのフラッシュドローのコール。計算上の注意点はどれですか。',
      choices: [
        '後ろの 2 人がコールするとオッズが悪くなるので、必要勝率を高く見積もる',
        '後ろの 2 人にレイズされる可能性があり、支払う額が 6BB で確定していない',
        '人数が多いほどアウツが減るので、アウツを半分にして数える',
        '後ろに人が残っていても、計算は 1 対 1 のときとまったく同じ',
      ],
      correctIndex: 1,
      shortReason:
          '「6BB 払えば次のカードが見られる」という前提が、まだ確定していません。'
          '後ろの誰かがレイズすれば、'
          'コールした 6BB を捨てるか、さらに払うかの選択を迫られます。',
      gtoView:
          '後ろに未行動のプレイヤーが残っている状況は、'
          '同じポットオッズでも実質的に不利です。'
          '「値段が確定しているか」はポジションの価値そのものです。',
      practicalView:
          '後ろが残っているときは、'
          'コールよりレイズで値段を自分から確定させるか、'
          '素直に降りるほうが扱いやすくなります。'
          '同じハンドでも、BTN なら迷わずコールできます。',
      commonMistake:
          '目の前のベット額だけでオッズを計算し、'
          '後ろのアクションを勘定に入れないミスです。'
          'ポットオッズは「これ以上払わされない」場合にだけそのまま使えます。',
    ),
  ];
}
