import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// ベットサイズの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class BetSizingQuizzes {
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
      category: QuizCategory.betSizing,
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
      id: 'bs001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Kd',
      board: 'Qs 7d 2c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question: '6MAX・100BB。Q72 レインボーで AK ハイ。最も適したベットサイズはどれですか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 1,
      shortReason:
          'Q72 レインボーは相手が当たりづらい乾いたボードで、'
          'こちらのレンジが有利です。'
          '小さいサイズなら、安く広くプレッシャーをかけられます。',
      gtoView:
          '乾いたボードでレンジ有利のある側は、'
          '小さいサイズを高頻度で使うのが基本形です。'
          '小さければ、弱い手で打っても損が小さく済みます。',
      practicalView:
          '相手が小さいベットに何でもコールしてくるタイプなら、'
          '弱いハンドでのベットを減らし、'
          '強いハンドでサイズを上げる調整が有効です。',
      commonMistake:
          'AK のような「強いけどまだ何もできていない」ハンドで'
          '大きく打ってしまうミスです。'
          '大きく打つと、降りてほしくない弱い手まで降ろしてしまいます。',
    ),
    _q(
      id: 'bs002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Jh Jc',
      board: '9h 8h 5c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。985（ハート 2 枚）で JJ のオーバーペア。'
          'ドローから守ることを重視した場合、適したサイズはどれですか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'Fold'],
      correctIndex: 2,
      shortReason:
          '985 ツートーンはストレートもフラッシュも狙える濡れたボードです。'
          'JJ は今強いので、'
          'ドローに安くカードを与えないよう大きめに打ちます。',
      gtoView:
          'ドローが多いボードでは、'
          'バリューハンドのベットサイズが大きくなります。'
          '相手が持っている「これから勝つ権利」を、'
          '安く実現させないことが目的です。',
      practicalView:
          '相手がドローを追いかけがちなタイプなら、'
          'さらに大きく打って問題ありません。'
          '逆にタイトすぎる相手なら、'
          '降ろしすぎないようサイズを落とします。',
      commonMistake:
          '「オーバーペアだからゆっくり」とチェックしてしまうミスです。'
          'このボードはターンで簡単に逆転されます。',
    ),
    _q(
      id: 'bs003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kc Kh',
      board: 'Kd 8s 3c 5h 2d',
      street: Street.river,
      potBb: 30,
      stackBb: 60,
      villainProfile: VillainProfile.station,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question: '6MAX。コーリングステーション相手にセット（KKK）。リバーのサイズはどれが適していますか。',
      choices: ['Check', 'Bet 25%', 'Bet 50%', 'Bet 100%以上'],
      correctIndex: 3,
      shortReason:
          'めったに降りない相手には、'
          '一番大きいサイズで打つのが最も利益になります。'
          '降りない相手のコール範囲は、'
          'サイズを上げてもほとんど狭まりません。',
      gtoView:
          'バリューベットのサイズは'
          '「相手がコールできる最大額」で決めます。'
          '相手がサイズを気にしないなら、'
          'その最大額は非常に大きくなります。',
      practicalView:
          'これがエクスプロイトの基本形です。'
          '相手の弱点（降りられない）に対して、'
          'サイズを上げるだけで利益が増えます。',
      commonMistake:
          '「大きく打つと降りられる」と'
          '相手を見ずに小さくしてしまうミスです。'
          '降りない相手からは、'
          '打った額だけそのまま利益になります。',
    ),
    _q(
      id: 'bs004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Kc',
      street: Street.preflop,
      potBb: 1.5,
      villainProfile: VillainProfile.reg,
      history: ['UTG・HJ ともにフォールド。CO のあなたの番'],
      question: '6MAX・100BB。オンラインのキャッシュゲームで、標準的なオープンレイズのサイズはどれですか。',
      choices: ['1.1BB', '2〜2.5BB', '6BB', '15BB'],
      correctIndex: 1,
      shortReason:
          '狙いはブラインドの 1.5BB を取ることです。'
          '2〜2.5BB は「相手に良いオッズを与えず、'
          '外したときの損も小さい」バランスの取れたサイズです。',
      gtoView:
          'ベットサイズは常に「リスクとリターンの比」で決まります。'
          '15BB 払って 1.5BB を取りにいくのは、'
          '成功しても増えず、失敗したときの損だけが大きい形です。',
      practicalView:
          'ライブポーカーでは、'
          'コールしやすい相手が多いため 3〜4BB が標準になります。'
          '環境によって適正サイズは変わります。',
      commonMistake:
          'ミニレイズにしてしまうミスです。'
          '安すぎるとブラインドがほぼ全ハンドでコールでき、'
          'レイズでレンジを狭めるという目的が消えます。',
    ),
    _q(
      id: 'bs005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qd Qh',
      street: Street.preflop,
      potBb: 4,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'SB fold'],
      question: '6MAX・100BB。BTN の 2.5BB オープンに QQ で 3Bet します。適したサイズはどれですか。',
      choices: ['3.5BB', '5BB', '11BB', '40BB'],
      correctIndex: 2,
      shortReason:
          '不利なポジションからの 3Bet は、'
          'オープン額の 4 倍以上（10〜12BB）が目安です。'
          '小さすぎると BTN が良いオッズとポジションの両方を得てしまいます。',
      gtoView:
          '3Bet サイズはポジションで変わります。'
          'ポジションがあるときは小さめ（3 倍程度）、'
          '無いときは大きめ（4 倍以上）にして相手のコール範囲を狭めます。',
      practicalView:
          '相手が 3Bet にほとんど降りないタイプなら、'
          'QQ のような強い手ではさらにサイズを上げます。',
      commonMistake:
          '「大きく打つと降りられる」と 5BB にしてしまうミスです。'
          'BTN は安い値段とポジションの両方を得て、'
          '広いレンジで気軽にコールしてきます。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
    _q(
      id: 'bs006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kd Qc',
      street: Street.river,
      board: 'Kc 9s 4h 7d 2c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンともに両者チェック', 'リバー: BB check'],
      question: '6MAX・100BB。両者チェックで進み、KQ のトップペア。薄いバリューを取るサイズはどれですか。',
      choices: ['Check', 'Bet 33%', 'Bet 100%', 'All-in'],
      correctIndex: 1,
      shortReason:
          '両者チェックで進んだので相手のレンジは弱めです。'
          '小さいサイズなら 9x や小さいペアからコールをもらえますが、'
          '大きく打つとそれらが全部降りてしまいます。',
      gtoView:
          '「薄いバリュー」とは、'
          '自分より少しだけ弱い手から取りにいくことです。'
          'そのためには、'
          'その少しだけ弱い手が払える額に抑える必要があります。',
      practicalView:
          '相手が何でもコールするタイプならサイズを上げてかまいません。'
          'サイズは、相手のコール範囲に合わせて決めます。',
      commonMistake:
          '手の強さだけでサイズを決めてしまうミスです。'
          '重要なのは自分の強さではなく、'
          '相手がどこまで払えるかです。',
    ),
    _q(
      id: 'bs007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '7c 6c',
      street: Street.river,
      board: 'Ad Kh 9s 4d 2h',
      potBb: 20,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX・100BB。ブラフします。'
          'ポット 20BB に対して 10BB と 20BB では、必要な成功率はどう変わりますか。',
      choices: [
        '10BB なら約33%、20BB なら 50%。大きいほど高い成功率が必要',
        'どちらも同じ',
        '10BB のほうが高い成功率が必要',
        'ブラフの成功率はサイズと無関係',
      ],
      correctIndex: 0,
      shortReason:
          '必要成功率はベット ÷（ポット + ベット）です。'
          '10 ÷ 30 ＝ 約33%、20 ÷ 40 ＝ 50%。'
          '大きく打つほど、より頻繁に降ろさなければ元が取れません。',
      gtoView:
          'サイズを上げると相手が降りる確率も上がりますが、'
          '必要な降り率のほうが速く上がります。'
          'だから大きいブラフは、'
          '相手が本当に降りると分かっているときに限定します。',
      practicalView:
          '相手が「大きいベットには降りるが小さいベットには受ける」タイプなら、'
          'サイズを上げる価値があります。'
          '相手の性質に合わせて選びます。',
      commonMistake:
          '手が弱いほど大きく打ってしまうミスです。'
          'サイズは自分の手の弱さではなく、'
          '相手が降りる確率で決めます。',
    ),
    _q(
      id: 'bs008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'As Ks',
      board: 'Ks Qs 4h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。KQ4（スペード 2 枚）で AK のトップペア + ナッツフラッシュドロー。'
          'サイズはどれが適していますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'Fold'],
      correctIndex: 2,
      shortReason:
          'トップペアで今も強く、'
          'さらにナッツフラッシュにもなれる最上位クラスのハンドです。'
          'ボードが濡れているので、'
          '大きく打ってポットを育てつつドローから守ります。',
      gtoView:
          '「今強い」と「これからもっと強くなれる」を'
          '両方持っているハンドが、最も大きく打てるハンドです。'
          'コールされても、外れても困りません。',
      practicalView:
          '相手が Qx やドローで受けてくれるので、'
          '大きく打っても十分にコールが期待できます。'
          'ポットを早く大きくしておくと、'
          'リバーで大きな額を賭けられます。',
      commonMistake:
          '「フラッシュドローもあるから、'
          '完成するまで小さく」と考えるミスです。'
          '完成を待つとポットが育たず、取れる額が減ります。',
    ),
    _q(
      id: 'bs009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Qh',
      board: 'Ah 7d 3s',
      potBb: 5.5,
      stackBb: 97.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。A73 レインボーで AQ のトップペア。'
          '3 ストリートかけて大きなポットを作るには、フロップのサイズをどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 1,
      shortReason:
          '乾いたボードでは、相手のレンジに強い手が少ないので、'
          '大きく打つと弱い手が全部降りてしまいます。'
          '小さく始めて、'
          'ターン・リバーで段階的に大きくするほうが最終的に多く取れます。',
      gtoView:
          '3 ストリートかけて取る場合、'
          '各ストリートで相手が付いてこられるサイズを選びます。'
          'フロップで降ろしてしまうと、'
          '残り 2 回の機会がゼロになります。',
      practicalView:
          '相手が 7x や 3x でコールしてくれるうちは、'
          '小さいサイズで残しておくのが得です。'
          'ターン以降、相手のレンジが絞られてから上げます。',
      commonMistake:
          '「強い手だから最初から大きく」としてしまうミスです。'
          '乾いたボードでは、'
          '相手に払える手がそもそも少ない点を見落としています。',
    ),
    _q(
      id: 'bs010',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '9h 9c',
      board: 'Kh 9d 4s',
      street: Street.flop,
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: [
        'BTN raise 2.5BB',
        'BB call',
        'BB check',
        'BTN bet 1.8BB',
        'BB raise を検討',
      ],
      question: '6MAX・100BB。セット（999）でチェックレイズします。1.8BB のベットに対する適切なレイズ額はどれですか。',
      choices: ['3BB', '6BB', '20BB', '97BB（オールイン）'],
      correctIndex: 1,
      shortReason:
          'レイズは「相手のベットの 3 倍前後」が目安です。'
          '1.8BB に対して 6BB なら、'
          '相手が Kx で続けやすく、'
          'それでいてポットは十分に大きくなります。',
      gtoView:
          'レイズサイズが小さすぎると相手に良いオッズを与え、'
          '大きすぎると弱い手が全部降ります。'
          '相手が続けられる範囲で、最大の額を選びます。',
      practicalView:
          '相手が Kx でほとんど降りないタイプなら、'
          'もう少し大きくしても構いません。'
          'セットは隠れているので、'
          '相手はレイズを見ても強さに気づきにくい状況です。',
      commonMistake:
          'セットを持ったときに'
          'いきなりオールインしてしまうミスです。'
          '相手が Kx で付いてこられる額に抑えないと、'
          '一番取りたい相手を逃します。',
    ),
    _q(
      id: 'bs011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ad Ac',
      street: Street.preflop,
      potBb: 14,
      villainProfile: VillainProfile.reg,
      history: ['BTN（あなた）raise 2.5BB', 'SB fold', 'BB 3Bet 11BB'],
      question: '6MAX・100BB。BB の 3Bet に AA で 4Bet します。適したサイズはどれですか。',
      choices: ['13BB', '24BB', '55BB', '100BB（オールイン）'],
      correctIndex: 1,
      shortReason:
          '3Bet の 2 倍強（24BB 前後）が目安です。'
          'この額なら QQ・JJ・AK も続けてくれます。'
          '大きすぎると降りられ、'
          '2.5BB しか取れずに終わります。',
      gtoView:
          '4Bet のサイズは「相手にどこまで続けてほしいか」で決めます。'
          '一番強い手を持っているときは、'
          '相手が続けられる最大額を選びます。',
      practicalView:
          '相手が 4Bet に対してほとんど降りないタイプなら、'
          'サイズを上げてさらに取りにいけます。'
          '逆に 4Bet で必ず降りる相手なら、'
          'コールに寄せる選択も出てきます。',
      commonMistake:
          '100BB でいきなりオールインしてしまうミスです。'
          'コールしてくれるのは KK と AK くらいで、'
          '勝っている相手のほとんどを逃がします。',
    ),
    _q(
      id: 'bs012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Qh Qd',
      board: 'Jc 8h 3d 2s',
      street: Street.turn,
      potBb: 12,
      stackBb: 90,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → CO bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX。ポット 12BB、残り 90BB。QQ でリバーまでにスタックを入れ切るのは現実的ですか。',
      choices: [
        '現実的ではない。SPR が 7.5 と深く、2 回打っても入り切らない',
        '現実的。ターンでオールインすればよい',
        '現実的。リバーで必ず入る',
        'SPR は関係ない',
      ],
      correctIndex: 0,
      shortReason:
          'SPR ＝ 90 ÷ 12 ＝ 7.5。'
          '通常のサイズで 2 回打っても、'
          'ポットは 90BB に届きません。'
          'QQ でスタックを全部入れる展開は、無理に狙う場面ではありません。',
      gtoView:
          'SPR は「どこまで戦えるか」の目安です。'
          'SPR が深いほど、'
          'スタックを入れるにはナッツに近い強さが必要になります。',
      practicalView:
          'QQ は 2 回打って価値を取り、'
          '大きなレイズが来たら降りる、という進め方が現実的です。'
          '最初から入れ切る計画は立てません。',
      commonMistake:
          '「オーバーペアだから全部入れる」と'
          '考えてしまうミスです。'
          'スタックが深いほど、'
          'オーバーペアで全額入れるのは危険になります。',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'bs013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Ad',
      board: 'Ac 8h 5s 2d 7c',
      street: Street.river,
      potBb: 30,
      stackBb: 70,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。セット（AAA）でリバー。ポット 30BB、残り 70BB。'
          'オーバーベット（45BB）を選ぶ根拠として正しいのはどれですか。',
      choices: [
        '相手のレンジに 8x・5x など払える手が多く、こちらのレンジには強い手が偏っているから',
        'セットは常にオーバーベットすべきだから',
        'ポットが大きいから',
        'オーバーベットは相手を必ず降ろせるから',
      ],
      correctIndex: 0,
      shortReason:
          'A85 のボードでこちらは 3 ストリート打ち続けており、'
          'レンジは強い側に偏っています。'
          '相手には 8x や 5x が残っているので、'
          '大きく打っても付いてくる相手がいます。',
      gtoView:
          'オーバーベットが成立するのは、'
          '「自分のレンジが相手より明確に強く」かつ'
          '「相手に払える手が残っている」ときです。'
          'どちらか一方でも欠けると機能しません。',
      practicalView:
          '同じサイズでブラフも用意しておく必要があります。'
          'オーバーベットが最強クラスだけになると、'
          '見ている相手はすぐに降りるようになります。',
      commonMistake:
          '「強い手だから最大サイズ」と機械的に決めるミスです。'
          '相手のレンジに払える手が残っていなければ、'
          'ただ降ろすだけになります。',
    ),
    _q(
      id: 'bs014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kh Kd',
      board: 'Kc 9h 8h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。K98（ハート 2 枚）でセット（KKK）。'
          '大きいサイズを選ぶ理由として最も正しいのはどれですか。',
      choices: [
        'ドローが多いボードなので、相手のエクイティを安く実現させないため',
        'セットは常に大きく打つべきだから',
        '相手に強いと思わせたいから',
        'ボードが 3 枚だから',
      ],
      correctIndex: 0,
      shortReason:
          'ハートのフラッシュドロー、'
          'JT・T7 のストレートドローが多数あるボードです。'
          '大きく打つことで、'
          'これらのドローに高い値段を払わせられます。',
      gtoView:
          'ベットサイズは「相手のレンジにどれだけドローがあるか」で決まります。'
          'ドローが多いほど、'
          '安くカードを見せることの損失が大きくなります。',
      practicalView:
          '同じセットでも K72 レインボーなら小さく打ちます。'
          '相手にドローがほとんど無いので、'
          '安く長く付き合ってもらうほうが得だからです。',
      commonMistake:
          'ハンドの強さでサイズを決めてしまうミスです。'
          '正しくは、ボードとレンジの構造で決めます。',
    ),
    _q(
      id: 'bs015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ts 9s',
      board: 'Ks 6s 2h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。K62（スペード 2 枚）でフラッシュドロー。'
          'バリューハンドと同じサイズで打つことの意味はどれですか。',
      choices: [
        '相手からベットの意味を読み取られなくなる',
        'フラッシュが完成しやすくなる',
        '相手が必ず降りる',
        'ポットオッズが良くなる',
      ],
      correctIndex: 0,
      shortReason:
          'ドローとバリューを同じサイズで打てば、'
          '相手はベットを見ても'
          'どちらを持っているか判断できません。',
      gtoView:
          'サイズごとに手の強さが決まってしまうと、'
          '相手はサイズを見るだけで正しく対応できます。'
          '同じサイズに強弱を混ぜることが、読まれない基本です。',
      practicalView:
          'このボードはこちらにレンジ有利があるので、'
          '小さいサイズを高頻度で使う形が基本です。'
          'ドローもそこに混ぜます。',
      commonMistake:
          'ドローのときだけサイズを変えてしまうミスです。'
          '観察している相手には、そのパターンがすぐ見抜かれます。',
    ),
    _q(
      id: 'bs016',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah Qc',
      street: Street.river,
      board: 'Ad Kh 9s 5c 3h',
      potBb: 20,
      villainProfile: VillainProfile.nit,
      history: ['フロップ・ターンでコールし続けた', 'リバー: あなた（BB）の番'],
      question: '6MAX・100BB。タイトな相手に AQ のトップペア。リバーで自分から打つならサイズはどれですか。',
      choices: ['Check', 'Bet 25%', 'Bet 75%', 'All-in'],
      correctIndex: 1,
      shortReason:
          'タイトな相手はリバーのベットに降りやすい傾向があります。'
          '小さいサイズなら、'
          '9x や 5x のような弱い手からも払ってもらえます。',
      gtoView:
          'バリューベットのサイズは相手のコール範囲で決まります。'
          '降りやすい相手ほど、'
          'コールしてもらえる額は小さくなります。',
      practicalView:
          '同じ AQ でも、'
          'コーリングステーション相手なら 75% 以上で打ちます。'
          'サイズだけを相手に合わせて変えるのが、'
          '最も簡単で効果の大きい調整です。',
      commonMistake:
          '「トップペアだから 3/4 ポット」と'
          '固定サイズで打ってしまうミスです。'
          '降りやすい相手には、打つ額を減らすほうが多く取れます。',
    ),
    _q(
      id: 'bs017',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ad Kc',
      board: 'Ks 7d 2c 4h',
      street: Street.turn,
      potBb: 12,
      stackBb: 88,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → CO bet 33% → BB call', 'ターン: BB check'],
      question:
          '6MAX。ポット 12BB、残り 88BB。AK でリバーまでに'
          '無理なくスタックを入れ切るには、ターンで何BB打つべきですか。',
      choices: ['4BB', '9BB', '30BB', '88BB（オールイン）'],
      correctIndex: 1,
      shortReason:
          'ターンで 9BB 打ってコールされると、'
          'ポット 30BB・残り 79BB。'
          'リバーでポットの 2.5 倍を打つ形になり、まだ入り切りません。'
          '4 択の中では最も自然に段階を踏めるサイズです。',
      gtoView:
          'サイズは「残り何ストリートで、どこまで積み上げたいか」から逆算します。'
          '各ストリートで同じくらいの割合を打つのが、'
          '最も無理なくポットを大きくする形です。',
      practicalView:
          '30BB のような大きすぎるサイズは、'
          '相手の弱い Kx を降ろしてしまいます。'
          'AK は最強ではないので、'
          '相手が付いてこられる範囲で積み上げます。',
      commonMistake:
          '各ストリートを別々に考えてしまうミスです。'
          'ターンのサイズは、'
          'リバーでいくら残るかを見てから決めます。',
    ),
    _q(
      id: 'bs018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qs Jd',
      board: 'Ah Kd 7c',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。AK7 で QJ（T のガットショット）。'
          'ブラフとして小さいサイズを選ぶ理由はどれですか。',
      choices: [
        '必要成功率が下がり、しかもこのボードでは小さくても相手が降りやすいから',
        '小さく打つほど相手が降りるから',
        'QJ が弱いハンドだから',
        '大きく打つとレイズされるから',
      ],
      correctIndex: 0,
      shortReason:
          '33% のベットなら必要成功率は 25% です。'
          'AK7 は相手がほとんど当たっていないボードなので、'
          '小さいサイズでも十分に降ろせます。',
      gtoView:
          'ブラフのサイズは「必要成功率」と'
          '「そのサイズで実際に降りる確率」の比較で決めます。'
          '相手が当たっていないボードでは、'
          '小さいサイズが最も効率よく利益を出します。',
      practicalView:
          'QJ は T でナッツになるので、'
          '降ろせなくてもリバーで戦える余地があります。'
          '安く仕掛けて、当たったら大きく取る形です。',
      commonMistake:
          '「ブラフは大きく打たないと通らない」と'
          '思い込んでしまうミスです。'
          '相手が何も持っていないボードでは、小さくても降ります。',
    ),
    _q(
      id: 'bs019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.co,
      heroCards: '5c 5d',
      board: '9h 5s 2c',
      street: Street.flop,
      potBb: 23,
      stackBb: 78,
      villainProfile: VillainProfile.reg,
      history: [
        'CO raise 2.5BB',
        'BB（あなた）3Bet 11BB',
        'CO call',
        'ポット 23BB / 残りスタック 78BB（SPR 約3.4）',
      ],
      question: '6MAX。3Bet ポットでセット（555）、SPR 約3.4。サイズの方針として正しいのはどれですか。',
      choices: [
        '2 回打てばスタックが入る計算なので、通常より大きめに打つ',
        'SPR が浅いので小さく打って長く進める',
        'チェックして相手に打たせる',
        'すぐにオールインする',
      ],
      correctIndex: 0,
      shortReason:
          'SPR 3.4 なので、'
          '2 回ポットサイズ前後で打てばスタックが入ります。'
          'セットは入れ切りたいハンドなので、'
          '逆算して大きめのサイズを選びます。',
      gtoView:
          '浅い SPR では、'
          '「何回打てば入り切るか」を先に計算してからサイズを決めます。'
          '小さく刻むと、リバーで不自然な額が残ります。',
      practicalView:
          '相手がオーバーペア（AA・KK・QQ）を持っている可能性が高いので、'
          '大きく打っても付いてきてくれます。'
          '3Bet ポットは、'
          'お互いのレンジが強いぶん大きなサイズが通りやすい構造です。',
      commonMistake:
          '100BB の感覚のまま 33% で刻んでしまうミスです。'
          '3Bet ポットでは、'
          'すでにプリフロップで大きく積んでいることを前提にサイズを決めます。',
    ),
    _q(
      id: 'bs020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac 4c',
      street: Street.river,
      board: 'Kh Qd 8s 5c 3h',
      potBb: 20,
      stackBb: 60,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。A4s で完全に外れました。'
          'ブラフのサイズを大きくすると何が起きますか。',
      choices: [
        '降ろせる相手は増えるが、必要な成功率も上がるので、条件を満たさなければ損になる',
        '必ず降ろせるようになる',
        '必要成功率が下がる',
        'サイズは成功率に影響しない',
      ],
      correctIndex: 0,
      shortReason:
          'ポット 20BB に 40BB なら必要成功率は 40 ÷ 60 ＝ 約67%。'
          '10BB なら 10 ÷ 30 ＝ 約33% です。'
          '大きくするほど、より高い頻度で降ろす必要があります。',
      gtoView:
          '大きいブラフが成立するのは、'
          '相手の続行レンジを強くブロックできているときや、'
          '相手のレンジに強い手がほとんど残っていないときです。',
      practicalView:
          'A4s は K も Q も持っておらず、'
          '相手の続行レンジをまったく減らせていません。'
          '大きいサイズを選ぶ根拠がありません。',
      commonMistake:
          '「相手を降ろしたいから大きく」と'
          '感覚でサイズを上げてしまうミスです。'
          'サイズを上げるには、それを支える根拠が必要です。',
    ),
    _q(
      id: 'bs021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '8h 8c',
      board: 'Kd 8s 3h',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。K83 レインボーでセット（888）。'
          '小さいサイズ（33%）を選ぶ理由として正しいのはどれですか。',
      choices: [
        '乾いたボードで相手にドローが少なく、安く長く付き合ってもらうほうが多く取れるから',
        'セットは弱いから',
        '相手を降ろしたいから',
        '小さいほうが安全だから',
      ],
      correctIndex: 0,
      shortReason:
          'K83 レインボーには、'
          '急いで守らなければならないドローがほとんどありません。'
          '安いサイズで相手の Kx や弱いペアを残し、'
          'ターン・リバーで積み上げます。',
      gtoView:
          'ベットサイズは「相手のエクイティをどれだけ急いで消すか」で決めます。'
          '相手にドローが無ければ、急ぐ必要がありません。',
      practicalView:
          '同じセットでも K98 ツートーンなら大きく打ちます。'
          'ボードにドローがあるかどうかで、'
          '同じハンドのサイズが変わります。',
      commonMistake:
          '「セットは常に大きく」と覚えてしまうミスです。'
          '乾いたボードで大きく打つと、'
          '相手の弱い手を全部降ろして取り分が減ります。',
    ),
    _q(
      id: 'bs022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ad Ks',
      street: Street.preflop,
      potBb: 4,
      stackBb: 40,
      villainProfile: VillainProfile.reg,
      history: ['有効スタック 40BB', 'BTN raise 2.5BB', 'SB fold'],
      question: '6MAX・有効スタック 40BB の BB です。BTN のオープンに AK で 3Bet。サイズはどれが適していますか。',
      choices: ['5BB', '9BB', '11BB', '40BB（オールイン）'],
      correctIndex: 1,
      shortReason:
          'スタックが 40BB しかないので、'
          '100BB のときと同じ 11BB では'
          'フロップ以降の余地がほとんど残りません。'
          '9BB 程度に抑えると、SPR がちょうど扱いやすい範囲になります。',
      gtoView:
          '3Bet サイズは有効スタックによって変わります。'
          'スタックが浅いほど、'
          'プリフロップに積む割合を減らさないと'
          'フロップ以降の選択肢が消えます。',
      practicalView:
          '有効スタックが 20BB 程度まで浅くなれば、'
          '3Bet ではなくそのままオールインする形が標準になります。'
          '深さに応じて、使う手段自体が変わります。',
      commonMistake:
          'スタックに関係なく'
          '同じ BB 数で 3Bet してしまうミスです。'
          'サイズは「BB 何枚か」ではなく、'
          '「スタックの何割か」で考えます。',
    ),
    _q(
      id: 'bs023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Qc',
      board: 'Qh 8d 4s 2c',
      street: Street.turn,
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → CO bet 33% → BB call', 'ターン: BB check'],
      question:
          '6MAX・100BB。KQ のトップペア。'
          'ターンで小さいサイズを選ぶ理由として正しいのはどれですか。',
      choices: [
        '大きく打つとレイズされたとき降りるしかなく、KQ はそこまで強くないから',
        'KQ が最強だから',
        '相手を降ろしたいから',
        '小さいほうが必ず得だから',
      ],
      correctIndex: 0,
      shortReason:
          'KQ はトップペアですが、'
          'ツーペアやセットに負けています。'
          '大きく打ってレイズされると降りるしかなく、'
          'ポットが大きいぶん損も大きくなります。',
      gtoView:
          '中程度の強さのハンドは、'
          'ポットを小さく保ったまま価値を取るのが基本です。'
          'サイズを上げるほど、'
          '「レイズされたら困る」というリスクが増えます。',
      practicalView:
          '小さく打てば、'
          '8x や 4x のようなさらに弱い手からも払ってもらえます。'
          'バリューの幅と安全性を両立できます。',
      commonMistake:
          '「トップペアだからしっかり打つ」と'
          '大きいサイズを選んでしまうミスです。'
          'トップペアは守るハンドであって、'
          '入れ切るハンドではありません。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'bs024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac As',
      board: 'Ad 9h 4c 3s',
      street: Street.turn,
      potBb: 20,
      stackBb: 80,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet → BB call', 'ターン: BB check'],
      question:
          '6MAX。セット（AAA）でポット 20BB、残り 80BB。'
          'ターンとリバーで均等に打ってちょうど入り切るサイズはどれに近いですか。',
      choices: ['ポットの25%', 'ポットの50%', 'ポットの90%前後', 'すぐオールイン'],
      correctIndex: 2,
      shortReason:
          'ターンにポットの 90%（18BB）を打ってコールされると、'
          'ポット 56BB・残り 62BB。'
          'リバーで残り全部を打つとポットとほぼ同額になり、自然に入り切ります。',
      gtoView:
          '残りのストリートで均等な割合を打ち続けると、'
          '無理なくスタックを使い切れます。'
          '「最後だけ極端に大きい」形にならないので、'
          '相手も付いてきやすくなります。',
      practicalView:
          '25% のような小さいサイズを選ぶと、'
          'リバーで残り 70BB をポット 30BB に打つことになり、'
          '不自然な額に見えて相手が降りやすくなります。',
      commonMistake:
          'ストリートごとに独立してサイズを決めてしまうミスです。'
          'スタックを入れたいハンドでは、'
          '最初に全体の道筋を決めます。',
    ),
    _q(
      id: 'bs025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ad Kd',
      board: 'Ac Kh 7s 2d 3c',
      street: Street.river,
      potBb: 24,
      stackBb: 76,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。AK のツーペアでリバー。'
          '大きいサイズを選ぶ前に確認すべきことはどれですか。',
      choices: [
        '相手のレンジに、大きいサイズでも払える手が残っているか',
        '自分の手が最強かどうか',
        'ポットが大きいかどうか',
        '相手のスタックが残っているかどうか',
      ],
      correctIndex: 0,
      shortReason:
          'AK のツーペアは強いですが、'
          '相手のレンジには A7・K7・77・33 など'
          '負けているセット・ツーペアもあります。'
          '大きく打って払ってくれるのは、そのうち何通りかを数えます。',
      gtoView:
          'バリューベットのサイズは'
          '「その額を払える相手のハンド」を数えて決めます。'
          '払える手が少ないなら、'
          '大きく打つほど「勝っている相手だけが残る」形になります。',
      practicalView:
          'A7 や K7 のトップペア以下から取りたいなら、'
          '中くらいのサイズが噛み合います。'
          '相手のレンジ構成を先に考えるのが順序です。',
      commonMistake:
          '自分の手の強さの順位だけでサイズを決めてしまうミスです。'
          '「自分がどれくらい強いか」ではなく、'
          '「相手が何を払えるか」で決めます。',
    ),
    _q(
      id: 'bs026',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '6h 5h',
      board: '9h 7d 3c 8s 2c',
      street: Street.river,
      potBb: 20,
      stackBb: 60,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでコールし続けた', 'リバー: あなた（BB）の番'],
      question:
          '6MAX。65s でストレートが完成しました。'
          'このボードでオーバーベットが有効になる理由はどれですか。',
      choices: [
        'ストレートを含む強い形が BB のレンジに集中しており、相手には少ないから',
        'ストレートは常にオーバーベットすべきだから',
        'ポットが小さいから',
        '相手が必ず降りるから',
      ],
      correctIndex: 0,
      shortReason:
          '9873 のボードで 65・T6・JT のストレートを作れるのは、'
          '主に BB のコールレンジです。'
          'BTN のオープンレンジにはこうした形が少なく、'
          'こちらだけが最強クラスを持てる状態です。',
      gtoView:
          '「自分のレンジにしか無い最強クラス」があると、'
          '相手はどのサイズにも対応しづらくなります。'
          'この状態がオーバーベットの前提条件です。',
      practicalView:
          '同じサイズでブラフも用意する必要があります。'
          '外したドローをここに混ぜておくと、'
          '相手はストレートだけを避けることができなくなります。',
      commonMistake:
          '完成した瞬間にサイズを最大まで上げてしまうミスです。'
          'オーバーベットには、'
          'レンジ構造という裏付けが必要です。',
    ),
    _q(
      id: 'bs027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qh Qd',
      board: 'Kd 7c 3h',
      potBb: 24,
      stackBb: 76,
      villainProfile: VillainProfile.reg,
      history: [
        'BTN raise 2.5BB',
        'BB 3Bet 11BB',
        'BTN call',
        'ポット 24BB / 残り 76BB（SPR 約3）',
        'BB bet 12BB',
      ],
      question: '6MAX。3Bet ポット（SPR 約3）で QQ、K 高のボードで打たれました。どうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          'K に負けていますが、'
          '相手の 3Bet レンジには AQ・AJ・A5s など'
          'K を持たないブラフも多く含まれます。'
          '必要勝率は 12 ÷ 48 ＝ 25% で、QQ はそれを上回ります。',
      gtoView:
          '3Bet ポットでは SPR が浅いため、'
          'レイズするとほぼスタックを入れることになります。'
          'QQ は「相手のブラフに勝てるが、'
          'Kx やセットには負ける」中間の位置です。',
      practicalView:
          'ターンで相手が打ち続けてきたら、'
          'そこで降りる準備をしておきます。'
          '1 回受けることと最後まで受けることは、別の判断です。',
      commonMistake:
          '「SPR が浅いから入れるしかない」と'
          'レイズしてしまうミスです。'
          '浅いからこそ、'
          '入れるハンドの基準を厳しくする必要があります。',
    ),
    _q(
      id: 'bs028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ah Ac',
      board: '7h 6h 5c',
      potBb: 5.5,
      stackBb: 97.5,
      villainProfile: VillainProfile.reg,
      history: ['CO raise 2.5BB', 'BB call', 'BB check'],
      question:
          '6MAX・100BB。765（ハート 2 枚）で AA。'
          'サイズ選択として最も適切な考え方はどれですか。',
      choices: [
        '大きく打ってドローを降ろしたいが、レイズされると苦しいので小さめか、チェックに寄せる',
        '最強なので全額入れる方向で最大サイズ',
        '必ずチェックする',
        'サイズは関係ない',
      ],
      correctIndex: 0,
      shortReason:
          'AA は今勝っている可能性が高いものの、'
          'このボードでは 98・87・76・65・55 などに'
          'すでに負けている組み合わせがあります。'
          '大きく打つと、勝っている相手だけが降りていきます。',
      gtoView:
          'ドローが多いボードは「守りたい」気持ちを誘いますが、'
          '同時に「相手がすでに完成している」ボードでもあります。'
          'その両方を天秤にかけてサイズを決めます。',
      practicalView:
          '小さいサイズなら、'
          'レイズされたときの損失を抑えつつ'
          'ドローから少しずつ取れます。'
          'ポットを膨らませないことが優先です。',
      commonMistake:
          '「AA だから守るために大きく打つ」と'
          '反射的に決めてしまうミスです。'
          'このボードで大きなポットになる展開は、'
          'こちらが負けていることが多くなります。',
    ),
    _q(
      id: 'bs029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kh Kc',
      board: 'Ks 9d 4c 2h 7s',
      street: Street.river,
      potBb: 20,
      stackBb: 100,
      villainProfile: VillainProfile.reg,
      history: ['フロップ・ターンでベットしコールされた', 'リバー: BB check'],
      question:
          '6MAX。セット（KKK）でリバー。'
          '複数のサイズを使い分けるとき、同じサイズにブラフも用意する必要があるのはなぜですか。',
      choices: [
        'サイズと手の強さが 1 対 1 で結びつくと、相手はサイズを見るだけで正しく対応できるから',
        'ブラフのほうが利益が大きいから',
        'ルールで決まっているから',
        'ブラフを混ぜると相手が必ず降りるから',
      ],
      correctIndex: 0,
      shortReason:
          '「大きいベット＝最強」と分かってしまえば、'
          '相手は最強クラス以外すべて降りるだけで正しく対応できます。'
          '同じサイズにブラフがあるからこそ、'
          '相手は払わざるを得なくなります。',
      gtoView:
          'サイズごとにバリューとブラフの両方を持つのが基本の構造です。'
          '大きいサイズほど相手に要求する勝率が上がるため、'
          'ブラフの比率も上げられます。',
      practicalView:
          '相手が観察してこないタイプなら、'
          'バランスは気にせずバリューだけ大きく打って構いません。'
          'この考え方が必要なのは、'
          'こちらの傾向を見ている相手に対してです。',
      commonMistake:
          '強い手のときだけサイズを変えてしまうミスです。'
          '短期的には取れますが、'
          '同じ相手と長く打つほど不利になります。',
    ),
    _q(
      id: 'bs030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Js Ts',
      board: 'Qs 9d 3s',
      potBb: 5.5,
      stackBb: 97.5,
      villainProfile: VillainProfile.reg,
      history: ['BTN raise 2.5BB', 'BB call', 'BB check', 'BTN bet 1.8BB'],
      question:
          '6MAX・100BB。JTs でフラッシュドロー + ガットショット。'
          'チェックレイズのサイズを大きめにする理由はどれですか。',
      choices: [
        'エクイティが高いので、降ろせなくてもポットが大きいほうが有利だから',
        'レイズは常に最大にすべきだから',
        '相手を必ず降ろすため',
        'サイズは何でも同じだから',
      ],
      correctIndex: 0,
      shortReason:
          'スペード 9 枚に K のガットショット 4 枚を加えた強いドローです。'
          '降ろせれば良し、'
          'コールされてもポットが大きいほど'
          '完成したときの取り分が増えます。',
      gtoView:
          'レイズのサイズは「降ろす目的」と'
          '「完成したときの取り分」の両方から決めます。'
          'エクイティが高いドローほど、'
          '後者の比重が大きくなり、サイズを上げられます。',
      practicalView:
          'エクイティの低いブラフ（何も無いハンド）でレイズするときは、'
          '逆にサイズを抑えます。'
          '降ろせなかったときに、'
          '大きなポットで戦う材料が無いからです。',
      commonMistake:
          'ドローの強さに関係なく、'
          '同じレイズサイズを使ってしまうミスです。'
          'エクイティが高いほど、大きく賭けられます。',
    ),
  ];
}
