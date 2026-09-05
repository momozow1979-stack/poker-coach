import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// バリュー / ブラフの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class ValueBluffQuizzes {
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
      category: QuizCategory.valueBluff,
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
      id: 'vb001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Kc',
      board: 'Kh 9d 4s 4h 2c',
      potBb: 18,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX・100BB。K94 42 のボードで AK のトップペア・トップキッカー。狙いはどれですか。',
      choices: ['バリューベット', 'ブラフ', 'ポットコントロールのチェック', 'ブラフキャッチのチェック'],
      correctIndex: 0,
      shortReason:
          '相手のレンジには K9・9x・ポケットペアなど、'
          'コールしてくれる弱い手が十分に残っています。'
          'ボードの 4 は両者が持っている扱いなので、'
          '実質「K のトップペア・最強キッカー」です。',
      gtoView:
          'バリューベットが成立する条件は'
          '「自分より弱い手がコールしてくれる」ことです。'
          'AK はキッカーが最強なので、'
          '相手が K を持っていても勝っています。',
      practicalView:
          '相手が降りやすいタイプならサイズを下げ、'
          '何でもコールするタイプならサイズを上げます。',
      commonMistake:
          '「4 がペアになって危ない」と止まってしまうミスです。'
          '相手が 4 を持っている組み合わせは、残り 2 枚ぶんしかありません。',
    ),
    _q(
      id: 'vb002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qs Js',
      board: 'Ks Ts 5d 3h',
      street: Street.turn,
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。ストレートドロー + フラッシュドロー。狙いはどれですか。',
      choices: [
        'バリューベット（今が最強のつもりで打つ）',
        'セミブラフ（降ろす + 完成したときの準備）',
        'ポットコントロールでチェック',
        'ブラフキャッチのためにチェック',
      ],
      correctIndex: 1,
      shortReason:
          'QJs は今は QJ ハイですが、'
          'A・9・スペードで一気に最強クラスになります。'
          '降ろせれば良し、コールされても次で逆転できるセミブラフです。',
      gtoView:
          'セミブラフは「フォールドエクイティ」と'
          '「完成したときのエクイティ」の両方から利益を得ます。'
          'ブラフの中でも優先度が高い形です。',
      practicalView:
          '相手が降りない相手なら、フォールドエクイティは期待できません。'
          'その場合はポットを育てる目的だけで打つ判断になります。',
      commonMistake:
          'セミブラフを「ただのブラフ」と考えて、'
          'コールされた瞬間に諦めてしまうミスです。',
    ),
    _q(
      id: 'vb003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '8h 8d',
      board: 'Ac Kd 9s 6h 2c',
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: CO bet → BB call', 'ターン: 両者チェック', 'リバー: BB check'],
      question: '6MAX・100BB。AK9 のボードで 88。BB のチェックにどうしますか。',
      choices: ['バリューベット', 'ブラフ', 'チェックしてショーダウンへ', 'オールイン'],
      correctIndex: 2,
      shortReason:
          '88 に払ってくれる手はほとんどありません。'
          '一方で相手が何も無いときには 88 のまま勝てます。'
          '打つ理由も降ろす理由もありません。',
      gtoView:
          'ハンドは「バリューベット」「ブラフ」'
          '「チェックしてショーダウン」の 3 つに分けられます。'
          '88 は 3 つ目です。',
      practicalView:
          '同じ 88 でも、ボードが 8 より低い数字ばかりなら'
          'バリューベットに変わります。'
          'ボードとの相対的な位置で役割が決まります。',
      commonMistake:
          'ショーダウンで勝てるハンドをブラフに使ってしまうミスです。'
          '勝てる可能性を自分から捨てることになります。',
    ),
    _q(
      id: 'vb004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qh Jh',
      board: 'Kh 8h 4c 2s 3d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: フラッシュが外れた。BB check'],
      question: '6MAX・100BB。QJ のフラッシュドローが外れました。狙いはどれですか。',
      choices: ['バリューベット', 'ブラフ', 'チェックしてショーダウンへ', 'ブラフキャッチ'],
      correctIndex: 1,
      shortReason:
          'QJ ハイでは、チェックしてもほぼ確実に負けています。'
          '勝つ道はブラフだけです。'
          'しかも相手のレンジには、'
          '降ろせる弱い Kx やペアが残っています。',
      gtoView:
          '「チェックしても勝てないハンド」は、'
          'ブラフの最有力候補になります。'
          'ブラフに回しても失うものがないからです。',
      practicalView:
          '相手が降りないタイプならブラフは成立しません。'
          'その場合はチェックして損失を抑えます。',
      commonMistake:
          '「外れたから諦める」とチェックしてしまうミスです。'
          'チェックした時点で、そのポットは確実に相手のものになります。',
    ),
    _q(
      id: 'vb005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah Jc',
      board: 'Ad 9h 5s 3c 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 7BB をベット'],
      question: '6MAX・100BB。AJ のトップペアで打たれました。あなたの役割はどれですか。',
      choices: ['バリューベット', 'ブラフ', 'ブラフキャッチ（相手のブラフに勝つためのコール）', 'レイズしてバリュー'],
      correctIndex: 2,
      shortReason:
          'AJ は相手のブラフには勝っていますが、'
          'AQ・AK・セットには負けています。'
          '「相手のブラフを捕まえる」ためにコールする役割です。',
      gtoView:
          'ブラフキャッチャーとは、'
          '「相手のブラフには勝ち、バリューには負ける」ハンドのことです。'
          'レイズするとブラフだけが降りるので、コールで受けます。',
      practicalView:
          '必要勝率は 7 ÷（20 + 7 + 7 ＝ 34）＝ 約21%。'
          'トップペアがこの水準を下回ることはまずありません。',
      commonMistake:
          'ブラフキャッチャーでレイズしてしまうミスです。'
          '勝っている相手（ブラフ）を全部降ろし、'
          '負けている相手だけを残すことになります。',
    ),
    _q(
      id: 'vb006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ks Qs',
      board: 'Kd Qc 7h 2s 3d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX・100BB。KQ のツーペアでリバー。狙いはどれですか。',
      choices: ['バリューベット', 'ブラフ', 'ポットコントロールのチェック', 'ブラフキャッチ'],
      correctIndex: 0,
      shortReason:
          'トップツーペアはこのボードでほぼ最強です。'
          '相手のレンジには Kx・Qx・7x が残っており、'
          '打てば十分に払ってもらえます。',
      gtoView:
          'バリューベットの条件は'
          '「自分より弱い手がコールしてくれる」ことです。'
          'ツーペアより弱い手は相手のレンジに多く残っています。',
      practicalView:
          '3 回打ち切ることでポットが最大になります。'
          'リバーでチェックすると、'
          '相手も弱い手でチェックバックして終わってしまいます。',
      commonMistake:
          '「もう十分取った」と最後の 1 回を打たないミスです。'
          '一番大きい額を賭けられるのはリバーです。',
    ),
    _q(
      id: 'vb007',
      difficulty: QuizDifficulty.beginner,
      street: Street.flop,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '9h 8h',
      board: 'Ac 7d 2s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。A72 のフロップで 98s。何も当たっていません。狙いはどれですか。',
      choices: ['バリューベット', 'ブラフ（相手が A を持ちにくいボード）', 'セミブラフ', 'ショーダウン狙いのチェック'],
      correctIndex: 1,
      shortReason:
          'A 高のボードは相手のコールレンジにほとんど当たりません。'
          '98s は何も無いので、'
          '降ろすことだけを狙った純粋なブラフになります。',
      gtoView:
          'ブラフが成立するのは「降ろしたい相手のハンドが存在する」ときです。'
          'A72 では、相手の大半がペアの無いハンドなので条件を満たします。',
      practicalView:
          '98s には 6 や T でストレートに近づく余地はありますが、'
          'まだ 2 枚必要な形です。'
          'セミブラフと呼べるほどのエクイティはありません。',
      commonMistake:
          'ブラフとセミブラフを混同するミスです。'
          '「完成すれば勝てるドローがあるか」が両者の違いです。',
    ),
    _q(
      id: 'vb008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '5c 5h',
      board: 'Ah Kd 9s 6c 2d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN がポットサイズの 20BB をベット'],
      question: '6MAX・100BB。55 でポットサイズのベットを受けました。どうしますか。',
      choices: ['Fold', 'Call（ブラフキャッチ）', 'Raise', 'ペアがあるので Call'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 33%。'
          '55 は A も K も 9 もブロックしておらず、'
          '相手のバリューレンジをまったく減らせていません。'
          'ブラフキャッチャーとしては下位です。',
      gtoView:
          'ブラフキャッチに残すべきなのは、'
          '相手のバリューハンドをブロックしているハンドです。'
          '同じ「ペアがある」でも、'
          'どのカードを持っているかで価値が変わります。',
      practicalView:
          '同じ状況で A9 を持っていれば、'
          '9 のペアと A のブロッカーで受けられます。'
          '55 はどちらの役割も果たせません。',
      commonMistake:
          '「ペアがあるから受ける」と考えるミスです。'
          '受けるかどうかは、'
          '相手のレンジの中でどこに位置しているかで決まります。',
    ),
    _q(
      id: 'vb009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ad Qd',
      board: 'Qh 8c 3s 5d',
      street: Street.turn,
      potBb: 12,
      villainProfile: VillainProfile.station,
      history: ['フロップ: BB check → CO bet → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。コーリングステーション相手に AQ のトップペア。狙いはどれですか。',
      choices: ['ブラフ', 'バリューベット（降りない相手から厚く取る）', 'ポットコントロール', 'チェックしてショーダウン'],
      correctIndex: 1,
      shortReason:
          'めったに降りない相手なので、'
          'AQ のトップペア・トップキッカーは'
          '8x や 3x、ドローから大きく取れます。',
      gtoView:
          '相手のコール範囲が広いほど、'
          'バリューベットできるハンドの幅も広がります。'
          '降りない相手には、バリューを厚くするのが正しい調整です。',
      practicalView:
          '同じ相手にはブラフをほぼゼロにします。'
          'バリューを増やしブラフを減らすのが、'
          'コーリングステーションへの基本対応です。',
      commonMistake:
          '降りない相手に「バランスを取るため」と'
          'ブラフを混ぜてしまうミスです。'
          'バランスが必要なのは、正しく降りてくる相手に対してだけです。',
    ),
    _q(
      id: 'vb010',
      difficulty: QuizDifficulty.beginner,
      street: Street.flop,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Th 9h',
      board: 'Jc 8d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。J83 で T9 のオープンエンド。狙いはどれですか。',
      choices: ['バリューベット', 'セミブラフ', '純粋なブラフ', 'チェックしてショーダウン'],
      correctIndex: 1,
      shortReason:
          'Q と 7 の 8 枚でストレートが完成します。'
          '降ろせれば良し、'
          'コールされても 3 回に 1 回は完成するセミブラフです。',
      gtoView:
          'セミブラフは、'
          '相手が降りる利益と完成する利益の両方を持ちます。'
          'エクイティがあるぶん、純粋なブラフより有利な形です。',
      practicalView:
          '相手がまったく降りないタイプでも、'
          '完成したときのポットを育てる目的で打てます。'
          '純粋なブラフとの大きな違いです。',
      commonMistake:
          'ドローを「まだ何も無い」と評価して'
          'チェックしてしまうミスです。'
          '8 アウツは十分に打つ根拠になります。',
    ),
    _q(
      id: 'vb011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Kh Kd',
      board: 'Kc 8h 5s 2d 7c',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 15BB をベット'],
      question: '6MAX・100BB。セット（KKK）で打たれました。どうしますか。',
      choices: ['Fold', 'Call', 'Raise（バリュー）', 'セットなので Call'],
      correctIndex: 2,
      shortReason:
          'セットはこのボードでほぼ最強です。'
          '相手が自分から打ってきたので、'
          'レイズすればさらに取れる可能性があります。',
      gtoView:
          '最強クラスを持ったときに'
          'コールで終わらせるのは、最も価値を取り逃がす選択です。'
          'レイズは、そこからもう一段取りにいく動きです。',
      practicalView:
          'レイズサイズは、'
          '相手が Kx やツーペアで払える範囲にします。'
          '大きすぎると降りられるだけです。',
      commonMistake:
          '「相手が打ってくれたからコールで十分」と'
          '満足してしまうミスです。'
          '一番強い手を持ったときこそ、最大まで取りにいきます。',
    ),
    _q(
      id: 'vb012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Jh Jd',
      board: 'Ac Kd 9h 4s 2c',
      potBb: 16,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: CO bet → BB call', 'ターン: 両者チェック', 'リバー: BB check'],
      question: '6MAX・100BB。AK9 のボードで JJ。BB のチェックにどうしますか。',
      choices: ['バリューベット', 'ブラフ', 'チェックしてショーダウンへ', 'オールイン'],
      correctIndex: 2,
      shortReason:
          'JJ に払ってくれるのは JJ より弱い手だけですが、'
          'このボードでそうした手はほとんど残っていません。'
          '一方で相手が何も無いときには JJ のまま勝てます。',
      gtoView:
          'オーバーペアであっても、'
          'A と K が落ちれば「上から 3 番目のペア」です。'
          '役割はバリューではなく、ショーダウンに向かうハンドに変わります。',
      practicalView:
          'ターンで両者がチェックしているので、'
          '相手のレンジは弱めです。'
          'チェックすれば勝てる回が十分にあります。',
      commonMistake:
          '「ポケットペアだから打てる」と考えるミスです。'
          'ボードとの相対的な位置で、打てるかどうかが決まります。',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'vb013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah 5c',
      board: 'Kh 9h 4c 2h 8d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX・100BB。ハート 3 枚のボードで A5o。Ah を持つことがブラフに向く理由はどれですか。',
      choices: [
        'A が最強のカードだから',
        '相手がナッツフラッシュを持つ組み合わせを消しているから',
        'A ハイでショーダウンに勝てるから',
        '5 がストレートに絡むから',
      ],
      correctIndex: 1,
      shortReason:
          '相手のコールレンジには完成したフラッシュが含まれます。'
          'Ah を自分が持っていることで、'
          '相手が最強のフラッシュを持つ可能性を消しています。',
      gtoView:
          'ブラフに選ぶべきなのは、'
          '相手が絶対に降りないハンドをブロックしているハンドです。'
          '続行レンジを直接減らせるぶん、成功率が上がります。',
      practicalView:
          '同じ A5o でも、Ac5c ならこの効果はありません。'
          'スート 1 枚で判断が変わるのがブロッカーの考え方です。',
      commonMistake:
          'ブロッカーを「自分の手が強くなること」と'
          '混同するミスです。'
          'Ah の価値は、相手のフラッシュを減らすことにあります。',
    ),
    _q(
      id: 'vb014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Qc',
      board: 'Ad Kh 7s 4c 2d',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX・100BB。AQ のトップペアですが、'
          'この状況でバリューベットが薄くなる理由はどれですか。',
      choices: [
        'A を持っているため、コールしてくれる Ax の組み合わせが減っているから',
        'Q が弱いから',
        'ボードに K があるから',
        'リバーが 2 だから',
      ],
      correctIndex: 0,
      shortReason:
          'A を 1 枚持っていることで、'
          '払ってくれるはずの Ax の組み合わせが減ります。'
          '相手に残るのは AK のような勝っている手か、'
          'まったく払えない手に偏ります。',
      gtoView:
          'ブロッカーはバリューベットの判断にも効きます。'
          '「自分が持っているせいで相手が持てなくなる」ハンドが'
          'ちょうどコールしてほしい相手だった場合、バリューは薄くなります。',
      practicalView:
          '打たないという意味ではありません。'
          'サイズを小さくして、'
          'Kx や 7x から取りにいくのが現実的な調整です。',
      commonMistake:
          'ブロッカーをブラフのときだけ考えるミスです。'
          'バリューでも「誰が払えるか」を組み合わせで数えます。',
    ),
    _q(
      id: 'vb015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah 9c',
      board: 'Kh Qh 7d 3c 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 15BB をベット'],
      question: '6MAX・100BB。A9 で何もありません。Ah を持った状態でこのベットにどうしますか。',
      choices: ['Fold', 'Call（ブラフキャッチ）', 'Raise', 'A ハイなので Fold'],
      correctIndex: 1,
      shortReason:
          'Ah を持っているので、'
          '相手がナッツフラッシュを持つ組み合わせが消えています。'
          'その分だけ相手のレンジはブラフに偏り、'
          '必要勝率 15 ÷ 50 ＝ 30% を満たす見込みが出ます。',
      gtoView:
          'ブラフキャッチに選ぶべきなのは、'
          '相手のバリューハンドをブロックしているハンドです。'
          'Ah はこのボードで最も価値のあるブロッカーです。',
      practicalView:
          '同じ A9 でも Ac9c ならブロッカーが無く、'
          '降りるほうが自然になります。',
      commonMistake:
          '「A ハイでは勝てない」と'
          '手の絶対的な強さだけで降りてしまうミスです。',
    ),
    _q(
      id: 'vb016',
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
          'ブラフに選ぶ判断として正しいのはどれですか。',
      choices: [
        '適している。ショーダウンで勝てず、A も K も持っていないので降ろしたい手を残せる',
        '適していない。ブロッカーが無いから',
        '適している。低いカードだから',
        '適していない。ショーダウンバリューがあるから',
      ],
      correctIndex: 0,
      shortReason:
          '54s はショーダウンでまず勝てないので、'
          'ブラフに回しても失うものがありません。'
          'また A も K も持っていないため、'
          '降ろしたい相手のハンドを自分で減らしていません。',
      gtoView:
          'ブラフには 2 種類の考え方があります。'
          '「相手のバリューをブロックする」ものと、'
          '「降ろしたい弱い手をブロックしない」ものです。'
          '54s は後者です。',
      practicalView:
          '逆に AQ のようなハンドは、'
          'ショーダウンバリューがあるうえ'
          '相手の Ax を減らしてしまうので、ブラフには向きません。',
      commonMistake:
          '「ブラフには必ずブロッカーが必要」と'
          '一面だけで覚えてしまうミスです。',
    ),
    _q(
      id: 'vb017',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kh 8h',
      board: 'Kc 7d 4s 9c 3h',
      potBb: 12,
      villainProfile: VillainProfile.nit,
      history: ['フロップ・ターンともに両者チェック', 'リバー: BB check'],
      question: '6MAX・100BB。タイトな相手と両者チェックで進み、K8s のトップペア。狙いはどれですか。',
      choices: ['薄いバリューベット（小さいサイズ）', 'ブラフ', 'チェックしてショーダウン', 'オールイン'],
      correctIndex: 0,
      shortReason:
          '両者チェックで進んだので相手のレンジは弱めです。'
          '小さいサイズなら、7x や 9x、'
          '小さいポケットペアからコールをもらえます。',
      gtoView:
          '「薄いバリュー」とは、'
          '自分より少しだけ弱い手から取りにいくことです。'
          'そのためには、その少しだけ弱い手が払える額に抑えます。',
      practicalView:
          'タイトな相手はリバーのベットに降りやすいので、'
          '33% 程度に抑えます。'
          'それでも打たなければゼロなので、打つ価値はあります。',
      commonMistake:
          '「キッカーが 8 だから危ない」とチェックしてしまうミスです。'
          '両者チェックのラインでは、'
          '相手に強い Kx はほとんど残っていません。',
    ),
    _q(
      id: 'vb018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh Th',
      board: '9c 8d 2s Kh 3c',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 7BB をベット'],
      question: '6MAX・100BB。ストレートが外れました。小さいベットへのチェックレイズブラフは有効ですか。',
      choices: [
        '有効。JT はショーダウンで勝てず、小さいベットは弱いレンジを示すから',
        '無効。ブラフは必ずベットで行うべきだから',
        '無効。JT にショーダウンバリューがあるから',
        '有効。J と T がボードに絡んでいるから',
      ],
      correctIndex: 0,
      shortReason:
          'JT ハイはショーダウンでほぼ勝てません。'
          '相手の小さいベットは「安く終わらせたい弱い手」を含むので、'
          'レイズで降ろせる余地があります。',
      gtoView:
          'チェックレイズのブラフに向くのは、'
          '「チェックしても勝てず、相手のレンジが強くない」場面です。'
          '小さいベットは、その条件を満たしやすい合図です。',
      practicalView:
          '相手が小さいベットにブラフキャッチで受け続けるタイプなら'
          '成立しません。'
          'またレイズサイズは大きめにしないと、'
          '相手にオッズを与えてしまいます。',
      commonMistake:
          '外したドローをすべてチェック・フォールドしてしまうミスです。'
          '一番弱いハンドこそ、ブラフに使う価値があります。',
    ),
    _q(
      id: 'vb019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ad Jd',
      board: 'Jh 9c 4s 6h 2c',
      potBb: 20,
      villainProfile: VillainProfile.station,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX・100BB。コーリングステーション相手に AJ のトップペア。サイズを上げるべきですか。',
      choices: [
        '上げるべき。降りない相手のコール範囲はサイズを上げてもほとんど狭まらないから',
        '下げるべき。降りられたくないから',
        '変えるべきでない',
        'チェックすべき',
      ],
      correctIndex: 0,
      shortReason:
          'めったに降りない相手には、'
          'サイズを上げても払ってもらえます。'
          '9x や J の弱いキッカーからも取れるので、'
          '大きく打つほど利益が増えます。',
      gtoView:
          'バリューベットのサイズは相手のコール範囲で決まります。'
          '相手が広くコールするなら、'
          'その広さに合わせてサイズを上げるのが正しい調整です。',
      practicalView:
          '同じ AJ でも、タイトな相手なら 33% 程度に落とします。'
          '相手のタイプでサイズだけを変えるのが、'
          '最も効果の大きい調整です。',
      commonMistake:
          '相手のタイプに関係なく、'
          'いつも同じサイズで打ってしまうミスです。',
    ),
    _q(
      id: 'vb020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Qd',
      board: 'Kd 8h 5c 3s Ah',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: A が落ちた。BB check'],
      question: '6MAX・100BB。KQ のトップペアでしたが、リバーで A が落ちました。狙いはどれですか。',
      choices: ['バリューベット', 'ブラフ', 'チェック（バリューが消えた）', 'オールイン'],
      correctIndex: 2,
      shortReason:
          'A が落ちたことで KQ はトップペアではなくなりました。'
          '相手が A を持っていれば負けており、'
          '打っても弱い手しか降りません。',
      gtoView:
          'リバーのカードは、'
          'それまで積み上げたバリューを一瞬で消すことがあります。'
          '「まだトップペアか」を毎回確認してから役割を決めます。',
      practicalView:
          'チェックすれば、'
          '相手が 8x や 5x のまま来ていたときに勝てる回が残ります。',
      commonMistake:
          '「2 回打ったからリバーも打つ」と'
          '惰性で 3 回目を打ってしまうミスです。',
    ),
    _q(
      id: 'vb021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '6s 5s',
      board: '9s 7d 2c 8h 3c',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: あなた（BB）の番'],
      question: '6MAX・100BB。65s でストレートが完成しています。BB のあなたはどうしますか。',
      choices: ['チェックして相手に打たせる', 'バリューベット（自分から打つ）', 'チェックフォールド', '小さくブラフ'],
      correctIndex: 1,
      shortReason:
          '9873 のボードで 65 のストレートを作れるのは'
          '主に BB のレンジです。'
          '相手はストレートを持ちにくいので、'
          '自分から打たないとポットが育ちません。',
      gtoView:
          '「自分のレンジにしか無い最強クラス」がある状態をナッツ有利と呼びます。'
          'ナッツ有利がある側は、'
          '不利なポジションからでも自分から打つ根拠があります。',
      practicalView:
          'チェックすると、'
          '相手も 9x でポットコントロールしてきて'
          '何も起きないまま終わる回が増えます。',
      commonMistake:
          '「BB は常にチェックから」と'
          '機械的に進めてしまうミスです。',
    ),
    _q(
      id: 'vb022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac Kd',
      board: 'Kh 9d 4s 7c 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ・ターンでベットしコールされた',
        'リバー: BB check → BTN bet 15BB → BB raise all-in 60BB',
      ],
      question: '6MAX。AK のトップペア・トップキッカーでリバーにオールインレイズされました。どうしますか。',
      choices: ['Fold', 'Call', '悩むが Call', 'トップペアなので Call'],
      correctIndex: 0,
      shortReason:
          'リバーのオールインレイズは、'
          'ツーペア以上に強く偏ります。'
          'トップペア・トップキッカーはバリューベットには十分ですが、'
          'レイズを受けて払うハンドではありません。',
      gtoView:
          'ハンドの役割は、相手の行動で変わります。'
          'AK はここまでバリューベットでしたが、'
          'レイズを受けた瞬間にブラフキャッチャーに降格しています。',
      practicalView:
          '必要勝率は 45 ÷（20 + 15 + 60 + 45）で約32%。'
          '相手のレイズレンジがブラフを多く含まない限り、届きません。',
      commonMistake:
          '「トップペア・トップキッカーで降りるのはもったいない」と'
          '払ってしまうミスです。'
          'バリューベットしたハンドが、そのまま強いとは限りません。',
    ),
    _q(
      id: 'vb023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Qh Jh',
      board: 'Th 9c 3d 2s',
      street: Street.turn,
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → CO bet 33% → BB call', 'ターン: BB check'],
      question:
          '6MAX・100BB。QJ でオープンエンド + ハートのバックドア。'
          'セミブラフとして打つ根拠を、最も正確に説明しているのはどれですか。',
      choices: [
        'K と 8 の 8 アウツで完成し、降ろせなくても約17%で逆転できるから',
        'QJ が強いハンドだから',
        'ボードが低いから',
        '相手が必ず降りるから',
      ],
      correctIndex: 0,
      shortReason:
          'K と 8 の 8 枚でストレートが完成します。'
          'ターン 1 枚なら約17%。'
          '降ろせる利益に加えて、'
          'この 17% ぶんの保険があるのがセミブラフです。',
      gtoView:
          'セミブラフの価値は'
          '「フォールドエクイティ」と「完成する確率」の合計です。'
          'どちらか一方でも大きければ、打つ根拠になります。',
      practicalView:
          'ハートのバックドアもあるので、'
          'リバーでハートが 2 枚並べば打ち続ける材料が増えます。'
          '完成しなくても、次に打つ理由が残ります。',
      commonMistake:
          'セミブラフのエクイティを実際より高く見積もるミスです。'
          'ターンでは 8 アウツでも約17%で、'
          'フロップの約32%とは大きく違います。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'vb024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac Ad',
      board: 'Ah 8c 5s 2d 7h',
      potBb: 30,
      stackBb: 70,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。セット（AAA）でオーバーベットを選ぶとき、'
          'レンジ全体で同時に用意すべきものはどれですか。',
      choices: [
        '同じサイズで打つブラフ',
        '同じサイズで打つ中くらいの強さのハンド',
        '何も必要ない',
        'チェックするバリューハンド',
      ],
      correctIndex: 0,
      shortReason:
          '最強クラスだけをオーバーベットに使うと、'
          '相手は「大きいベット＝最強」と学習して降りるようになります。'
          '外したドローなどを同じサイズに混ぜることで、'
          '相手は払わざるを得なくなります。',
      gtoView:
          'サイズごとにバリューとブラフの両方を用意するのが基本構造です。'
          'サイズが大きいほど相手に要求する勝率が上がるため、'
          'ブラフの比率も上げられます。',
      practicalView:
          '相手が観察してこないタイプなら、'
          'バランスを気にせずバリューだけ大きく打って構いません。',
      commonMistake:
          '強い手のときだけサイズを上げてしまうミスです。'
          '見ている相手にはすぐ読まれ、降りられるようになります。',
    ),
    _q(
      id: 'vb025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kh Qh',
      board: 'Ad Kd 7s 4h 2c',
      potBb: 20,
      stackBb: 70,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。KQ のセカンドペアです。'
          'この状況で「バリューでもブラフでもない」と判断できる根拠はどれですか。',
      choices: [
        '打っても Kx より弱い手しか降りず、コールしてくるのは Ax など勝っている手ばかりだから',
        'KQ が弱いハンドだから',
        'ボードにドローが無いから',
        'ポットが大きいから',
      ],
      correctIndex: 0,
      shortReason:
          'バリューベットには「自分より弱い手のコール」が必要で、'
          'ブラフには「降ろしたい相手のハンド」が必要です。'
          'KQ はそのどちらの条件も満たしていません。',
      gtoView:
          'ベットの目的は常に'
          '「弱い手から取る」か「強い手を降ろす」のどちらかです。'
          'どちらでもないなら、チェックが正解になります。',
      practicalView:
          'チェックすれば、'
          '相手が 7x や 4x のまま来ていたときに'
          'K のペアで勝てる回が残ります。',
      commonMistake:
          '「何かしないといけない」とベットしてしまうミスです。'
          'チェックは消極的な選択ではなく、'
          '条件を満たさないときの正しい選択です。',
    ),
    _q(
      id: 'vb026',
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
          'オーバーベットのブラフに向かない理由はどれですか。',
      choices: [
        '必要成功率が高いのに、Q と J では相手の Ax・Kx を減らせないから',
        'オーバーベットはリバーでは使えないから',
        'QJ にショーダウンバリューがあるから',
        'ポットが小さすぎるから',
      ],
      correctIndex: 0,
      shortReason:
          'ポット 20BB に 30BB なら、'
          '必要成功率は 30 ÷ 50 ＝ 60%。'
          'QJ は相手の続行レンジ（Ax・Kx）を'
          'まったくブロックしていません。',
      gtoView:
          'オーバーベットのブラフは、'
          '相手の続行レンジを強くブロックできるハンドに限定します。'
          'ここでは A か K を持つハンドが適します。',
      practicalView:
          '小さいサイズなら必要成功率が下がるので、'
          'QJ でも成立します。'
          'ブロッカーが弱いときは、サイズを下げるのが正しい調整です。',
      commonMistake:
          '「大きく打てば降りるはず」とサイズだけで押そうとするミスです。'
          'サイズが大きいほど、ブラフの選定条件は厳しくなります。',
    ),
    _q(
      id: 'vb027',
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
      question: '6MAX・100BB。AJ のトップペアですが、フラッシュが完成しうるボードです。どうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'トップペアなので Call'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 20 ÷（24 + 20 + 20 ＝ 64）＝ 約31%。'
          'Ac を持っているだけでハートを 1 枚もブロックできておらず、'
          '相手の完成フラッシュを減らせていません。',
      gtoView:
          'ブラフキャッチは'
          '「相手のバリューをどれだけ減らせているか」で決めます。'
          'ここで守るべき相手はハートのフラッシュで、'
          'Ac はその役に立ちません。',
      practicalView:
          '同じ AJ でも Ah を持っていれば'
          '相手のナッツフラッシュを消せるため受けられます。'
          'スート 1 枚で答えが変わります。',
      commonMistake:
          '「トップペア・トップキッカーだから受ける」と'
          'ハンドの名前で判断してしまうミスです。',
    ),
    _q(
      id: 'vb028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '8h 7h',
      board: 'Kd 9c 6s 5h 2d',
      potBb: 20,
      stackBb: 70,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。87s でストレートが外れました（8 も 7 もペアにならず）。'
          'このハンドをブラフに選ぶ判断はどうですか。',
      choices: [
        '適している。ショーダウンで勝てず、相手が降りる 9x や 6x をブロックしていないから',
        '適していない。ブロッカーが無いから',
        '適していない。ペアがあるから',
        '適している。ボードが低いから',
      ],
      correctIndex: 0,
      shortReason:
          '87 ハイはショーダウンで勝てないので、'
          'ブラフに回しても失うものがありません。'
          'さらに 9 も 6 も持っていないため、'
          '降ろしたい相手のハンドを自分で減らしていません。',
      gtoView:
          'ブラフ候補の選定基準は 2 つあります。'
          '「相手のバリューをブロックしているか」と'
          '「降ろしたい弱い手をブロックしていないか」です。'
          '後者も同じくらい重要です。',
      practicalView:
          '逆に 9x を持っていると、'
          '降ろしたい相手の 9x を自分で消してしまいます。'
          'しかも 9 のペアにはショーダウンバリューもあります。',
      commonMistake:
          '「ブロッカーがあるハンドだけがブラフに向く」と'
          '覚えてしまうミスです。'
          '降ろしたい手をブロックしないことも、選定基準の一つです。',
    ),
    _q(
      id: 'vb029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kc Kd',
      board: 'Kh 9s 4c 7d 2h',
      potBb: 20,
      villainProfile: VillainProfile.looseAggressive,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX・100BB。ルース・アグレッシブな相手にセット（KKK）。'
          'あえてチェックする根拠が成立するのはどんなときですか。',
      choices: [
        '相手がチェックに対して高頻度でブラフしてきて、その額が自分で打って取れる額を上回るとき',
        'セットは常にチェックすべきとき',
        'ボードが乾いているとき',
        'ポットが小さいとき',
      ],
      correctIndex: 0,
      shortReason:
          'チェックが得になるのは、'
          '「相手のブラフから得られる額」が'
          '「自分で打って取れる額」を上回るときだけです。'
          '攻撃的な相手ほど、この条件を満たしやすくなります。',
      gtoView:
          '強い手を必ず打つのは、'
          '相手が受け身のときの正解です。'
          '相手が高頻度で攻めてくるなら、'
          'チェックして受け止めるほうが利益になります。',
      practicalView:
          '相手が受け身なタイプなら、まったく逆に必ず自分から打ちます。'
          '同じセットでも、相手のタイプで真逆の行動になります。',
      commonMistake:
          '「強い手は必ず打つ」と決めてしまうミスです。'
          'ブラフの多い相手に打つと、'
          '相手のブラフを消して弱い手を降ろすだけになります。',
    ),
    _q(
      id: 'vb030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qd Qs',
      board: 'Ac 8h 6d 3s 2c',
      potBb: 24,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 8BB（ポットの 1/3）をベット'],
      question: '6MAX・100BB。ポット 24BB に 8BB の小さいベット。QQ でどうしますか。',
      choices: ['Fold', 'Call（ブラフキャッチ）', 'Raise', 'A があるので Fold'],
      correctIndex: 1,
      shortReason:
          '必要勝率は 8 ÷（24 + 8 + 8 ＝ 40）＝ 20%。'
          'QQ は Ax に負けていますが、'
          '相手の小さいベットには外したドローも多く含まれます。',
      gtoView:
          '小さいベットに対しては、'
          'レンジの広い部分で受けなければ'
          '相手のブラフが自動的に得になります。'
          'QQ はその中で確実に受ける側です。',
      practicalView:
          '同じ QQ でも、'
          'ポットサイズのベットなら必要勝率が 33% に上がり、'
          '降りる判断が出てきます。',
      commonMistake:
          '「A が落ちているから QQ は負け」と'
          'サイズを見ずに降りてしまうミスです。',
    ),
  ];
}
