import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// GTO の考え方の出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class GtoQuizzes {
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
      category: QuizCategory.gto,
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
      id: 'gt001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ad Jd',
      board: 'Ac 8h 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。「レンジ有利」が意味するのはどれですか。',
      choices: [
        '自分のハンドが相手のハンドより強いこと',
        'そのボードで、自分のレンジ全体が相手のレンジ全体より強いこと',
        '自分のポジションが相手より良いこと',
        'スタックが相手より深いこと',
      ],
      correctIndex: 1,
      shortReason:
          'レンジ有利は「今持っている 2 枚」ではなく、'
          'そのボードで自分が持ちうる全ハンドの分布が'
          '相手より強い状態を指します。',
      gtoView:
          'A 高のボードはオープンした側に AK・AQ・AJ が多く、'
          'BB のコールレンジには A が少ないため、レンジ有利が生まれます。',
      practicalView:
          'レンジ有利がある側は、'
          '小さいサイズで高頻度に打つのが基本方針になります。'
          '相手が降りない場合だけ、弱い手のベットを減らします。',
      commonMistake:
          '自分の手札の強さだけでベットを決めてしまうミスです。'
          '相手が何を持ちうるかを含めて考えるのがレンジ思考です。',
    ),
    _q(
      id: 'gt002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kh Qd',
      board: 'Kc 9s 4h 7d 2c',
      street: Street.river,
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 10BB', 'BB が 5BB をベット'],
      question: '6MAX・100BB。「MDF（最低限守るべき頻度）」が意味するのはどれですか。',
      choices: [
        '自分が勝つべき確率',
        '相手のブラフが自動的に利益にならないよう、レンジの何割を降りずに残すかの下限',
        'ブラフすべき割合',
        'ベットすべきサイズ',
      ],
      correctIndex: 1,
      shortReason:
          'ポット ÷（ポット + ベット）＝ 10 ÷ 15 ＝ 約67%。'
          'これを下回って降りると、'
          '相手はどんな 2 枚で打っても得をするようになります。',
      gtoView:
          'MDF は「コールする側が守る」ための基準で、'
          'ハンド 1 つの話ではなくレンジ全体の話です。'
          'ベットが大きいほど、守るべき割合は下がります。',
      practicalView:
          'ブラフをほとんどしない相手に対しては、'
          'MDF を守る必要はありません。'
          'あくまで「相手が正しくブラフしてくる場合」の下限です。',
      commonMistake:
          '必要勝率（1 ハンドがコールできるかの基準）と'
          '混同するミスです。'
          '25% と 67% は、まったく別のことを測っています。',
    ),
    _q(
      id: 'gt003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah 5h',
      board: 'Kh Qh 4c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。「ブロッカー」が意味するのはどれですか。',
      choices: [
        '自分の手を強くするカード',
        '自分が持っていることで、相手がそのカードを含むハンドを持てなくなる効果',
        '相手のベットを止める行動',
        'ポジションのこと',
      ],
      correctIndex: 1,
      shortReason:
          'Ah を持っていると、'
          '相手が Ah を含むナッツフラッシュドローを持つことはできません。'
          '相手のレンジを直接削るのがブロッカーの効果です。',
      gtoView:
          'ポーカーの判断は「相手が何を持ちうるか」で決まります。'
          '自分の 2 枚は、その可能性を直接減らす情報でもあります。',
      practicalView:
          'ブロッカーが効くのは、'
          '相手のレンジの重要な部分を減らせるときだけです。'
          '相手がほとんど持っていないハンドをブロックしても意味がありません。',
      commonMistake:
          'ブロッカーを「自分の手が強くなること」と'
          '混同するミスです。'
          '効果は相手側にあります。',
    ),
    _q(
      id: 'gt004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Kc',
      board: 'Ah 7d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。乾いたボードでレンジ有利がある側の基本方針はどれですか。',
      choices: ['小さいサイズを高い頻度で使う', '大きいサイズを低い頻度で使う', 'すべてチェックする', '常にオールインする'],
      correctIndex: 0,
      shortReason:
          '相手がほとんど当たっていないボードでは、'
          '小さいベットでも十分に降ろせます。'
          '小さければ弱い手で打っても損が小さく、'
          'レンジ全体で打てるようになります。',
      gtoView:
          'サイズと頻度は逆の関係にあります。'
          '小さいサイズは高頻度で、'
          '大きいサイズは低頻度で使うのが基本の形です。',
      practicalView:
          '相手が小さいベットに何でもコールしてくるタイプなら、'
          '弱い手でのベットを減らし、'
          '強い手だけサイズを上げる形に切り替えます。',
      commonMistake:
          '「レンジ有利があるから大きく打つ」と考えるミスです。'
          'レンジ有利は「広く打てる」ことを意味し、'
          '「大きく打てる」ことではありません。',
    ),
    buildDefinitionQuiz(
      id: 'gt005',
      category: QuizCategory.gto,
      difficulty: QuizDifficulty.beginner,
      question: '「バランスが取れている」とはどういう状態ですか。',
      choices: [
        '同じ行動の中に、強い手と弱い手が適切な割合で混ざっている状態',
        '毎回同じサイズで打つ状態',
        '勝率がちょうど 50% の状態',
        'ブラフを一切しない状態',
      ],
      correctIndex: 0,
      shortReason:
          '同じ行動に強弱が混ざっていれば、'
          '相手はその行動を見ても'
          'どちらを持っているか判断できません。',
      gtoView:
          'バランスの目的は「相手に正しく対応させないこと」です。'
          '行動と手の強さが 1 対 1 で結びつくと、'
          '相手は毎回正しい選択ができるようになります。',
      practicalView:
          '相手が観察してこないタイプなら、'
          'バランスを気にする必要はありません。'
          '弱点があるなら、そこを突くほうが利益になります。',
      commonMistake:
          'バランスを「常に守るべきルール」だと'
          '思い込んでしまうミスです。'
          'バランスは、相手に読まれることを防ぐための手段です。',
    ),
    _q(
      id: 'gt006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '9c 8c',
      board: '9h 7d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'あなた（BB）から先に行動する'],
      question: '6MAX・100BB。「エクイティ」が意味するのはどれですか。',
      choices: [
        '今この時点で、最後まで進んだときに勝てる確率',
        'ポットにある自分のチップの割合',
        '相手が降りる確率',
        'ハンドの強さのランク',
      ],
      correctIndex: 0,
      shortReason:
          'エクイティは「ここから最後まで進んだら何%勝つか」です。'
          'ポットの中の自分の取り分を表す数字として使われます。',
      gtoView:
          'ポーカーの利益は「エクイティ」と'
          '「そのエクイティをどれだけ実現できるか」の掛け算です。'
          '不利なポジションでは、後者が下がります。',
      practicalView:
          'エクイティが高くても、'
          '相手に打たれ続けて降りざるを得なければ実現できません。'
          'だから「実現しやすさ」も同時に考えます。',
      commonMistake:
          'エクイティだけを見て判断してしまうミスです。'
          '見かけの勝率と、実際に取れる勝率は別物です。',
    ),
    _q(
      id: 'gt007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ah Kh',
      board: 'Ad Kc 7s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。「ナッツ有利」と「レンジ有利」の違いはどれですか。',
      choices: [
        'ナッツ有利は最強クラスの偏り、レンジ有利は全体の強さの偏り',
        '同じ意味',
        'ナッツ有利はプリフロップだけの概念',
        'レンジ有利はリバーだけの概念',
      ],
      correctIndex: 0,
      shortReason:
          'レンジ有利は「平均的にどちらが強いか」、'
          'ナッツ有利は「最強クラスをどちらが多く持っているか」です。'
          '両方を持っている側が、最も自由に攻められます。',
      gtoView:
          '大きいサイズやオーバーベットを使えるのは、'
          'ナッツ有利がある側です。'
          '全体で強いだけでは、大きく打つ根拠になりません。',
      practicalView:
          'AK7 のボードでは、'
          'オープンした側が AA・KK・AK を多く持つため'
          '両方の有利を持っています。'
          '765 のような低いボードでは、両方が相手側に移ります。',
      commonMistake:
          '2 つを同じものとして扱ってしまうミスです。'
          'レンジ有利があってもナッツ有利が無ければ、'
          '大きく打つと危険です。',
    ),
    _q(
      id: 'gt008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '7c 6c',
      board: 'Ad Kh 9s 4c 2d',
      street: Street.river,
      potBb: 10,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 10BB', 'BB check'],
      question: '6MAX・100BB。ポット 10BB に 5BB のブラフ。損益分岐点となる成功率はどれですか。',
      choices: ['約25%', '約33%', '約50%', '約67%'],
      correctIndex: 1,
      shortReason:
          'ベット ÷（ポット + ベット）＝ 5 ÷ 15 ＝ 約33%。'
          '3 回に 1 回降ろせれば、それだけで損はしません。',
      gtoView:
          'ブラフの損益分岐点はベットサイズだけで決まります。'
          '小さく打つほど必要な成功率は下がり、'
          '大きく打つほど上がります。',
      practicalView:
          '相手が「1/2 ポットには 3 回に 1 回以上降りる」タイプなら、'
          'このブラフは成立します。',
      commonMistake:
          '「ブラフは半分以上成功しないと意味がない」と'
          '考えるミスです。'
          '実際は 33% で十分です。',
    ),
    _q(
      id: 'gt009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.utg,
      villain: Position.bb,
      heroCards: 'Ac Kd',
      board: '7h 6h 5s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。765 のボードで、レンジ有利がどちらにあるか正しいのはどれですか。',
      choices: [
        'BB 側。コールレンジに 87s・65s・77・66・55 が多く含まれるから',
        'UTG 側。オープンレンジのほうが強いから',
        'どちらでもない',
        'ポジションのある側に必ずある',
      ],
      correctIndex: 0,
      shortReason:
          'UTG のタイトなレンジには 765 に当たるハンドがほとんどありません。'
          '一方 BB のコールレンジには、'
          'この 3 枚に絡む形が多数含まれます。',
      gtoView:
          'レンジ有利はボードごとに入れ替わります。'
          '高いカードのボードではレイズした側に、'
          '低くつながったボードではコールした側に傾きます。',
      practicalView:
          'レンジ有利が無い側は、'
          'ベット頻度を大きく下げてポットを小さく保ちます。'
          'AK でも無理に打たないのはこのためです。',
      commonMistake:
          '「レイズした側が常に有利」と'
          '思い込んでしまうミスです。'
          'ボードによって、有利は簡単に入れ替わります。',
      relatedRangeSpotId: '6max_utg_open',
    ),
    _q(
      id: 'gt010',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Kd',
      board: 'Qh 8d 3c',
      potBb: 5.5,
      stackBb: 97.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。「SPR」が戦い方に与える影響として正しいのはどれですか。',
      choices: [
        'SPR が小さいほど、トップペア級でもスタックを入れやすくなる',
        'SPR が小さいほど、より強い手が必要になる',
        'SPR はハンドの強さと無関係',
        'SPR はプリフロップだけの概念',
      ],
      correctIndex: 0,
      shortReason:
          'SPR ＝ 残りスタック ÷ ポット。'
          '小さいほど「あと何ポットぶん賭けられるか」が減るので、'
          '入れ切るのに必要な強さも下がります。',
      gtoView:
          '同じトップペアでも、'
          'SPR 1 なら全額入れるハンド、'
          'SPR 10 なら慎重に扱うハンドになります。'
          'ハンドの価値は SPR で決まります。',
      practicalView:
          '3Bet ポットは SPR が浅くなるので、'
          '通常より弱い手でスタックを入れることになります。'
          'ポットの種類によって基準が変わります。',
      commonMistake:
          'ハンドの強さだけを見て、'
          'スタックの深さを考えないミスです。',
    ),
    _q(
      id: 'gt011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh Th',
      board: 'Qc 9d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 1.8BB'],
      question: '6MAX・100BB。「セミブラフ」の定義として正しいのはどれですか。',
      choices: [
        '今は勝っていないが、完成すれば勝てるドローを持った状態でのベットやレイズ',
        '小さいサイズのブラフ',
        '半分の確率で成功するブラフ',
        'ブラフキャッチのこと',
      ],
      correctIndex: 0,
      shortReason:
          'JT は今 Q に負けていますが、'
          'K か 8 でストレートが完成します。'
          '降ろせれば良し、'
          'コールされても完成する可能性が残るのがセミブラフです。',
      gtoView:
          'セミブラフは「フォールドエクイティ」と'
          '「完成する確率」の 2 つから利益を得ます。'
          '純粋なブラフより有利な形です。',
      practicalView:
          '相手が降りないタイプでも、'
          '完成したときのポットを育てる目的で打てます。'
          '純粋なブラフとの決定的な違いです。',
      commonMistake:
          'セミブラフを「弱いブラフ」と考えてしまうミスです。'
          '実際にはブラフの中で最も優先度が高い形です。',
    ),
    _q(
      id: 'gt012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ad Ah',
      board: 'Kc 9h 4s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。「エクイティ・デナイアル（勝つ権利を奪う）」が意味するのはどれですか。',
      choices: [
        'ベットして相手を降ろし、相手が持っていた逆転の可能性を消すこと',
        '相手のブラフを止めること',
        'ポットを大きくすること',
        'ショーダウンまで進むこと',
      ],
      correctIndex: 0,
      shortReason:
          'AA は今勝っていますが、'
          '相手が Q や J でペアになれば逆転されます。'
          '打って降ろせば、'
          'その逆転の可能性ごと消せます。',
      gtoView:
          'ベットには「バリューを取る」だけでなく'
          '「相手のエクイティを消す」役割があります。'
          '逆転される余地が大きいほど、後者の価値が上がります。',
      practicalView:
          '相手のレンジにオーバーカードやドローが多いほど、'
          '打つ理由が増えます。'
          '逆に相手がほとんど何も持てないボードでは、急ぐ必要がありません。',
      commonMistake:
          '「バリューが取れないなら打たない」と考えるミスです。'
          '相手の逆転を防ぐことも、立派なベットの目的です。',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'gt013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Kd Qc',
      board: 'Kc 9s 4h 7d 2c',
      street: Street.river,
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: [
        'リバー時点のポットは 20BB',
        'BTN が 20BB（ポットサイズ）をベット',
        'あなたのレンジには 40 通りが残っている',
      ],
      question: '6MAX・100BB。ポットサイズのベットに対し、40 通りのうち何通りを続ければ降りすぎになりませんか。',
      choices: ['10通り', '13通り', '20通り', '27通り'],
      correctIndex: 2,
      shortReason:
          '守るべき割合は 20 ÷（20 + 20）＝ 50%。'
          '40 通りの半分で 20 通りです。',
      gtoView:
          '守る「割合」を具体的な「通り数」に落とすと、'
          'どこまでのハンドで受けるかが決まります。'
          '強い順に 20 通り並べ、そこが受ける下限になります。',
      practicalView:
          'この計算は相手が正しくブラフしてくる前提です。'
          'ブラフをしない相手には、20 通りも守る必要はありません。',
      commonMistake:
          '割合だけ覚えて、実際のハンドに落とし込まないミスです。'
          '自分のレンジに何が残っているか把握していなければ実行できません。',
    ),
    _q(
      id: 'gt014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Kd',
      board: 'Ah 7d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。A73 レインボー。'
          '「レンジ全体を小さく打つ」戦略が機能する理由として正しいのはどれですか。',
      choices: [
        '小さいサイズなら弱い手で打っても損が小さく、強い手と同じサイズに混ぜられるから',
        '小さいサイズのほうが相手が降りやすいから',
        '小さいサイズは必ず得だから',
        '相手のスタックが減るから',
      ],
      correctIndex: 0,
      shortReason:
          '弱い手で大きく打つと、外したときの損が大きくなります。'
          '小さければ損が抑えられるので、'
          'レンジ全体を同じサイズに乗せられます。',
      gtoView:
          '「サイズを揃える」ことが目的ではなく、'
          '「同じサイズに強弱を混ぜられる」ことが目的です。'
          '結果として相手はベットから情報を得られなくなります。',
      practicalView:
          '相手が小さいベットに何でもコールしてくるなら成立しません。'
          'その場合は弱い手を減らし、強い手だけサイズを上げます。',
      commonMistake:
          '「小さいベットは弱い」と考えてしまうミスです。'
          'この戦略では、小さいベットの中に最強クラスも入っています。',
    ),
    buildDefinitionQuiz(
      id: 'gt015',
      category: QuizCategory.gto,
      difficulty: QuizDifficulty.intermediate,
      question: '「相手を無差別（インディファレント）にする」とはどういう意味ですか。',
      choices: [
        'コールしてもフォールドしても、相手の期待値が同じになる状態にすること',
        '相手を必ず降ろすこと',
        '相手に必ずコールさせること',
        '相手のレンジを読むこと',
      ],
      correctIndex: 0,
      shortReason:
          'バリューとブラフの比率を適切にすると、'
          '相手はコールしてもフォールドしても'
          '同じ結果になります。'
          'つまり、どちらを選んでも得をしません。',
      gtoView:
          'これが GTO の中心的な考え方です。'
          '相手の選択に関係なく自分の利益が確保される状態を作ります。'
          '「相手を間違えさせる」のではなく、'
          '「相手に正解が無い状態にする」戦略です。',
      practicalView:
          '実戦では相手は無差別なときに'
          '一方に偏った選択をします。'
          'その偏りが分かれば、'
          'バランスを崩して突くほうが利益になります。',
      commonMistake:
          'GTO を「相手に勝つための最強手」だと'
          '思い込んでしまうミスです。'
          'GTO は負けない戦略であって、最大に勝つ戦略ではありません。',
    ),
    _q(
      id: 'gt016',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '7h 6h',
      board: '9c 8d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'あなた（BB）から先に行動する'],
      question:
          '6MAX・100BB。「エクイティの実現（リアライゼーション）」が'
          '不利なポジションで下がる理由はどれですか。',
      choices: [
        '相手に先に行動を見せることになり、降りざるを得ない場面が増えるから',
        '不利なポジションでは配られるカードが弱いから',
        'ポットオッズが悪くなるから',
        '相手のエクイティが上がるから',
      ],
      correctIndex: 0,
      shortReason:
          '見かけの勝率が同じでも、'
          '相手に打たれて降りると、その勝率は実現できません。'
          '不利なポジションでは、'
          'この「降ろされる」場面が増えます。',
      gtoView:
          '利益は「エクイティ × 実現率」で決まります。'
          'ポジションは実現率を大きく左右する要素です。',
      practicalView:
          'だからこそ、不利なポジションではレンジを締めます。'
          '同じ勝率でも、実際に取れる額が少ないためです。',
      commonMistake:
          'エクイティ計算だけでコールを決めてしまうミスです。'
          '「その勝率を最後まで持っていけるか」まで考えます。',
    ),
    buildDefinitionQuiz(
      id: 'gt017',
      category: QuizCategory.gto,
      difficulty: QuizDifficulty.intermediate,
      question: '「レンジがキャップされている（上限が見えている）」とはどういう状態ですか。',
      choices: [
        'ある行動を選んだ時点で、最強クラスのハンドがそのレンジから抜けている状態',
        'レンジが狭い状態',
        'レンジに強い手しかない状態',
        'ポジションが無い状態',
      ],
      correctIndex: 0,
      shortReason:
          '例えばプリフロップでコールしただけの側は、'
          'AA・KK を 3Bet に回しているぶん、'
          'そのレンジから最強クラスが抜けています。',
      gtoView:
          '上限が見えているレンジは、'
          '大きいベットやオーバーベットに対して守りにくくなります。'
          '相手はその弱点を狙って攻められます。',
      practicalView:
          '自分のレンジに上限ができる行動'
          '（コールだけで進める、チェックバックを繰り返す）を'
          '取ったときは、そのあと攻められる前提で進めます。',
      commonMistake:
          '自分のレンジがどう見えているかを'
          '意識しないまま進めてしまうミスです。'
          '相手はこちらの行動からレンジを推測しています。',
    ),
    _q(
      id: 'gt018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ad Kh',
      board: 'Qc 8h 3d 5s 2c',
      street: Street.river,
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['リバー時点のポットは 20BB', 'BB check'],
      question:
          '6MAX・100BB。リバーでポットサイズのベットをする場合、'
          'バリューとブラフの比率の考え方として正しいのはどれですか。',
      choices: [
        '相手に必要な勝率（33%）と同じ割合だけブラフを混ぜると、相手はコールしてもフォールドしても同じになる',
        'ブラフは常に半分にする',
        'ブラフは一切混ぜない',
        '比率はサイズと無関係',
      ],
      correctIndex: 0,
      shortReason:
          'ポットサイズのベットに対し、'
          '相手は 33% の勝率が必要です。'
          'ブラフを 3 分の 1 の割合で混ぜれば、'
          '相手のコールとフォールドの結果が等しくなります。',
      gtoView:
          'サイズが大きいほど、'
          '相手に要求される勝率が上がるぶん、'
          '混ぜられるブラフの割合も上がります。',
      practicalView:
          '実戦でこの比率を厳密に守る必要はありません。'
          '重要なのは「大きく打つときほどブラフを増やせる」という'
          '方向性を理解しておくことです。',
      commonMistake:
          'サイズに関係なく同じ割合でブラフしてしまうミスです。'
          '小さいベットでブラフを多くしすぎると、'
          '相手に安く受けられて損をします。',
    ),
    _q(
      id: 'gt019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jc Tc',
      board: 'Kh 9d 4s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'あなた（BB）から先に行動する'],
      question: '6MAX・100BB。BB がフロップで「まとめてチェックする」戦略を取る理由はどれですか。',
      choices: [
        'ポジションが無いので、行動から手の強さが読まれないようにまとめる',
        'チェックのほうが常に得だから',
        '弱い手しか無いから',
        'ベットが禁止されているから',
      ],
      correctIndex: 0,
      shortReason:
          '不利なポジションでは行動の回数が限られます。'
          '強い手と弱い手を同じチェックに混ぜておけば、'
          '相手はこちらのレンジを絞れません。',
      gtoView:
          'これを「チェックレンジ」と呼びます。'
          '相手にレンジ有利があるボードでは、'
          'まとめてチェックしてから受ける形が基本になります。',
      practicalView:
          'ただしボードによっては、'
          'BB のレンジにしか無い強い形が多いこともあります。'
          'その場合は自分から打つ（リードする）根拠が生まれます。',
      commonMistake:
          '「強い手は必ず打つ」と決めてしまうミスです。'
          'その癖がつくと、'
          'チェックした瞬間に弱いと決めつけられて攻められます。',
    ),
    _q(
      id: 'gt020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ah Ad',
      board: 'Jh Ts 9c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。JT9 のボードで AA。'
          'ベット頻度を下げるべき理由として正しいのはどれですか。',
      choices: [
        'このボードは相手のコールレンジに何重にも当たり、レンジ有利もナッツ有利も相手側にあるから',
        'AA が弱いハンドだから',
        'ポジションが無いから',
        'ポットが小さいから',
      ],
      correctIndex: 0,
      shortReason:
          'QJ・JT・T9・98・87 のストレートやツーペアは、'
          'BB のコールレンジに多く含まれます。'
          'CO のオープンレンジには、こうした形が相対的に少なくなります。',
      gtoView:
          'レンジ有利とナッツ有利の両方が相手にあるボードでは、'
          'ベット頻度は大きく下がります。'
          'AA という強さも、そのボード構造の前では相対的なものです。',
      practicalView:
          'チェックすれば、'
          '安全なターンが落ちたときに打ち直せます。'
          'ポットを膨らませないことが優先です。',
      commonMistake:
          '「AA は最強だから常に打つ」と考えるミスです。'
          'プリフロップの最強ハンドは、'
          'フロップが開いた瞬間に順位が入れ替わります。',
    ),
    _q(
      id: 'gt021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah 5h',
      board: 'Kh Qh 4c 2s 8d',
      street: Street.river,
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: フラッシュは完成せず。BB check'],
      question:
          '6MAX・100BB。Ah を持ってフラッシュが外れました。'
          'ブラフ候補として優先される理由はどれですか。',
      choices: [
        'ショーダウンで勝てず、かつ相手のフラッシュドローの一部をブロックしているから',
        'A ハイで勝てるから',
        '5 がストレートに絡むから',
        'ハートを持っているから相手も持っていないから',
      ],
      correctIndex: 0,
      shortReason:
          'A5 ハイはショーダウンでまず勝てません。'
          'さらに Ah を持つことで、'
          '相手が Ah を含むハンドでコールしてくる可能性を消しています。',
      gtoView:
          'ブラフ候補は「失うショーダウンバリューが小さい」ものから選びます。'
          'そのうえでブロッカー効果があれば、優先度がさらに上がります。',
      practicalView:
          '同じ A5 でも Ac5c ならブロッカーが弱くなります。'
          'ただしショーダウンバリューが無い点は変わらないので、'
          'ブラフ候補ではあります。',
      commonMistake:
          'ショーダウンバリューのあるハンド（AQ など）を'
          'ブラフに使ってしまうミスです。'
          '勝てる可能性を自分から捨てることになります。',
    ),
    _q(
      id: 'gt022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '5h 5c',
      board: '9h 6d 3s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'あなた（BB）から先に行動する'],
      question:
          '6MAX・100BB。963 のボードで、BB が自分から打つ（リードする）'
          '根拠になるのはどれですか。',
      choices: [
        'BB のコールレンジにしか無い形（96s・63s・99・66・33）が多く、ナッツ有利があるから',
        'BB はいつでもリードすべきだから',
        '相手を試したいから',
        'ポットが小さいから',
      ],
      correctIndex: 0,
      shortReason:
          '963 のような低いボードは、'
          'BB のコールレンジにしか無い形が多く、'
          'BTN のオープンレンジには少ない構造です。',
      gtoView:
          'ナッツ有利がある側は、'
          '不利なポジションからでも自分から打つ根拠があります。'
          'レンジ有利（全体の強さ）とは別の判断材料です。',
      practicalView:
          '逆に AK7 のような高いボードでは、'
          '両方の有利が相手側にあります。'
          'そこでリードすると、'
          '強いレンジに向かって不利な位置から仕掛けることになります。',
      commonMistake:
          'ドンクベットを「相手を試す動き」として使ってしまうミスです。'
          'ボード構造の裏付けが必要です。',
    ),
    _q(
      id: 'gt023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Kh',
      board: 'Kd 9s 4h 7c 2d',
      street: Street.river,
      potBb: 20,
      stackBb: 80,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。セット（KKK）で複数のサイズを使い分けるとき、'
          '「サイズごとにレンジを作る」とはどういう意味ですか。',
      choices: [
        '各サイズにバリューとブラフの両方を配置し、どのサイズを見ても相手が読めないようにすること',
        '強い手ほど大きいサイズを使うこと',
        'サイズを毎回ランダムに選ぶこと',
        '常に同じサイズを使うこと',
      ],
      correctIndex: 0,
      shortReason:
          '大きいサイズに最強クラスだけを入れると、'
          '相手は「大きいベット＝最強」と学習します。'
          '各サイズにブラフも配置することで、'
          'サイズが情報にならなくなります。',
      gtoView:
          'サイズは選択肢を増やす道具ですが、'
          '選択肢ごとに手の強さが決まってしまえば、'
          'かえって相手に情報を与えます。',
      practicalView:
          '実戦では 2 種類（小さい / 大きい）程度に絞れば十分です。'
          '種類を増やすほど、各サイズにブラフを用意する手間が増えます。',
      commonMistake:
          'サイズの種類を増やせば強くなると'
          '思い込んでしまうミスです。'
          '扱いきれない数のサイズは、ただの癖になります。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'gt024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ac Qd',
      board: 'Ah 8c 5s 3d 2h',
      street: Street.river,
      potBb: 24,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: BB check → BTN が 24BB をベット'],
      question:
          '6MAX・100BB。GTO 戦略に従うことと、'
          '相手を最大限に利用することの関係として正しいのはどれですか。',
      choices: [
        'GTO は相手の弱点を突かない代わりに、こちらも突かれない戦略。相手に明確な偏りがあるならバランスを崩したほうが利益は大きい',
        'GTO は常に最大の利益を生む戦略',
        'GTO は初心者向けの簡易戦略',
        'GTO と実戦の判断は無関係',
      ],
      correctIndex: 0,
      shortReason:
          'GTO は「相手が何をしても負けない」戦略です。'
          'しかし相手が明らかに降りすぎ・払いすぎなら、'
          'そこを突いたほうが利益は大きくなります。',
      gtoView:
          'GTO は基準点です。'
          '相手の傾向が分からないときの出発点として使い、'
          '情報が集まったらそこから離れます。',
      practicalView:
          '離れた分だけ、自分にも弱点ができます。'
          '相手が調整してきたら、また基準点に戻す必要があります。',
      commonMistake:
          '「GTO が常に正解」と考えて、'
          '明らかに弱い相手にもバランスを守ってしまうミスです。'
          '利益を取り逃がすことになります。',
    ),
    _q(
      id: 'gt025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac As',
      board: 'Ad 9h 5c 3s 7d',
      street: Street.river,
      potBb: 30,
      stackBb: 70,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。オーバーベットが戦略として成立する条件として、'
          '最も本質的なものはどれですか。',
      choices: [
        '自分のレンジにナッツ有利があり、かつ相手のレンジに払える手が残っていること',
        '自分の手が最強であること',
        'ポットが大きいこと',
        '相手のスタックが深いこと',
      ],
      correctIndex: 0,
      shortReason:
          'ナッツ有利が無ければ、'
          '大きく打っても相手にレイズで返される危険があります。'
          '払える手が残っていなければ、ただ降ろすだけになります。'
          '両方が必要です。',
      gtoView:
          'オーバーベットは、'
          '相手のレンジに上限がある（キャップされている）ときに'
          '最も効果を発揮します。'
          '相手は最強クラスを持てないので、'
          'どのハンドで受けても苦しくなります。',
      practicalView:
          '同じサイズでブラフも用意する必要があります。'
          'オーバーベットが最強クラスだけになると、'
          '見ている相手はすぐ降りるようになります。',
      commonMistake:
          '自分の手が強いことだけを理由に'
          'オーバーベットしてしまうミスです。'
          'レンジ構造の裏付けが無ければ機能しません。',
    ),
    _q(
      id: 'gt026',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kh Kd',
      board: 'Ac Qd 8s',
      potBb: 24,
      stackBb: 76,
      villainProfile: VillainProfile.reg,
      history: [
        'CO raise 2.5BB',
        'BB 3Bet 11BB',
        'CO call',
        'ポット 24BB / 残り 76BB（SPR 約3）',
        'BB bet 12BB',
      ],
      question:
          '6MAX。3Bet ポット（SPR 約3）で KK、A と Q が落ちたボード。'
          '判断の軸として最も適切なのはどれですか。',
      choices: [
        'SPR が浅いので、レイズすればほぼ入り切る。KK は相手のブラフに勝つが Ax には負ける中間の位置なのでコールで受ける',
        'KK は強いのでレイズしてスタックを入れる',
        'A が落ちたので必ずフォールドする',
        'SPR は関係なくハンドの強さだけで決める',
      ],
      correctIndex: 0,
      shortReason:
          '必要勝率は 12 ÷ 48 ＝ 25%。'
          'BB の 3Bet レンジには AK・AQ も AJ・A5s のブラフもあります。'
          'KK は Ax に負けていますが、'
          'ブラフには勝っているのでまだ受けられます。',
      gtoView:
          'SPR が浅いと、レイズは実質オールインの意思表示になります。'
          '中間の強さのハンドは、'
          'その意思表示に見合う強さを持っていません。',
      practicalView:
          'ターンでも打たれ続けたら降りる準備をします。'
          '1 回受けることと、最後まで受けることは別の判断です。',
      commonMistake:
          '「KK は強いから入れる」と'
          'ボードを見ずに決めてしまうミスです。'
          'A と Q が落ちた時点で、KK は 3 番目のペアです。',
    ),
    _q(
      id: 'gt027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kd Qc',
      board: 'Kc 8h 3d 9s',
      street: Street.turn,
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question:
          '6MAX・100BB。ターンで強い手をチェックに混ぜる'
          '（チェックレンジを守る）目的はどれですか。',
      choices: [
        'チェックが弱い手だけになると、相手はチェックを見た瞬間に安全に攻められるから',
        'チェックのほうが期待値が高いから',
        '相手を油断させるため',
        'ポットを小さくしたいから',
      ],
      correctIndex: 0,
      shortReason:
          '強い手を必ず打つ癖がつくと、'
          'チェックしたレンジには弱い手しか残りません。'
          '観察している相手は、そこを狙って攻めてきます。',
      gtoView:
          'どの行動にもある程度の強さを混ぜておくことで、'
          '相手はこちらの行動から情報を得られなくなります。'
          'これがレンジ保護の考え方です。',
      practicalView:
          '相手がこちらのチェックに対してほとんど攻めてこないなら、'
          '保護は不要です。'
          '強い手は毎回打ってバリューを取ります。',
      commonMistake:
          '毎回その場で一番得な行動だけを選び続けるミスです。'
          '短期的には正しくても、'
          '行動と手の強さが結びつくと読まれます。',
    ),
    _q(
      id: 'gt028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah Kh',
      board: '8h 7h 2c',
      potBb: 23,
      stackBb: 78,
      villainProfile: VillainProfile.reg,
      history: [
        'BTN raise 2.5BB',
        'BB（あなた）3Bet 11BB',
        'BTN call',
        'ポット 23BB / 残り 78BB（SPR 約3.4）',
      ],
      question:
          '6MAX。3Bet ポットの 872（ハート 2 枚）で AK ハイ + ナッツフラッシュドロー。'
          'SPR 3.4 での方針はどれですか。',
      choices: [
        'ベットして、レイズされてもスタックを入れる前提で進める',
        'チェックしてポットコントロールする',
        'フォールドする',
        '小さく打って安く進める',
      ],
      correctIndex: 0,
      shortReason:
          'ナッツフラッシュドローは、'
          'コールされても完成すれば最強になります。'
          'SPR 3.4 なら 2 回打てば入り切るので、'
          '入れる前提で進められる強さです。',
      gtoView:
          'SPR が浅いポットでは、'
          '「入れるか降りるか」を早めに決めます。'
          'ナッツドローは、'
          'その基準の上側に入る代表的なハンドです。',
      practicalView:
          '同じ AK でもハートを持っていなければ、'
          'ペアもドローも無いのでチェックが妥当になります。'
          'スート 1 枚で方針が変わります。',
      commonMistake:
          '「ペアが無いから入れられない」と考えるミスです。'
          '完成すれば最強になるドローは、'
          '多くの完成した手より強いエクイティを持ちます。',
    ),
    _q(
      id: 'gt029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Jd Jc',
      board: 'Kh 7d 3c 5s 2h',
      street: Street.river,
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: CO bet → BB call', 'ターン: 両者チェック', 'リバー: BB が 15BB をベット'],
      question:
          '6MAX・100BB。JJ でリバーに打たれました。'
          'ブラフキャッチの判断で最も重要な問いはどれですか。',
      choices: [
        '相手のベットレンジにブラフが何通りあり、バリューが何通りあるか',
        '自分のハンドがどれくらい強いか',
        'ポットが大きいかどうか',
        'これまでにいくら払ったか',
      ],
      correctIndex: 0,
      shortReason:
          '必要勝率は 15 ÷（20 + 15 + 15 ＝ 50）＝ 30%。'
          '相手のベットレンジのうち 30% 以上がブラフなら受けられます。'
          '自分の手の強さは、その比較の材料でしかありません。',
      gtoView:
          'ブラフキャッチは常に'
          '「相手のレンジの構成」と「必要勝率」の比較です。'
          '自分のハンドは、'
          'そのレンジのどこに勝てるかを決めるだけです。',
      practicalView:
          'ターンでチェックが入っているので、'
          '相手のリバーのベットには外したドローが多く含まれます。'
          'JJ は Kx に負けますが、ブラフには勝っています。',
      commonMistake:
          '「JJ は強いから受ける」「JJ は K に負けるから降りる」と'
          '自分の手だけで完結させてしまうミスです。',
    ),
    _q(
      id: 'gt030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ts 9s',
      board: 'Kd 8c 4h 2s 6d',
      street: Street.river,
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX・100BB。3 回目のブラフを打つかどうかを決めるとき、'
          'レンジ全体で確認すべきことはどれですか。',
      choices: [
        'ここまで打ってきたバリューハンドの数に対して、ブラフの数が多すぎないか',
        'ここまでにいくら投資したか',
        'ポットが大きいかどうか',
        '相手のスタックが残っているか',
      ],
      correctIndex: 0,
      shortReason:
          '3 ストリート打ち切るバリューハンドは限られます。'
          'それに対してブラフを打ちすぎると、'
          'レンジ全体がブラフ過多になり、'
          '相手は広く受けるだけで利益が出ます。',
      gtoView:
          'ブラフの本数は、'
          'そのラインで打ち切れるバリューの本数から逆算します。'
          'リバーのポットサイズのベットなら、'
          'バリュー 2 に対してブラフ 1 程度が目安です。',
      practicalView:
          '実戦で正確に数える必要はありませんが、'
          '「3 回打ち切るブラフは、'
          '最も強いドローが外れたものに絞る」と決めておくと'
          '自然にこの比率に近づきます。',
      commonMistake:
          '1 ハンドずつ独立に判断してしまうミスです。'
          'ブラフの是非は、'
          'そのラインを通るレンジ全体の中でしか決まりません。',
    ),
  ];
}
