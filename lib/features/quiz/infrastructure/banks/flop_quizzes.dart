import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// フロップの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class FlopQuizzes {
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
      category: QuizCategory.flop,
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
      id: 'fl001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Qd',
      board: 'Ad 7s 2h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。A72 レインボーのフロップで KQ。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'Fold'],
      correctIndex: 1,
      shortReason:
          'A 高のボードは、レイズした側のレンジに大きく味方します。'
          'AK・AQ・AJ を持っているのはこちらばかりで、'
          'BB のコールレンジには A がほとんど入っていません。',
      gtoView:
          'こうした「自分のレンジ全体が相手より強い」ボードでは、'
          '手札の強さに関係なく、小さいサイズで広く打つのが基本形になります。'
          '相手は A を持っていない限り、どこで受けても苦しくなります。',
      practicalView:
          '相手が小さいベットに何でもコールしてくるタイプなら、'
          'KQ のような何もできていない手でのベットは減らします。',
      commonMistake:
          '「自分がペアになっていないから打てない」と考えるミスです。'
          'ベットするかどうかは、'
          '自分のレンジと相手のレンジのどちらがそのボードに当たるかで決めます。',
    ),
    _q(
      id: 'fl002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '7d 2c',
      board: 'Kh Js 4d',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 33%（1.8BB）'],
      question: '6MAX・100BB。KJ4 のフロップで 72o。何も当たっていません。どうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          'ペアもドローもなく、勝つ道が「相手が降りる」以外にありません。'
          '72 は次のカードで何かになる可能性も最低クラスです。',
      gtoView:
          'ベットに対して続けるハンドは、'
          '「今勝っている」か「これから勝てる形になる」かのどちらかです。'
          '72 はそのどちらにも当てはまりません。',
      practicalView:
          '同じ何も無い手でも、'
          'ボードと同じスートを 2 枚持っているなど将来性があれば話は変わります。'
          'まったく将来性が無い手から降りていくのが、正しい降り方です。',
      commonMistake:
          '「安いから」と 1.8BB を払ってしまうミスです。'
          '1 回は安くても、この後ターン・リバーでも払わされます。',
    ),
    _q(
      id: 'fl003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Kd',
      board: 'Kc 7s 2h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。K72 のフロップで AK。トップペア・トップキッカーです。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          'K を持っていて、しかもキッカーが最強です。'
          '相手の K7・K5s・77 などから払ってもらえるうちに、'
          'ポットを大きくしておきます。',
      gtoView:
          'A 高でも K 高でも、高いカードのボードはレイズした側に有利です。'
          'その上でトップペアを持っているので、'
          'レンジ全体の強さと手札の強さが両方そろっています。',
      practicalView:
          '相手が降りやすいタイプなら、'
          '同じ AK でも打つ回数を減らしてターンから取りにいく調整もあります。'
          'ただし基本は打っておいて損のないハンドです。',
      commonMistake:
          '「強いから相手に打たせよう」とチェックしてしまうミスです。'
          'K7 や 77 のような、払ってくれる手は次のカードで簡単に降りてしまいます。',
    ),
    _q(
      id: 'fl004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '7c 7d',
      board: '9h 7h 2c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。9h 7h 2c のフロップでセット（777）。どうしますか。',
      choices: ['Check（ゆっくり進める）', 'Bet', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          'セットは今ほぼ最強ですが、ボードにハートが 2 枚あります。'
          'フラッシュやストレートに逆転される前に、'
          'ドローから払わせてポットを大きくします。',
      gtoView:
          '「今強い」ハンドの価値は、'
          '相手が逆転できるカードの枚数で目減りします。'
          '逆転の余地が大きいボードほど、早く大きく打つ理由が増えます。',
      practicalView:
          '乾いたボード（例えば K72 レインボー）なら、'
          '同じセットでもチェックして相手に打たせる選択が生きます。'
          'ボードが濡れているかどうかで扱いが変わります。',
      commonMistake:
          '「最強なんだから隠したい」とチェックしてしまうミスです。'
          'このボードでは、ただでハートを 1 枚めくらせているだけになります。',
    ),
    _q(
      id: 'fl005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qh Jh',
      board: 'Th 9c 3d',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 33%（1.8BB）'],
      question: '6MAX・100BB。QJ で T93 のフロップ。オープンエンドのストレートドローです。どうしますか。',
      choices: ['Fold', 'Call', '降りて次に備える', 'ペアが無いので Fold'],
      correctIndex: 1,
      shortReason:
          'K と 8 の 8 枚でストレートが完成します。'
          '必要勝率は 1.8 ÷（5.5 + 1.8 + 1.8）＝ 約20% で、'
          '8 アウツはそれを十分に上回ります。',
      gtoView:
          'ペアが無くても、完成すれば勝てる形があるハンドは続行できます。'
          '判断材料は「今の強さ」ではなく「値段と、これから勝てる確率」です。',
      practicalView:
          'QJ はオーバーカードも持っているので、'
          'Q や J でペアになって勝てる回もあります。'
          '見えている 8 アウツより実際は少し強いハンドです。',
      commonMistake:
          '「ペアが無いから降りる」と反射的に判断してしまうミスです。'
          'ドローの枚数を数えてから決めてください。',
    ),
    _q(
      id: 'fl006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Jd Ts',
      board: '9h 8c 2d',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。JT で 982 のフロップ。オープンエンドです。BB のチェックにどうしますか。',
      choices: ['Check（無料でカードを見る）', 'Bet', 'Fold', '何もできないので Check'],
      correctIndex: 1,
      shortReason:
          '打てば相手が降りることもあり、'
          'コールされても Q か 7 でストレートが完成します。'
          '「降ろせて良し、当たっても良し」の二段構えです。',
      gtoView:
          'これがセミブラフです。'
          'ブラフの成功（相手が降りる）と、'
          '失敗したときの保険（ドローの完成）を両方持っています。',
      practicalView:
          '相手がほとんど降りないタイプなら、'
          'ベットの目的は「降ろす」から'
          '「完成したときに大きなポットを作っておく」に変わります。'
          'どちらにしても打つ理由はあります。',
      commonMistake:
          '「無料でカードを見たい」とチェックしてしまうミスです。'
          'チェックすると、相手が降りてくれる回のポットをすべて捨てることになります。',
    ),
    _q(
      id: 'fl007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Kd 9d',
      board: 'Kc 7s 2h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 33%（1.8BB）'],
      question: '6MAX・100BB。K72 のフロップで K9s。トップペアです。BTN の小さいベットにどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          'トップペアは降りるには強すぎます。'
          '一方でレイズすると、勝っている相手（ブラフ）は降り、'
          '負けている相手（AK・KQ）だけが残ります。'
          'コールして相手のブラフを残すのが最も得です。',
      gtoView:
          'レイズには「弱い手を降ろす」効果と'
          '「強い手から払わせる」効果があります。'
          'K9 はどちらも狙いにくい、中間の強さのハンドです。',
      practicalView:
          '相手が小さいベットをブラフばかりで打つタイプなら、'
          'コールして次も受けるのが正解になります。'
          '逆にほとんどブラフしない相手なら、降りる回も出てきます。',
      commonMistake:
          '「トップペアだからレイズして守る」と考えるミスです。'
          'レイズして残るのは、こちらが負けているハンドばかりです。',
    ),
    _q(
      id: 'fl008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '9s 8s',
      board: 'Kd 9c 4h',
      potBb: 8.5,
      villainProfile: VillainProfile.reg,
      history: [
        'BTN raise 2.5BB',
        'SB call',
        'BB（あなた）call',
        '3 人でフロップへ',
        'SB check',
      ],
      question: '6MAX・100BB。3 人のポットで K94 のフロップ。98s のミドルペアでどうしますか。',
      choices: ['Check', 'Bet 50%', 'Bet 100%', 'All-in'],
      correctIndex: 0,
      shortReason:
          '3 人いると、誰か 1 人が K を持っている確率が大きく上がります。'
          'ミドルペアで打っても、降りるのは自分より弱い手ばかりです。',
      gtoView:
          '人数が増えるほど、'
          '「レンジ全体で見て自分が勝っている」状態は成立しにくくなります。'
          '結果として、ブラフも薄いバリューベットも減らすのが基本になります。',
      practicalView:
          '2 人だけなら同じ 98s で打てる場面です。'
          '「多人数ではベット頻度を落とす」と覚えておくと大きく外しません。',
      commonMistake:
          '2 人のときと同じ感覚で打ってしまうミスです。'
          '多人数のポットは、相手が 1 人増えるごとに慎重さが必要になります。',
    ),
    _q(
      id: 'fl009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.utg,
      villain: Position.bb,
      heroCards: 'Ac Kd',
      board: '7h 6h 5s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。UTG でオープンし、765 のフロップ。AK ハイでどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          '765 は BB のコールレンジ（87s・65s・77・66・55 など）に強く当たり、'
          'UTG のタイトなレンジにはほとんど当たりません。'
          '相手のほうが強いボードでは、無理に打たずポットを小さく保ちます。',
      gtoView:
          'ボードが相手のレンジに味方するとき、'
          'レンジ全体のベット頻度は大きく下がります。'
          '「レンジ vs レンジ」で考える典型例です。',
      practicalView:
          '相手がチェックに対してほとんど打ってこない受け身なタイプなら、'
          '無料でターンを見る価値がさらに上がります。',
      commonMistake:
          '「オープンしたから毎回コンティニュエーションベット」というミスです。'
          '自分のレンジが当たらないボードでは、打つほど損をします。',
      relatedRangeSpotId: '6max_utg_open',
    ),
    _q(
      id: 'fl010',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.co,
      heroCards: 'Jc Th',
      board: '9d 7s 2c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check', 'CO bet 75%（4BB）'],
      question: '6MAX・100BB。JT で 972 のフロップ。ガットショットだけです。大きいベットにどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 4 ÷（5.5 + 4 + 4 ＝ 13.5）＝ 約30%。'
          'ガットショット 4 アウツでは、2 枚見られても約17% しかありません。',
      gtoView:
          '大きいベットは、そのぶん高い勝率を要求します。'
          '同じ 4 アウツでも、小さいベットには受けられて'
          '大きいベットには受けられなくなります。',
      practicalView:
          'J と T のオーバーカードで勝てる回も少しはありますが、'
          '相手が 75% も打っているレンジには 9x が多く、'
          'ペアになっても勝ち切れないことが多い状況です。',
      commonMistake:
          '「ドローがあるから」とサイズを見ずにコールするミスです。'
          '必要勝率はベットサイズで変わります。',
    ),
    _q(
      id: 'fl011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Qs',
      board: 'Kd Qc 7h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。KQ7 のフロップで KQ のツーペア。どうしますか。',
      choices: ['Check', 'Bet', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          'トップツーペアで、今はほぼ最強です。'
          'JT のストレートドローや Kx・Qx から'
          '払ってもらえるうちにポットを大きくします。',
      gtoView:
          '強いハンドを持っているときは、'
          '「相手が払える一番大きい額」を 3 ストリートかけて積み上げるのが目標です。'
          'フロップでチェックすると、その積み上げが 1 段減ります。',
      practicalView:
          '相手が受け身でほとんど打ってこないタイプなら、'
          'チェックして待つのは特に損です。'
          '自分から打たないとポットが育ちません。',
      commonMistake:
          '「強いから逃したくない」と隠してしまうミスです。'
          'JT や AJ のようなドローは、ターン以降で完成するか降りるかのどちらかになり、'
          'いま払ってもらう機会を逃します。',
    ),
    _q(
      id: 'fl012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '2c 2d',
      board: 'Ks Qs Jh',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。KQJ のフロップで 22。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'All-in'],
      correctIndex: 0,
      shortReason:
          'KQJ は BB のコールレンジに何重にも当たるボードです。'
          '22 は相手の何にも勝てず、'
          '打っても降りるのは 22 より弱い手（＝ほとんど無い）だけです。',
      gtoView:
          'ブラフが成立するのは「降ろしたい相手のハンド」が存在するときです。'
          'このボードで BB が降りるハンドはほとんど残っておらず、'
          'ベットは目的を持てません。',
      practicalView:
          'チェックすれば、リバーまで進んで相手も何も無い場合に'
          '22 のまま勝てる回があります。'
          'わずかですが、ベットで捨てるよりは価値があります。',
      commonMistake:
          '「ペアがあるから守らないと」と打ってしまうミスです。'
          '守る価値があるのは、相手が降りるハンドを持っているときだけです。',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'fl013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '9h 8h',
      board: '7h 6c 2h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 33%（1.8BB）'],
      question: '6MAX・100BB。98s で 762（ハート 2 枚）のフロップ。15 アウツのコンボドローです。どうしますか。',
      choices: ['Fold', 'Call', 'Check-Raise', 'All-in'],
      correctIndex: 2,
      shortReason:
          'フラッシュ 9 枚 + ストレート 6 枚（重複を除く）で 15 アウツ。'
          '2 枚見られれば 5 割を超えます。'
          'コールされても五分以上、降ろせればそのまま勝ちです。',
      gtoView:
          'チェックレイズには「相手のレンジを狭める」効果があります。'
          'エクイティが高いドローをここに置くと、'
          '降ろせなかった回も損になりません。',
      practicalView:
          '相手が小さいベットにレイズされると簡単に降りるタイプなら、'
          'このレイズの価値はさらに上がります。'
          '逆にほとんど降りない相手なら、'
          'ポットを大きくする目的だけのレイズになります。',
      commonMistake:
          '一番強いドローをコールで受けてしまうミスです。'
          'コールだけで進めると、相手にターンのカードを安く見せたうえ、'
          '主導権も渡したままになります。',
    ),
    _q(
      id: 'fl014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Kh',
      board: '8s 7s 6d',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。876 のフロップで AK ハイ。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          '876 は BB のコールレンジ（98・T9・65・87・77・66 など）を直撃します。'
          'AK はペアもストレートドローも無く、'
          '打っても降りてくれる相手がほとんどいません。',
      gtoView:
          '「BTN だからレンジが広くて有利」は、'
          '高いカードのボードでの話です。'
          '低くつながったボードでは、'
          'BB のコールレンジのほうが完成形を多く含みます。',
      practicalView:
          'AK はチェックしても A や K でペアになれば十分戦えます。'
          '安くターンを見て、良いカードが落ちたら打ち直す方針が合っています。',
      commonMistake:
          '「BTN でレイズしたから打つ」と自動化してしまうミスです。'
          'ボードによって、レンジの有利不利は入れ替わります。',
    ),
    _q(
      id: 'fl015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ad Jc',
      board: 'Kc 7s 2h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: [
        'BTN raise 2.5BB',
        'BB call',
        'BB check',
        'BTN bet 33%（1.8BB）',
        'BB check-raise to 6BB',
      ],
      question: '6MAX・100BB。K72 でベットしたらチェックレイズされました。AJ ハイでどうしますか。',
      choices: ['Fold', 'Call', 'Re-raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          'ペアもドローも無く、A のオーバーカード 3 枚しかありません。'
          'チェックレイズしてくるレンジには Kx とセットが多く、'
          'A が落ちても勝てるとは限りません。',
      gtoView:
          'チェックレイズを受けたときに残すべきなのは、'
          'ある程度の勝率か、'
          '相手の強い手を減らすブロッカーを持つハンドです。'
          'AJ は K をブロックしていません。',
      practicalView:
          '相手がチェックレイズをブラフで多用するタイプなら、'
          'A ハイでも受ける回が出てきます。'
          'ただし乾いたボードでのチェックレイズは、'
          '一般に強いレンジで打たれます。',
      commonMistake:
          '「A が高いから」と粘ってしまうミスです。'
          'A ハイに価値が出るのはショーダウンまで安く進めたときで、'
          '大きいポットで守るハンドではありません。',
    ),
    _q(
      id: 'fl016',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Qc Qd',
      board: 'Jh Ts 4h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。JT4（ハート 2 枚）のフロップで QQ。どうしますか。',
      choices: ['Check', 'Bet', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          'QQ は今は勝っていますが、'
          'ハートのフラッシュドロー、K・9 のストレートドロー、'
          'J や T でのペアなど、逆転される道が非常に多いボードです。'
          '打って払わせ、同時に降ろします。',
      gtoView:
          'ベットには「バリューを取る」と「相手のエクイティを消す」'
          '2 つの役割があります。'
          '逆転の余地が大きいボードほど、後者の価値が大きくなります。',
      practicalView:
          '同じ QQ でも、K72 レインボーのような乾いたボードなら'
          'チェックして相手のブラフを残す選択が生きます。'
          'ボードの濡れ具合で扱いを変えます。',
      commonMistake:
          '「オーバーペアだから安泰」とチェックしてしまうミスです。'
          'このボードは、ターンの半分近くのカードが'
          'こちらにとって嬉しくないカードです。',
    ),
    _q(
      id: 'fl017',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac 5d',
      board: 'Kd Kh 4s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。KK4 のペアボードで A5o。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'All-in'],
      correctIndex: 1,
      shortReason:
          'K が 2 枚見えているので、'
          'どちらのレンジにも K はほとんど残っていません。'
          '相手はペアの無いハンドばかりで、小さいベットで広く降ろせます。',
      gtoView:
          'ボードがペアになると、'
          '両者ともに強い完成形を作りにくくなります。'
          'その状態では、レンジ有利のある側が'
          '小さいサイズで押し続けるのが基本になります。',
      practicalView:
          'A5 は A ハイのショーダウンバリューも持っています。'
          '相手がコールしすぎるタイプなら、'
          'チェックして A ハイのまま勝ちにいく選択も出てきます。',
      commonMistake:
          '「ペアボードは危ないから避ける」と考えるミスです。'
          '危ないのは相手が K を持っているときだけで、'
          'その組み合わせは 2 枚しか残っていません。',
    ),
    _q(
      id: 'fl018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.utg,
      villain: Position.bb,
      heroCards: 'Ah Ad',
      board: 'Qs Jd 9h',
      potBb: 11,
      villainProfile: VillainProfile.reg,
      history: [
        'UTG（あなた）raise 2.5BB',
        'HJ call',
        'BTN call',
        'BB call',
        '4 人でフロップへ',
      ],
      question: '6MAX・100BB。4 人のポットで QJ9 のフロップ。AA でどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          'QJ9 は KT のストレート、QJ・J9 のツーペア、'
          'KQ・KJ のドローなど、当たり方が非常に多いボードです。'
          '相手が 3 人いると、そのうち誰かが当たっている確率は高くなります。',
      gtoView:
          '多人数のポットでは「レンジ全体で勝っている」状態が作りにくく、'
          'ベット頻度は大きく下がります。'
          'AA という強さも、相手が 3 人なら相対的な価値が落ちます。',
      practicalView:
          '同じ AA でも、1 対 1 なら迷わず打つ場面です。'
          'チェックして安くターンを見れば、'
          '危険なカードが落ちたときに降りる余地も残せます。',
      commonMistake:
          '「AA は最強だから常に打つ」と考えるミスです。'
          'プリフロップの最強ハンドは、'
          'フロップが開いた瞬間に順位が入れ替わります。',
    ),
    _q(
      id: 'fl019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '6h 5h',
      board: 'Kd 9h 3c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。K93 のフロップで 65s。何も当たっていませんがどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'Fold'],
      correctIndex: 1,
      shortReason:
          'K 高のボードはこちらのレンジに有利です。'
          'さらに 65s はハートをもう 1 枚引けばフラッシュドローになり、'
          '7 か 8 が来ればストレートドローにもなります。'
          '次で強くなれるので、打ち続ける材料があります。',
      gtoView:
          'ブラフに選ぶハンドは「今は何も無い」中でも、'
          'バックドア（あと 2 枚で完成する形）を持つものを優先します。'
          'ターンで強くなれば、そのまま打ち続けられるからです。',
      practicalView:
          'まったくバックドアの無い 72o のようなハンドは、'
          '同じ「何も無い」でもブラフに向きません。'
          'ターンで打ち続ける理由が生まれないためです。',
      commonMistake:
          '何も無いハンドをすべて同じ扱いにしてしまうミスです。'
          'バックドアの有無で、その後の進めやすさがまったく変わります。',
    ),
    _q(
      id: 'fl020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'As Kd',
      board: '7h 6s 5c',
      potBb: 5.5,
      villainProfile: VillainProfile.nit,
      history: [
        'BTN raise 2.5BB',
        'BB（タイト・パッシブ）call',
        'BB が自分から 4BB をベット（ドンクベット）',
      ],
      question: '6MAX・100BB。765 のフロップで、受け身なはずの BB が自分から打ってきました。AK でどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          '普段打ってこない相手が自分から打つのは、'
          'それだけ強い形ができたときです。'
          '765 で作れる形（ストレート・ツーペア・セット）に対し、'
          'AK は何も持っていません。',
      gtoView:
          '相手の行動が普段と違うときは、'
          'その行動を取るレンジが極端に狭いという情報になります。'
          '受け身な相手のリードは、特に強いレンジに偏ります。',
      practicalView:
          '同じドンクベットでも、'
          '相手がルース・アグレッシブなら意味がまったく変わり、'
          'ブラフの割合が高くなるので受ける余地が出ます。'
          '相手のタイプが答えを決めるスポットです。',
      commonMistake:
          '「AK だから」と手の名前で判断してしまうミスです。'
          'このボードで AK が持っているのはオーバーカードだけで、'
          '相手のレンジにはほとんど勝てません。',
    ),
    _q(
      id: 'fl021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ah Kc',
      board: 'Kd 7s 2h',
      potBb: 24,
      stackBb: 76,
      villainProfile: VillainProfile.reg,
      history: [
        'CO raise 2.5BB',
        'BB 3Bet 11BB',
        'CO call',
        'ポット 24BB / 残りスタック 76BB（SPR 約3）',
        'BB check',
      ],
      question: '6MAX。3Bet ポット（SPR 約3）の K72 フロップで AK。方針として正しいのはどれですか。',
      choices: [
        'ポットを小さく保ち、ショーダウンを目指す',
        'ベットして、レイズされてもスタックを入れる前提で進める',
        'チェックして相手のブラフだけを取る',
        'トップペアなので 1 回だけ打って以降は降りる',
      ],
      correctIndex: 1,
      shortReason:
          'SPR が約 3 しかないので、'
          '2 回ベットすればほぼスタックが入ります。'
          'トップペア・トップキッカーは、この深さでは十分に強い手です。',
      gtoView:
          '同じ AK でも、SPR 10 の場面では慎重に扱い、'
          'SPR 3 では最後まで戦うハンドになります。'
          'ハンドの価値は、残りスタックとポットの比で決まります。',
      practicalView:
          '3Bet ポットではプリフロップですでに大きく積んでいるため、'
          'フロップ以降の選択肢が少なくなります。'
          '「入れるか降りるか」を早めに決めておくと迷いません。',
      commonMistake:
          'SPR を見ずに、100BB の感覚のままポットコントロールしてしまうミスです。'
          '浅いポットで慎重になりすぎると、'
          '一番勝っている場面で取り切れません。',
    ),
    _q(
      id: 'fl022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '9c 9d',
      board: '8h 5c 2d',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。852 のフロップで 99。オーバーペアです。どうしますか。',
      choices: ['Check', 'Bet', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          '99 は今おそらく勝っていますが、'
          'T から A までの 20 枚は、相手にペアを作らせる可能性のあるカードです。'
          '打つことで、そうしたハンドをいま降ろせます。',
      gtoView:
          '「今勝っているが、逆転されうるカードが多い」ハンドは、'
          'ベットして相手のエクイティを消すのが基本です。'
          'これをエクイティ・デナイアル（勝つ権利を奪う）と呼びます。',
      practicalView:
          'BB のコールレンジには AJo や KTo のような'
          'オーバーカードのハンドが多く含まれます。'
          '打てばこれらの多くを降ろせます。',
      commonMistake:
          '「相手に打たせて釣ろう」とチェックしてしまうミスです。'
          'チェックすると、A や K が落ちて相手が逆転する回を'
          'そのまま与えることになります。',
    ),
    _q(
      id: 'fl023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'As 5s',
      board: 'Ah 8c 3d',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 33%（1.8BB）'],
      question: '6MAX・100BB。A83 のフロップで A5s のトップペア。小さいベットにどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          'レイズすると、相手のブラフはすべて降り、'
          '残るのは AK・AQ・AJ など、キッカーで負けているハンドばかりになります。'
          'コールして相手にブラフを続けさせるほうが得です。',
      gtoView:
          'キッカーの弱いトップペアは「ブラフキャッチャー」として扱います。'
          '相手が弱い手で打ち続けてくれることが利益の源で、'
          'レイズはその源を自分で断つ動きです。',
      practicalView:
          '相手がフロップで打った後、'
          'ターン・リバーでもブラフを続けるタイプなら、'
          'コールで受け続ける価値が高くなります。',
      commonMistake:
          '「トップペアだからレイズして情報を取る」と考えるミスです。'
          '得られる情報より、失うバリューのほうがはるかに大きくなります。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'fl024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kh Qd',
      board: 'Kc 7s 2h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: [
        'BTN raise 2.5BB',
        'BB call',
        'BB check',
        'BTN bet 33%（1.8BB）',
        'BB check-raise to 6BB',
      ],
      question: '6MAX・100BB。K72 でベットしたらチェックレイズ。KQ のトップペアでどうしますか。',
      choices: ['Fold', 'Call', 'Re-raise to 16BB', 'All-in'],
      correctIndex: 1,
      shortReason:
          'チェックレイズのレンジにはブラフも含まれるため、'
          'トップペア・グッドキッカーは降りるには強すぎます。'
          '一方で再レイズすると、'
          'ブラフは降りて KK・77・22 など負けている手だけが残ります。',
      gtoView:
          '再レイズは「相手の強い部分だけを残す」動きです。'
          'KQ はチェックレイズレンジの上位には勝てず、'
          '下位（ブラフ）には勝っている中間の強さなので、'
          'コールがちょうど噛み合います。',
      practicalView:
          '相手がチェックレイズをほとんどブラフでしないタイプなら、'
          'KQ でも降りる判断が出てきます。'
          'チェックレイズのブラフ頻度が、この判断を左右します。',
      commonMistake:
          '「はっきりさせたい」と再レイズしてしまうミスです。'
          'はっきりしたときには、たいてい負けが確定しています。',
    ),
    _q(
      id: 'fl025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah 3h',
      board: 'Kh Qh 4c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 33%（1.8BB）'],
      question: '6MAX・100BB。KQ4（ハート 2 枚）で Ah3h のナッツフラッシュドロー。どうしますか。',
      choices: ['Fold', 'Call', 'Check-Raise', 'All-in'],
      correctIndex: 2,
      shortReason:
          'Ah を持っているので、相手がナッツフラッシュドローを持つ可能性を消しています。'
          '完成すれば必ず最強、しかも相手は上のフラッシュを持てません。'
          '安心して大きなポットを作りにいけます。',
      gtoView:
          'レイズのブラフに選ぶのは「降ろせなかったときに困らない」ハンドです。'
          'ナッツフラッシュドローは、'
          '再レイズされてもエクイティで戦えるため、最も適した候補になります。',
      practicalView:
          '同じフラッシュドローでも 5h4h なら話は別です。'
          '完成しても上のフラッシュに負ける可能性が残るため、'
          'レイズして大きなポットを作るのはリスクが高くなります。',
      commonMistake:
          'フラッシュドローをすべて同じ強さとして扱うミスです。'
          'ナッツかどうかで、レイズしてよいかどうかが変わります。',
    ),
    _q(
      id: 'fl026',
      difficulty: QuizDifficulty.advanced,
      hero: Position.utg,
      villain: Position.bb,
      heroCards: 'Ac Qs',
      board: 'Ad 7h 2c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。A72 レインボーでレンジ有利があります。戦略として優れているのはどちらですか。',
      choices: [
        'レンジ全体を 33% の小さいサイズで高頻度に打つ',
        '強い手だけを 75% で打ち、弱い手はチェックする',
        'すべてチェックしてターンから打つ',
        'すべて 100% のサイズで打つ',
      ],
      correctIndex: 0,
      shortReason:
          'A72 は相手がほとんど当たらない乾いたボードです。'
          '強い手だけ打つと、相手は「打たれた＝強い」と分かり、'
          '簡単に降りられてしまいます。',
      gtoView:
          '小さいサイズなら、弱い手で打っても損が小さく済みます。'
          'その結果、強い手と弱い手を同じサイズに混ぜられ、'
          '相手はどちらか判別できなくなります。',
      practicalView:
          '相手が「小さいベットには何でもコールする」タイプなら、'
          'このやり方は機能しません。'
          'その場合は弱い手でのベットを減らし、'
          '強い手だけサイズを上げる形に切り替えます。',
      commonMistake:
          '自分の手の強さでサイズを変えてしまうミスです。'
          '強いときだけ大きく打つ癖は、相手に手札を教えているのと同じです。',
    ),
    _q(
      id: 'fl027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ad Ks',
      board: '4c 4d 9s',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。449 のペアボードで AK ハイ。BB のチェックにどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 1,
      shortReason:
          '4 も 9 も、BB のコールレンジにわずかしか入っていません。'
          '相手の大半はペアの無いハンドで、'
          '小さいベットで広く降ろせます。'
          'コールされても A・K の 6 アウツが残ります。',
      gtoView:
          '低いペアボードは、'
          'どちらのレンジも完成形を作りにくい構造です。'
          'この状態では、高いカードを多く持つ側'
          '（＝レイズした側）が押し続ける形になります。',
      practicalView:
          '相手が「ペアボードでは降りない」と決めているタイプなら、'
          'ブラフの本数を減らします。'
          'ただしその場合も、AK は 6 アウツを持つので打つ理由が残ります。',
      commonMistake:
          '「A も K もペアになっていないから打てない」と考えるミスです。'
          '相手も同じくらい当たっていないことが、ベットの根拠になります。',
    ),
    _q(
      id: 'fl028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah Kd',
      board: '8h 7h 2c',
      potBb: 23,
      stackBb: 78,
      villainProfile: VillainProfile.reg,
      history: [
        'BTN raise 2.5BB',
        'BB（あなた）3Bet 11BB',
        'BTN call',
        'ポット 23BB / 残りスタック 78BB（SPR 約3.4）',
      ],
      question: '6MAX。3Bet ポットの 872（ハート 2 枚）フロップで AK ハイ。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          '872 は BTN のコールレンジ（98s・87s・77・88・22・ハートのドロー）に'
          'よく当たります。'
          'AK はペアもドローも無く、SPR が浅いので'
          '打ってレイズされると降りるしかありません。',
      gtoView:
          '3Bet ポットは SPR が浅いぶん、'
          'ブラフを始めると引き返しにくくなります。'
          '「打った後にレイズされたらどうするか」を'
          '決められない手では、打たないほうが安全です。',
      practicalView:
          'チェックすれば、A や K が落ちたターンから'
          '打ち直すことができます。'
          '3Bet した側のレンジは強いので、'
          'チェックしても相手は無条件で攻めてはこられません。',
      commonMistake:
          '「3Bet したから打たないと弱く見える」と考えるミスです。'
          '3Bet ポットで一度打つと、'
          'その後の 2 回でスタックが入る構造になっています。',
    ),
    _q(
      id: 'fl029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qc Jd',
      board: 'Ah Kd 7c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。AK7 のフロップで QJ。ブラフとして優れている理由はどれですか。',
      choices: [
        'Q と J でペアになれば勝てるから',
        'T でナッツストレートになり、同時に相手の AQ・KQ・AJ・KJ を減らすから',
        'ハートのフラッシュドローがあるから',
        'A も K も持っていないから',
      ],
      correctIndex: 1,
      shortReason:
          'T が落ちれば AKQJT でナッツになります。'
          'さらに Q と J を持っていることで、'
          '相手が持ちうる AQ・KQ・AJ・KJ の組み合わせを減らしています。',
      gtoView:
          'ブラフの質は「ドローの強さ」と「ブロッカー」の両方で決まります。'
          'QJ はガットショットに加え、'
          '相手の続行レンジを直接減らすという二重の役割を持ちます。',
      practicalView:
          'Q や J でペアになっても、'
          'A・K のボードでは勝ちにつながりにくい点には注意してください。'
          'このハンドの価値は T のストレートとブロッカーにあります。',
      commonMistake:
          'ブロッカーを無視して、'
          'ドローの枚数だけでブラフを選んでしまうミスです。'
          '同じ 4 アウツでも、相手の強い手を減らせるかどうかで価値が変わります。',
    ),
    _q(
      id: 'fl030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.utg,
      villain: Position.bb,
      heroCards: 'Ac Ad',
      board: 'Jh Th 9c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。JT9（ハート 2 枚）のフロップで AA。UTG のあなたはどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          'JT9 は BB のコールレンジを何重にも直撃します。'
          'すでに QJ・JT・T9・98 のストレートやツーペアが完成しており、'
          'AA は「今は勝っているかもしれないが、ほとんどのカードで悪くなる」状態です。',
      gtoView:
          'オーバーペアの価値は、'
          'ボードがどれだけ相手のレンジに当たるかで決まります。'
          'ここでは AA が実質ブラフキャッチャーに近く、'
          'ポットを大きくしても得をしません。',
      practicalView:
          'チェックすれば、'
          '安全なターン（ペアにならない低いカード）が落ちたときに打ち直せます。'
          '不利なポジションで大きなポットを作らないことが優先です。',
      commonMistake:
          '「AA を折るのはもったいない」とポットを膨らませてしまうミスです。'
          'このボードでスタックが入る展開は、'
          'ほとんどの場合こちらが負けています。',
      relatedRangeSpotId: '6max_utg_open',
    ),
  ];
}
