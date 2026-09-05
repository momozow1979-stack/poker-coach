import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// リバーの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class RiverQuizzes {
  static List<Quiz> get all => _quizzes;

  static Quiz _q({
    required String id,
    required QuizDifficulty difficulty,
    Street street = Street.river,
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
      category: QuizCategory.river,
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
      id: 'rv001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kd Qc',
      board: 'Kc 9s 4h 7d 2c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンともに両者チェック', 'リバー: BB check'],
      question: '6MAX・100BB。両者チェックで進み、リバーで KQ のトップペア。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'All-in'],
      correctIndex: 1,
      shortReason:
          '両者がチェックで進んだので、相手のレンジは弱めです。'
          '小さいサイズなら、9x やポケットペアなど'
          '自分より弱い手からコールをもらえます。',
      gtoView:
          '相手のレンジが弱いときは、'
          '「薄いバリュー」を小さいサイズで取りにいくのが基本です。'
          '大きく打つと弱い手が全部降りて、価値が取れません。',
      practicalView:
          '相手が何でもコールするタイプならサイズを上げてかまいません。'
          '逆にリバーで降りやすい相手なら、そもそも打つ価値が下がります。',
      commonMistake:
          'チェックで回して価値を取り逃がすミスです。'
          '「負けているかもしれない」という不安で、'
          '勝っている回の利益を丸ごと捨てています。',
    ),
    _q(
      id: 'rv002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '9c 9d',
      board: 'Ah Kd 6s 3c 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet → BB call',
        'ターン: BB check → BTN bet → BB call',
        'リバー: BB check → BTN がポットサイズの 20BB をベット',
      ],
      question: '6MAX・100BB。3 ストリート打たれました。99 でどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          '3 回打ち続けるレンジには A や K が多く、'
          '99 が勝てる相手はごく限られます。'
          'ポットサイズのベットには 33% の勝率が必要で、それを満たしません。',
      gtoView:
          'ブラフキャッチャーとして残すべきなのは、'
          '相手のバリューハンドをブロックしているハンドです。'
          '99 は A も K もブロックしていません。',
      practicalView:
          '相手がリバーでほとんどブラフしない相手なら、なおさら降ります。'
          '極端に攻撃的な相手が明らかなブラフレンジを持つ場合だけ、'
          'コールを検討します。',
      commonMistake:
          '「ここまで払ったから」と最後まで払ってしまうミスです。'
          'すでに入れたチップは、これからの判断材料になりません。',
    ),
    _q(
      id: 'rv003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qh Jh',
      board: 'Kh 8h 4c 2s 3d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet → BB call',
        'ターン: BB check → BTN bet → BB call',
        'リバー: フラッシュもストレートも外れた。BB check',
      ],
      question: '6MAX・100BB。QJ のフラッシュドローが外れました。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet（ブラフ）', 'Fold', '諦めて Check'],
      correctIndex: 1,
      shortReason:
          'QJ ハイでは、チェックしてもほぼ確実に負けています。'
          '勝つ道はブラフだけです。'
          'しかも 2 回コールした相手のレンジは、'
          'K の弱いペアなど降ろせる手を多く含みます。',
      gtoView:
          '「チェックしても勝てないハンド」は、'
          'ブラフの最有力候補になります。'
          '逆に少しでもショーダウンで勝てる手は、'
          'ブラフに回すと二重に損をします。',
      practicalView:
          'この相手が降りない場合は成立しません。'
          'ただし降りない相手であれば、'
          'そもそもフロップ・ターンで打ち続けた方針から見直す必要があります。',
      commonMistake:
          '「外れたから諦める」とチェックしてしまうミスです。'
          'チェックした時点で、そのポットは確実に相手のものになります。',
    ),
    _q(
      id: 'rv004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ts 9s',
      board: 'Js Qs 4h 7s 2d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX・100BB。T9s でスペードのフラッシュが完成しています。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%以上', 'Fold'],
      correctIndex: 2,
      shortReason:
          'フラッシュはほぼ最強です。'
          '相手のレンジには Qx・Jx のトップペアやツーペアが残っており、'
          '大きめに打っても十分コールしてもらえます。',
      gtoView:
          'バリューベットのサイズは'
          '「相手がコールできる一番大きい額」で決めます。'
          '相手に強い手が多く残っているほど、大きく打てます。',
      practicalView:
          '相手がスペードを 1 枚持っていると降りやすくなります。'
          'それでも Qx を持っている相手からは十分に取れます。',
      commonMistake:
          '「大きく打つと降りられる」と小さくしてしまうミスです。'
          '一番強い手を持ったときに小さく打つ癖は、'
          '長期的に大きな取りこぼしになります。',
    ),
    _q(
      id: 'rv005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ac 8d',
      board: 'Ad 9h 5s 3c 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet → BB call',
        'ターン・リバー: 両者チェック → リバーで BTN が 4BB をベット',
      ],
      question: '6MAX・100BB。ポット 20BB に 4BB の小さいベット。A8 のトップペアでどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          '必要勝率は 4 ÷（20 + 4 + 4 ＝ 28）＝ 約14%。'
          'トップペアがこの水準を下回ることはまずありません。'
          '7 回に 1 回勝てば十分です。',
      gtoView:
          '小さいベットは、'
          'それだけ広いレンジで受けなければ相手のブラフが得になります。'
          'トップペアはその中で確実に受ける側です。',
      practicalView:
          'レイズはしません。'
          'ターンでチェックした相手のレンジは弱く、'
          'レイズしても降りられるだけです。',
      commonMistake:
          '「キッカーが 8 だから弱い」と降りてしまうミスです。'
          '必要勝率 14% の場面で、'
          'キッカーの強弱を気にする必要はありません。',
    ),
    _q(
      id: 'rv006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '8c 8d',
      board: 'Ah Kd 9s 6c 3h',
      potBb: 8,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンともに両者チェック', 'リバー: BB check'],
      question: '6MAX・100BB。88 で AK9 のボード。全員チェックで進みました。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'All-in'],
      correctIndex: 0,
      shortReason:
          '88 は A も K も 9 も無いので、'
          '打っても降りるのは 88 より弱い手（何も無いハンド）だけです。'
          '一方でコールしてくるのは、すべて 88 に勝っている手です。',
      gtoView:
          'バリューベットが成立するのは'
          '「自分より弱い手がコールしてくれる」ときだけです。'
          '88 にはその相手がいません。',
      practicalView:
          'チェックすれば、'
          '相手も何も無いときに 88 のまま勝てます。'
          'これがショーダウンバリューです。',
      commonMistake:
          '「ペアがあるから打てる」と考えるミスです。'
          'ペアの有無ではなく、'
          '「どの手がコールしてくれるか」で打つかどうかを決めます。',
    ),
    _q(
      id: 'rv007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Ah 5h 2c 8d 3h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: ハートが 4 枚目でフラッシュが完成'],
      question: '6MAX・100BB。リバーでフラッシュが完成しました。BB のあなたはどうしますか。',
      choices: ['Check（相手に打たせる）', 'Bet（リード）', 'Fold', '様子を見る'],
      correctIndex: 1,
      shortReason:
          'ハートが 4 枚見えているので、'
          '相手は「フラッシュがあるかも」と警戒してチェックで回してきます。'
          'こちらから打たないと、価値がまったく取れません。',
      gtoView:
          '相手が打ちにくいボードでは、'
          'チェックは「何も起きないまま終わる」だけです。'
          '自分から仕掛けないと利益になりません。',
      practicalView:
          '4 枚見えているぶん、'
          '相手も 1 枚持っている可能性はあります。'
          '小さめのサイズなら、そうした相手から払ってもらえます。',
      commonMistake:
          '「完成したから相手に打たせよう」と考えるミスです。'
          'ボードにフラッシュが見えている状況で、'
          '相手が自分から打ってくれることはめったにありません。',
    ),
    _q(
      id: 'rv008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac 9c',
      board: '9h 6d 3s 2c 9s',
      potBb: 16,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → CO bet → BB call',
        'ターン: 両者チェック',
        'リバー: 9 でスリーカードに。BB check',
      ],
      question: '6MAX・100BB。リバーの 9 で 999 のスリーカードになりました。どうしますか。',
      choices: ['Check', 'Bet', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          'A キッカーのスリーカードで、ほぼ最強です。'
          '相手のレンジには 6x・3x・ポケットペアが残っており、'
          '打てば払ってくれます。',
      gtoView:
          'ボードがペアになったリバーは、'
          '相手が自分から打ちにくい状況です。'
          'チェックすると何も起きないまま終わる可能性が高くなります。',
      practicalView:
          '相手が 9 を持っている可能性は残り 2 枚ぶんしかありません。'
          'キッカーが A なので、'
          'その少ない相手にもほとんど勝っています。',
      commonMistake:
          '強い手を隠そうとしてチェックしてしまうミスです。'
          '隠したところで、相手が打ってくれなければ意味がありません。',
    ),
    _q(
      id: 'rv009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.co,
      heroCards: 'Kh Jd',
      board: 'Kd 8c 5h 4d Qs',
      potBb: 24,
      stackBb: 60,
      villainProfile: VillainProfile.nit,
      history: ['フロップ・ターンでコールし続けた', 'リバー: Q が落ちた', 'CO（タイトな相手）が残り 60BB をオールイン'],
      question: '6MAX。タイトな相手にポット 24BB へ 60BB のオールイン。KJ のトップペアでどうしますか。',
      choices: ['Fold', 'Call', 'Raise', '悩むが Call'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 60 ÷（24 + 60 + 60 ＝ 144）＝ 約42%。'
          'タイトな相手のオーバーベット・オールインは'
          'ツーペア以上に強く偏り、トップペアではまず届きません。',
      gtoView:
          '大きいベットほど高い勝率を要求します。'
          '42% はブラフキャッチャーで満たせる水準ではなく、'
          '相手が頻繁にブラフする前提が必要です。',
      practicalView:
          '相手がマニアックなタイプなら、'
          '同じ状況でもコールを検討します。'
          'タイト・パッシブな相手のオールインは、'
          'ほぼ例外なくバリューです。',
      commonMistake:
          '「トップペアで降りるのはもったいない」という'
          '気持ちで払ってしまうミスです。'
          '必要勝率を計算すれば、機械的に答えが出ます。',
    ),
    _q(
      id: 'rv010',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '9s 8s',
      board: 'Kc 9h 4d 2s 7c',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet → BB call',
        'ターン: 両者チェック',
        'リバー: BB が 16BB をベット',
      ],
      question: '6MAX・100BB。ポット 20BB に 16BB のベット。98s のミドルペアでどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 16 ÷（20 + 16 + 16 ＝ 52）＝ 約31%。'
          'ターンでチェックした相手が'
          'リバーで大きく打つのは、Kx 以上に偏ります。'
          'ミドルペアでは足りません。',
      gtoView:
          'ターンをチェックしてリバーで大きく打つ形は、'
          '「弱い手を捨てて、強い手とブラフだけを残した」レンジです。'
          'ミドルペアはその強い側に勝てません。',
      practicalView:
          'ブラフを多用する相手なら受ける余地はあります。'
          'ただしその場合も、'
          '9 より上のペアをすべて相手にする必要があります。',
      commonMistake:
          '「ペアがあるから」と払ってしまうミスです。'
          'ペアの有無ではなく、'
          '相手のレンジのどこに位置しているかで決めます。',
    ),
    _q(
      id: 'rv011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Th 9h',
      board: 'Jc 8d 7s 2c 3h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 14BB をベット'],
      question: '6MAX・100BB。T9 でストレートが完成しており、相手が打ってきました。どうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'ストレートなので Call'],
      correctIndex: 2,
      shortReason:
          'JT9 のストレートはこのボードでほぼ最強です。'
          '相手が自分から打ってきたということは、'
          'ある程度の強さを持っているので、レイズでさらに取りにいけます。',
      gtoView:
          '最強クラスのハンドを持ったときは、'
          '相手のベットに対してコールで終わらせるのが'
          '最も価値を取り逃がす選択になります。',
      practicalView:
          'レイズサイズは、相手が Jx や 8x でコールできる範囲にします。'
          '相手が降りやすいタイプなら小さめのレイズにします。',
      commonMistake:
          '「相手が打ってくれたからコールで十分」と'
          '満足してしまうミスです。'
          '一番強い手を持ったときは、最大まで取りにいきます。',
    ),
    _q(
      id: 'rv012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '7h 7d',
      board: 'Ah Kc 9d 5s 2h',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: CO bet → BB call', 'ターン: 両者チェック', 'リバー: BB check'],
      question: '6MAX・100BB。AK9 のボードで 77。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          '77 は「打っても弱い手しか降りず、'
          'コールされたら必ず負けている」中途半端な位置にいます。'
          'ただしチェックすれば、相手が何も無いときに勝てます。',
      gtoView:
          'ハンドは「バリューベット」「ブラフ」'
          '「チェックしてショーダウンへ」の 3 つに分類できます。'
          '77 は 3 つ目です。'
          '弱い手を降ろす必要も、強い手から取る力もありません。',
      practicalView:
          '同じ 77 でも、'
          'ボードが 7 より低い数字ばかりなら'
          'バリューベットに変わります。'
          'ボードとの相対的な位置で役割が決まります。',
      commonMistake:
          'ショーダウンバリューのあるハンドでブラフしてしまうミスです。'
          '勝てる可能性を自分から捨てることになります。',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'rv013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Kc',
      board: 'Kh 9d 4s 4h 2c',
      potBb: 18,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX・100BB。ボードが 4 でペアの K94 42。AK のトップペア・トップキッカーです。狙いはどれですか。',
      choices: ['バリューベット', 'ブラフ', 'ポットコントロールのチェック', 'ブラフキャッチのチェック'],
      correctIndex: 0,
      shortReason:
          '相手のレンジには K9・9x・ポケットペアなど、'
          'コールしてくれる弱い手が十分に残っています。'
          'ボードの 4 は両者が持っている扱いなので、'
          '実質「K のトップペア・最強キッカー」として戦えます。',
      gtoView:
          '3 ストリート打ち続けるバリューレンジの中でも、'
          'AK はトップキッカーを持つ上位ハンドです。'
          '相手が K を持っていても、キッカーで勝っています。',
      practicalView:
          '相手が降りやすいタイプならサイズを下げ、'
          '何でもコールするタイプならサイズを上げます。'
          'サイズは相手の性質で決めます。',
      commonMistake:
          '「4 がペアになって危ない」と止まってしまうミスです。'
          '相手が 4 を持っている組み合わせは、残り 2 枚ぶんしかありません。',
    ),
    _q(
      id: 'rv014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah 5c',
      board: 'Kh 9h 4c 2h 8d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: ハートは 3 枚のまま。BB check'],
      question: '6MAX・100BB。A5o で何もありません。Ah を持っていることがブラフに向く理由はどれですか。',
      choices: [
        'A が最強のカードだから',
        '相手がナッツフラッシュを持っている可能性を消しているから',
        'A ハイでショーダウンに勝てるから',
        '5 がストレートに絡むから',
      ],
      correctIndex: 1,
      shortReason:
          'ボードにハートが 3 枚あり、'
          '相手のコールレンジには完成したフラッシュが含まれます。'
          'Ah を自分が持っていることで、'
          '相手が最強のフラッシュを持つ組み合わせを消しています。',
      gtoView:
          'ブラフに選ぶべきなのは、'
          '「相手が絶対に降りないハンド」をブロックしているハンドです。'
          '相手の続行レンジを直接減らせるぶん、'
          'ブラフの成功率が上がります。',
      practicalView:
          '同じ A5o でも、Ac5c ならこの効果はありません。'
          'スートの 1 枚が判断を変えるのが、ブロッカーの考え方です。',
      commonMistake:
          'ブロッカーを「自分の手が強くなること」と'
          '混同するミスです。'
          'Ah の価値は、A ハイの強さではなく'
          '相手のフラッシュを減らすことにあります。',
    ),
    _q(
      id: 'rv015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah 9c',
      board: 'Kh Qh 7d 3c 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: ハートが 3 枚。BB check → BTN が 15BB をベット'],
      question: '6MAX・100BB。A9 で何もありません。Ah を持った状態でこのベットにどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'A ハイなので Fold'],
      correctIndex: 1,
      shortReason:
          'Ah を持っているので、'
          '相手がナッツフラッシュを持つ組み合わせが消えています。'
          'その分だけ相手のレンジはブラフに偏り、'
          '必要勝率 15 ÷ 50 ＝ 30% を満たす見込みが出てきます。',
      gtoView:
          'ブラフキャッチに選ぶべきなのは、'
          '相手のバリューハンドをブロックしているハンドです。'
          'Ah はこのボードで最も価値のあるブロッカーになります。',
      practicalView:
          '同じ A9 でも Ac9c ならブロッカーが無く、'
          '降りるほうが自然になります。'
          '「同じ強さのハンドでも、どのスートを持っているかで判断が変わる」'
          '典型例です。',
      commonMistake:
          '「A ハイでは勝てない」と'
          '手の絶対的な強さだけで降りてしまうミスです。'
          'ブラフキャッチは、相手のレンジ構成で決めます。',
    ),
    _q(
      id: 'rv016',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '6h 5h',
      board: '9h 8h 2c Kd 7s',
      potBb: 20,
      stackBb: 60,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: 7 でストレートが完成。BB check'],
      question: '6MAX。リバーの 7 で 65 のストレートが完成。相手のレンジは Kx とペアが中心です。どのサイズが最適ですか。',
      choices: ['Check', 'Bet 25%', 'Bet 75%', 'Bet 150%（オーバーベット）'],
      correctIndex: 2,
      shortReason:
          '相手のレンジには Kx やツーペアが多く残っており、'
          '大きめのサイズでも払ってもらえます。'
          '一方でストレートが見えているボードなので、'
          'オーバーベットは降ろしすぎになります。',
      gtoView:
          'バリューベットのサイズは'
          '「相手がコールできる最大額」で決まります。'
          '相手のレンジがトップペア中心なら 3/4 前後、'
          'もっと強い手が多いならさらに上げられます。',
      practicalView:
          '相手が「ストレートが見えたら降りる」タイプなら、'
          'サイズを 50% 程度まで落として確実に取りにいきます。'
          'サイズは相手のコール範囲に合わせます。',
      commonMistake:
          '「最強だから最大サイズ」と機械的にオーバーベットするミスです。'
          '相手が付いてこられないサイズは、'
          '強い手を持った意味を消してしまいます。',
    ),
    _q(
      id: 'rv017',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kd Kc',
      board: 'Ks 8h 3d 5c 4s',
      potBb: 30,
      stackBb: 50,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ・ターンでベットしコールされた',
        'リバー: CO bet 20BB → BB が残り 50BB をオールインでレイズ',
      ],
      question: '6MAX。セット（KKK）でリバーに打ったら、オールインでレイズされました。どうしますか。',
      choices: ['Fold', 'Call', '悩むが Fold', 'セットなので即 Call'],
      correctIndex: 1,
      shortReason:
          '必要勝率は 30 ÷（30 + 20 + 50 + 30 ＝ 130）で約23%。'
          '負けるのは 67 のストレートだけで、'
          'その組み合わせは限られます。'
          '相手のブラフも含めれば 23% は十分に超えます。',
      gtoView:
          'セットは「ごく限られた相手にしか負けない」ハンドです。'
          'リバーのレイズに対しては、'
          '「自分に勝つ組み合わせが何通りあるか」を数えて判断します。',
      practicalView:
          '相手がタイト・パッシブで'
          'ブラフをまったくしないタイプなら降りる場面です。'
          'レギュラー相手であれば、ブラフの割合を考えて受けます。',
      commonMistake:
          '「オールインされた＝負けている」と反射的に降りるミスです。'
          '必要勝率と、負ける組み合わせの数を数えれば答えが出ます。',
    ),
    _q(
      id: 'rv018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh Th',
      board: '9c 8d 2s Kh 3c',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: ストレートが外れた。BB check → BTN が 7BB をベット'],
      question: '6MAX・100BB。ストレートが外れました。小さいベットに対してチェックレイズのブラフは有効ですか。',
      choices: [
        '有効。JT はショーダウンで勝てず、小さいベットは弱いレンジを示すから',
        '無効。ブラフは必ずベットで行うべきだから',
        '無効。JT にはショーダウンバリューがあるから',
        '有効。J と T がボードに絡んでいるから',
      ],
      correctIndex: 0,
      shortReason:
          'JT ハイはショーダウンでほぼ勝てません。'
          'さらに相手の小さいベットは'
          '「安く終わらせたい弱い手」を含むレンジなので、'
          'レイズで降ろせる余地があります。',
      gtoView:
          'チェックレイズのブラフに向くのは、'
          '「チェックしても勝てず、'
          '相手のレンジが強くない」と読める場面です。'
          '小さいベットは、その条件を満たしやすい合図になります。',
      practicalView:
          '相手が小さいベットに'
          'ブラフキャッチで受け続けるタイプなら成立しません。'
          'また、レイズサイズは大きめにしないと'
          '相手にオッズを与えてしまいます。',
      commonMistake:
          '外したドローをすべてチェック・フォールドしてしまうミスです。'
          '一番弱いハンドこそ、ブラフに使う価値があります。',
    ),
    _q(
      id: 'rv019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ad Jc',
      board: 'Jh 9c 4d 6s 2h',
      potBb: 20,
      villainProfile: VillainProfile.station,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX・100BB。コーリングステーション相手に AJ のトップペア。リバーでどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 2,
      shortReason:
          'めったに降りない相手なので、'
          'AJ のトップペア・トップキッカーは大きめに打って取りにいきます。'
          '9x や J の弱いキッカーからも払ってもらえます。',
      gtoView:
          'バリューベットのサイズは相手のコール範囲で決まります。'
          '相手が広くコールするなら、'
          'その広さに合わせてサイズを上げるのが正しい調整です。',
      practicalView:
          'これがエクスプロイト（相手に合わせた調整）です。'
          '同じ AJ でも、タイトな相手なら'
          '33% 程度に落として薄く取りにいきます。',
      commonMistake:
          '相手のタイプに関係なく、'
          'いつも同じサイズで打ってしまうミスです。'
          '降りない相手からは、大きく打つほど利益が増えます。',
    ),
    _q(
      id: 'rv020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Qd',
      board: 'Kd 8h 5c 3s Ah',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: A が落ちた。BB check'],
      question: '6MAX・100BB。KQ のトップペアでしたが、リバーで A が落ちました。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          'A が落ちたことで KQ はトップペアではなくなりました。'
          '相手が A を持っていれば負けており、'
          '打っても弱い手しか降りません。',
      gtoView:
          'リバーのカードは、'
          'それまで積み上げてきたバリューを一瞬で消すことがあります。'
          '「まだトップペアか」を毎回確認してからサイズを決めます。',
      practicalView:
          'チェックすれば、'
          '相手が 8x や 5x のまま来ていたときに'
          'K のペアで勝てる回が残ります。',
      commonMistake:
          '「2 回打ったからリバーも打つ」と'
          '惰性で 3 回目を打ってしまうミスです。'
          'A で自分の手の順位が下がったことを見落としています。',
    ),
    _q(
      id: 'rv021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '5c 4c',
      board: 'Ah Kd 9s 7h 2d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX・100BB。54s は完全に外れました。'
          'この状況で 54s をブラフに選ぶ判断として正しいのはどれですか。',
      choices: [
        '適している。ショーダウンで勝てず、A も K もブロックしていないので降ろしたい手を残せる',
        '適していない。ブロッカーが無いのでブラフに向かない',
        '適している。5 と 4 が低いカードだから',
        '適していない。ショーダウンバリューがあるから',
      ],
      correctIndex: 0,
      shortReason:
          '54s はショーダウンでまず勝てないので、'
          'ブラフに回しても失うものがありません。'
          'また A も K も持っていないため、'
          '「降ろしたい相手のハンド」を自分で減らしていません。',
      gtoView:
          'ブラフには 2 種類の考え方があります。'
          '「相手のバリューをブロックする」ものと、'
          '「降ろしたい弱い手をブロックしない」ものです。'
          '54s は後者に当てはまります。',
      practicalView:
          '逆に AQ のようなハンドは、'
          'ショーダウンバリューがあるうえ'
          '相手の Ax を減らしてしまうので、ブラフには向きません。',
      commonMistake:
          '「ブラフには必ずブロッカーが必要」と'
          '一面だけで覚えてしまうミスです。'
          'ショーダウンバリューが無いことも、重要な選定基準です。',
    ),
    _q(
      id: 'rv022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac Qd',
      board: 'Qh 8c 5d 3s 2h',
      potBb: 20,
      villainProfile: VillainProfile.loosePassive,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: 普段は自分から打たない BB が、いきなり 18BB をベット'],
      question: '6MAX・100BB。受け身な相手がリバーで突然リードしてきました。AQ のトップペアでどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'トップペアなので Call'],
      correctIndex: 0,
      shortReason:
          '普段打たない相手が、'
          '2 回コールした後に自分から大きく打つのは'
          'ツーペア以上に強く偏ります。'
          'AQ のトップペアでは、そのレンジにほとんど勝てません。',
      gtoView:
          '相手の行動が普段と大きく違うときは、'
          'その行動を取るレンジが極端に狭いという情報です。'
          '受け身な相手のリバーリードは、最も信頼できる合図の一つです。',
      practicalView:
          '同じリードでも、'
          'ルース・アグレッシブな相手ならブラフが混ざるので受けます。'
          '「誰が打ったか」で答えが変わるスポットです。',
      commonMistake:
          '「トップペア・トップキッカーだから降りられない」と'
          '考えてしまうミスです。'
          '相手のレンジが強く偏っているなら、'
          'どんなに強く見える手でも降りるのが正解です。',
    ),
    _q(
      id: 'rv023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Kh 8h',
      board: 'Kc 7d 4s 9c 3h',
      potBb: 12,
      villainProfile: VillainProfile.nit,
      history: ['フロップ・ターンともに両者チェック', 'リバー: BB（あなた）の番'],
      question: '6MAX・100BB。タイトな相手と両者チェックで進み、K8s のトップペア。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 1,
      shortReason:
          '両者チェックで進んだので相手のレンジは弱めです。'
          '小さいサイズなら、7x や 9x、ポケットペアから'
          'コールをもらえる可能性があります。',
      gtoView:
          '薄いバリューは「相手が払える一番小さいサイズ」で取ります。'
          '大きく打つと弱い手が全部降り、'
          'K より強いキッカーだけが残ります。',
      practicalView:
          'タイトな相手はリバーのベットに降りやすいので、'
          '33% 程度に抑えるのが有効です。'
          'それでも打たなければゼロなので、打つ価値はあります。',
      commonMistake:
          '「キッカーが 8 だから危ない」とチェックしてしまうミスです。'
          '両者チェックのラインでは、相手に強い Kx はほとんど残っていません。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'rv024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ac Jd',
      board: 'Ah 9h 5c 2d 8h',
      potBb: 24,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ・ターンでコールし続けた',
        'リバー: ハートが 3 枚目。BB check → BTN が 20BB をベット',
      ],
      question: '6MAX・100BB。AJ のトップペアですが、リバーでフラッシュが完成しうるボードです。どうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'トップペアなので Call'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 20 ÷（24 + 20 + 20 ＝ 64）＝ 約31%。'
          'Ac を持っているだけでハートは 1 枚もブロックできておらず、'
          '相手の完成フラッシュを減らせていません。',
      gtoView:
          'ブラフキャッチは「相手のバリューをどれだけ減らせているか」で決めます。'
          'ここで守りたいのはハートのフラッシュに対してで、'
          'Ac はその役に立ちません。',
      practicalView:
          '同じ AJ でも、Ah を持っていれば'
          '相手のナッツフラッシュを消せるため受けられます。'
          'スート 1 枚で答えが変わる、ブロッカーの典型例です。',
      commonMistake:
          '「トップペア・トップキッカーだから受ける」と'
          'ハンドの名前で判断してしまうミスです。'
          '3 枚目のフラッシュカードが落ちた時点で、'
          'AJ は上位のブラフキャッチャーですらなくなっています。',
    ),
    _q(
      id: 'rv025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qc Jc',
      board: 'Ad Kd 7s 4h 2c',
      potBb: 20,
      stackBb: 70,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。QJ でストレートドローが外れました。'
          'オーバーベットのブラフに向かない理由として最も適切なものはどれですか。',
      choices: [
        'オーバーベットは必要成功率が高く、Q と J では相手の Ax・Kx を減らせないから',
        'オーバーベットはリバーでは使えないルールだから',
        'QJ にショーダウンバリューがあるから',
        'ポットが小さすぎるから',
      ],
      correctIndex: 0,
      shortReason:
          'ポット 20BB に 30BB のオーバーベットなら、'
          '必要成功率は 30 ÷ 50 ＝ 60%。'
          'ところが QJ は相手の続行レンジ（Ax・Kx）を'
          'まったくブロックしていません。',
      gtoView:
          'オーバーベットのブラフは、'
          '相手の続行レンジを強くブロックできるハンドに限定します。'
          'ここでは A か K を持っているハンドがその役割に適します。',
      practicalView:
          '同じブラフでも、'
          '小さいサイズなら必要成功率が下がるので QJ でも成立します。'
          'ブロッカーが弱いときは、サイズを下げるのが正しい調整です。',
      commonMistake:
          '「一番強く見えるベットをすれば降りるはず」と'
          'サイズだけで押そうとするミスです。'
          'サイズが大きいほど、ブラフの選定条件は厳しくなります。',
    ),
    _q(
      id: 'rv026',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '8s 7s',
      board: 'Kh Qd 9c 4s 3h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN check（チェックバック）',
        'ターン: BB check → BTN check',
        'リバー: BB が 10BB をベット',
      ],
      question: '6MAX・100BB。2 回チェックバックした後、リバーで打たれました。87s（何も無し）でどうしますか。',
      choices: ['Fold', 'Call', 'Raise（ブラフ）', 'Call してみる'],
      correctIndex: 2,
      shortReason:
          '2 回チェックバックしたことで、'
          'こちらのレンジは弱いと見られています。'
          'だからこそ相手は広くブラフしてきます。'
          '87s は勝てないので、レイズで降ろしにいく価値があります。',
      gtoView:
          '相手がこちらのレンジを「弱い」と決めつけて打ってくるとき、'
          'その相手のレンジ自体もブラフに偏ります。'
          '一番弱い手でレイズし返すのが、'
          'その偏りを利用する動きです。',
      practicalView:
          'この動きは相手が降りることが前提です。'
          '相手がレイズにほとんど降りないタイプなら、'
          '素直にフォールドします。',
      commonMistake:
          'チェックバックしたレンジをすべて降りてしまうミスです。'
          '毎回降りると、相手はリバーで何でも打つだけで利益が出ます。',
    ),
    _q(
      id: 'rv027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qd Qs',
      board: 'Ac 8h 6d 3s 2c',
      potBb: 24,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 8BB（ポットの 1/3）をベット'],
      question: '6MAX・100BB。ポット 24BB に 8BB の小さいベット。QQ でどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'A があるので Fold'],
      correctIndex: 1,
      shortReason:
          '必要勝率は 8 ÷（24 + 8 + 8 ＝ 40）＝ 20%。'
          'QQ は Ax に負けていますが、'
          '相手の小さいベットには外したドローも多く含まれます。'
          '5 回に 1 回勝てれば十分です。',
      gtoView:
          '小さいベットに対しては、'
          'レンジの広い部分で受けなければ'
          '相手のブラフが自動的に得になります。'
          'QQ はその中で確実に受ける側です。',
      practicalView:
          '同じ QQ でも、'
          'ポットサイズのベットなら必要勝率が 33% に上がり、'
          '降りる判断が出てきます。'
          'サイズによって答えが変わります。',
      commonMistake:
          '「A が落ちているから QQ は負け」と'
          'サイズを見ずに降りてしまうミスです。'
          '安いベットには、負けていても受ける価値があります。',
    ),
    _q(
      id: 'rv028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ah Ks',
      board: 'Ad Qc Jh 5s 4d',
      potBb: 24,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX・100BB。AK のトップペアですが、'
          'リバーでバリューベットが薄くなる理由はどれですか。',
      choices: [
        'K を持っているので、相手の KT のストレートを減らしてしまっているから',
        'A を持っているので、相手が A を持てず、コールしてくれる Ax がほとんど残っていないから',
        'ボードに Q と J があるから',
        'リバーが 4 だから',
      ],
      correctIndex: 1,
      shortReason:
          'A を 1 枚持っていることで、'
          'コールしてくれるはずの Ax の組み合わせが減っています。'
          '相手に残るのは、'
          'AK に勝っている QQ・JJ・KT か、まったく払えない弱い手です。',
      gtoView:
          'ブロッカーはブラフだけでなく、'
          'バリューベットの判断にも効きます。'
          '「自分が持っているせいで、相手が持てなくなる」ハンドが'
          'ちょうどコールしてほしい相手だった場合、'
          'バリューは薄くなります。',
      practicalView:
          '打たないという意味ではありません。'
          'サイズを小さくして、'
          'Qx や Jx から取りにいくのが現実的な調整になります。',
      commonMistake:
          'ブロッカーをブラフのときだけ考えるミスです。'
          'バリューベットでも「誰がコールできるか」を'
          '組み合わせで数える必要があります。',
    ),
    _q(
      id: 'rv029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kc Kd',
      board: 'Kh 9s 4c 7d 2h',
      potBb: 20,
      stackBb: 80,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。セット（KKK）です。ポット 20BB に対し 60BB のオーバーベットを選ぶには、'
          'レンジ全体で何が必要ですか。',
      choices: [
        '同じサイズで打つブラフを一定数用意しておくこと',
        '相手が必ず降りると分かっていること',
        'ボードにフラッシュが無いこと',
        'スタックがちょうど 60BB であること',
      ],
      correctIndex: 0,
      shortReason:
          '強い手だけを 60BB で打つと、'
          '相手は「大きいベット＝最強」と学習して降りるようになります。'
          '同じサイズでブラフも打つからこそ、'
          '相手はバリューにも払わざるを得なくなります。',
      gtoView:
          'ベットサイズごとに、'
          'バリューとブラフの両方を用意するのが基本の考え方です。'
          'サイズが大きいほど、'
          '相手に要求される勝率が上がるぶん、ブラフの比率も上げられます。',
      practicalView:
          '相手が観察してこないタイプなら、'
          'バランスを気にせずバリューだけ大きく打って構いません。'
          'この考え方が必要なのは、'
          'こちらの傾向を見ている相手に対してです。',
      commonMistake:
          '強い手のときだけサイズを上げてしまうミスです。'
          '短期的には取れますが、'
          '見ている相手にはすぐ読まれて降りられるようになります。',
    ),
    _q(
      id: 'rv030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ks Kd',
      board: 'Kc 8h 5s 2d 7c',
      potBb: 20,
      villainProfile: VillainProfile.looseAggressive,
      history: ['フロップ・ターンでコールし続けた', 'リバー: あなた（BB）の番'],
      question: '6MAX・100BB。ルース・アグレッシブな相手にセット（KKK）。リバーでどうしますか。',
      choices: ['Bet 75%', 'Bet 33%', 'Check（相手に打たせる）', 'All-in'],
      correctIndex: 2,
      shortReason:
          '相手はブラフが多いタイプで、'
          'こちらが 2 回コールしただけのレンジを弱いと見ています。'
          'チェックすれば、'
          '相手が外したドローや何も無い手で打ってくれます。',
      gtoView:
          'チェックが得になるのは、'
          '「相手のベット頻度が、こちらのベットで取れる額を上回る」ときです。'
          '攻撃的な相手ほど、この条件を満たしやすくなります。',
      practicalView:
          '相手が受け身なタイプなら、'
          'まったく逆に必ず自分から打ちます。'
          '同じセットでも、相手のタイプで真逆の行動になります。',
      commonMistake:
          '「強い手は必ず打つ」と決めてしまうミスです。'
          'ブラフの多い相手に打つと、'
          '相手のブラフを消して弱い手を降ろすだけになります。',
    ),
  ];
}
