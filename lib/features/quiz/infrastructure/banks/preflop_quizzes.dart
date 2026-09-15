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
          'オフスートのエースは AJo 前後が下限になります。'
          'これは UTG では「後ろの誰かが強いハンドを持っている確率」が最も高く、'
          'しかもその全員に対してオープン後もアクションを晒し続けなければならないためです。'
          '同じ理由で、キッカーの弱い A9o や A8o は HJ や CO ではオープンレンジに入ってきても、'
          'UTG では真っ先に外れる部類のハンドになります。',
      practicalView:
          '後ろが極端にタイトで、ほとんど誰も参加してこないテーブルなら'
          'A9o のオープンも成立します。相手が降りやすいほど広げられますが、'
          'これはあくまで「オープンした時点でほぼポットを取り切れる」という前提があってこそ'
          '成り立つ調整です。逆に後ろに 3Bet を仕掛けてくるプレイヤーが 1 人でもいるテーブルでは、'
          'A9o はその 3Bet に対してコールもフォールドも判断が難しい中途半端な強さになりやすく、'
          '素直に下限から外しておくほうが安定します。',
      commonMistake:
          '「A が付いているから強い」と考えてしまうミスです。'
          'エース自体は強いですが、キッカーが弱いオフスートエースは'
          '「相手も A を持っているときに必ず負けている」形になりがちです。'
          'さらに、A9o は相手が AK/AQ/AJ で参加してきたとき勝率 20% 前後まで落ち込む一方、'
          '相手の QJ や T9 のような手には勝っているため'
          '「オールインすれば五分五分だろう」という感覚的な過大評価も起きやすい部分です。'
          'UTG からのオープンは「強い手を持たれたときにどれだけ沈むか」で判断するべきで、'
          '「平均的にはどうか」では判断しません。',
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
          'KTs はその中でも上のほうに位置します。'
          'KTs はブロードウェイのトップペアを作れるうえ、'
          'フラッシュとストレートの両方に向かえるスーテッドという組み合わせを持つため、'
          'BTN の広いレンジの中でも「降ろされにくく、降ろされても取り返しが効く」上位ハンドに数えられます。'
          'K9s や K8s のようにキッカーがさらに落ちると同じ論理は弱まっていきます。',
      practicalView:
          'ブラインドが 3Bet を多用する相手でも KTs は降りる必要のない強さです。'
          '3Bet された後は基本的にコールで様子を見て、'
          'フロップでキッカーやフラッシュドローの強さを活かす方針になります。'
          'ブラインドが受け身でほとんどレイズを返してこないなら、さらに広げてかまいません。'
          '特に SB がコールドコールばかりで BB もオープンにほぼ手向かいしないテーブルでは、'
          'KTo や QTs のような一段落ちるハンドまでオープンレンジに含める余地があります。',
      commonMistake:
          'リンプ（コールだけで参加）してしまうミスです。'
          'リンプは主導権を渡すうえ、ブラインドに安くフロップを見せてしまいます。'
          'KTs のようにフォールドエクイティも実質的なバリューも両方持つハンドをリンプで抑えると、'
          'ブラインドから弱いハンドを降ろす機会を自分から捨てることになり、'
          'さらにブラインド側にオーバーリンプやアイソレーションレイズという主導権を渡すことにもなります。',
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
          'レイズはその両方を同時に達成します。'
          'AKo はショーダウンでは強い一方、フロップでヒットしない回も多いハンドなので、'
          'プリフロップで先制してポットとイニシアチブを握っておくことで、'
          'A ハイやハイカードのままでもベットで主導権を維持しやすくなります。',
      practicalView:
          'All-in が正解になるのは有効スタックが十数 BB まで浅いときです。'
          '100BB でオールインすると、コールしてくれるのは AA・KK だけになってしまい、'
          'しかもその相手に AKo は大きく負けている組み合わせです。'
          '100BB の深さでは、通常のオープンサイズでレイズしてポジションを保ったまま、'
          '3Bet された場合にさらに判断する余地を残すほうが得られる利益が大きくなります。',
      commonMistake:
          '「強すぎるから相手を逃したくない」とリンプしてしまうミスです。'
          '一番強いレンジのときこそ、素直に大きいポットを作りにいきます。'
          'リンプでスロープレイをしても、後ろの複数人を安く参加させてしまえば、'
          'AKo のようなハイカード主体のハンドはむしろ多人数のポットで実現できる勝率を落とします。'
          '逃したくない相手には、レイズで自分からポットを大きくして追いかけさせるほうが合理的です。',
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
          'フラッシュという降ろされにくい強い完成形が増えるためです。'
          '加えて、3Bet されてフォールドする場合でも、'
          'スーテッドはドローとしての伸びしろを最後まで残せるため実質的な損失が小さく、'
          'コールして続行する場合にも「勝てないのに降りられない」という苦しい形になりにくい特徴があります。',
      practicalView:
          '後ろのプレイヤーが 3Bet を連発してくるなら、'
          'こうした境界付近のハンドから外していきます。'
          'QJs は 3Bet に対してコールもフォールドも成立しうる中間の強さなので、'
          '3Bet レンジが広い相手には勝ちにくく、'
          '逆に 3Bet がめったに飛んでこないテーブルでは HJ からさらに一段階弱いスーテッドまで'
          'オープンレンジを広げる余地があります。',
      commonMistake:
          'QJs と QJo を同じ強さだと思ってしまうミスです。'
          'スーテッドかどうかは、参加できるポジションが 1 つ変わる程度の差になります。'
          'QJo は 3Bet に対してコールで続けにくく実質フォールド寄りになりがちですが、'
          'QJs は同じ場面でもフラッシュドローの伸びしろがあるぶんコールで戦える範囲が広がり、'
          '扱いが根本的に変わってきます。',
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
          '手にした権利を実現できず、参加するほど損をします。'
          '72o はトップペアを作ってもキッカーが弱く BTN のレンジに支配されやすく、'
          '当たっても大きく取れずに外れた回だけ確実に負ける「見せかけのオッズ」の代表例です。'
          'ポットオッズはあくまで最低条件で、フロップ以降どれだけ勝ち切れるかまで込みで判断する必要があります。',
      practicalView:
          'BB のディフェンスは「値段」と「フロップ以降で戦えるか」の両方で決めます。'
          '同じ値段でも 72s や 76o なら守れます。'
          '72s はフラッシュとストレートの両方に向かえるぶん降ろされにくい形を作れ、'
          '76o はコネクターとして連続する数字を持つためストレートに向かいやすく、'
          'どちらも 72o にはない「はっきり勝てる完成形」を持っています。',
      commonMistake:
          '「BB は安いから何でも守る」と覚えてしまうミスです。'
          '守るべきなのは、フロップで何かを作れる可能性があるハンドだけです。'
          '72o のようなキッカーもつながりもないハンドを機械的にコールし続けると、'
          'フロップ以降ずっとチェック・フォールドを繰り返す羽目になり、'
          '1BB の節約以上のチップをじわじわ失っていきます。',
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
          '後ろの人数が増えるほど「誰か 1 人は強い」確率が上がるため、レンジは狭くなります。'
          'KJo は誰も参加してこなければ十分強いハンドですが、9MAX の UTG では後ろに 8 人おり、'
          'そのうち誰か 1 人でも AK や KQ、あるいは AA クラスを持っていれば大きく支配される展開になりやすく、'
          '期待値の中心が「支配されたときの負け幅」に引っ張られます。',
      practicalView:
          '参加者の多いルースなテーブルほど、アーリーからのオープンは締めます。'
          '逆に全員がタイトなら少しだけ広げられます。'
          '特に 9MAX では後ろに座るプレイヤーの人数がそのまま「支配されるリスクの母数」になるため、'
          '6MAX の感覚で UTG のレンジを組むと、実戦では想定以上に強いハンドとぶつかる頻度が高くなります。',
      commonMistake:
          '6MAX で覚えたレンジを 9MAX にそのまま持ち込むミスです。'
          'ポジション名が同じでも、後ろの人数が違えば別のスポットです。'
          'KJo は 6MAX の UTG なら境界線付近で開ける部類ですが、9MAX では後ろの人数が大きく増えるぶん、'
          '同じ「UTG」という名前のポジションでも実質的にはもっと深いアーリーポジションとして扱う必要があります。',
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
          'プリフロップで積む金額が増えるほど、フロップ以降の各ベットも大きくなります。'
          'AA はフロップで何もヒットしなくても依然として最強のハンドであり続けることが多いため、'
          'プリフロップの時点でポットを大きくしておくこと自体が、'
          'フロップの中身に関係なく利益を積み増す手段になります。',
      practicalView:
          'All-in は 100BB では大きすぎます。'
          '相手が降りてしまい、2.5BB しか取れません。'
          'UTG のオープンレンジには AK や QQ のような、'
          '8BB 程度の 3Bet なら追いかけてくるが 100BB のオールインには絶対に付き合わないハンドが多く含まれており、'
          'サイズを抑えることでそうした「ついてこられる強いレンジ」を最大限残せます。',
      commonMistake:
          '「トラップしたい」とコールしてしまうミスです。'
          'コールすると後ろの 3 人に安く入られ、'
          'AA が多人数戦で負ける確率まで上げてしまいます。'
          'AA は 1 対 1 では圧倒的に強い一方、参加人数が増えるほど'
          '誰か 1 人がフロップでツーペアやセット、あるいはナッツドローを作る確率が積み上がっていくため、'
          'トラップよりもまず参加人数を絞ることが優先されます。',
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
          'レイズは後者を丸ごと手に入れる動きです。'
          'CO は後ろがブラインド 2 人と BTN の 3 人だけなので、'
          'レイズ一発で全員が降りてポットをそのまま獲得できる場面が多く、'
          '55 のようにポストフロップでは弱く見える手でも、'
          'プリフロップの時点で完結する利益を積み上げられます。',
      practicalView:
          '後ろがコールばかりでほとんど降りない相手なら、'
          '降ろす価値が減るぶん、セットになることに期待する比重が上がります。'
          'その場合は有効スタックの深さが特に重要になり、'
          '100BB あれば相手のトップペアやオーバーペアから大きく取れる一方、'
          'スタックが浅いテーブルではセットになってもリターンが乏しく、'
          '55 のオープン自体を見直す必要が出てきます。',
      commonMistake:
          '「小さいペアは安く見たい」とリンプしてしまうミスです。'
          'リンプは降ろす可能性をゼロにするうえ、複数人を呼び込みます。'
          '複数人参加のポットでセットを引いても、誰かに強いレンジを読まれてフォールドされやすくなり、'
          '55 の価値を支えている「降ろせる可能性」と「当たったときに大きく取れる可能性」の'
          '両方を自分で削ってしまいます。',
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
          'ポジションがあっても、作れる形がなければ利益は出ません。'
          'J4o はキッカーが弱くつながりもないため、トップペアを作ってもキッカー勝負に負けやすく、'
          'ミドルペア以下ではほとんどのベットに降りるしかない形になり、'
          'ポジションの利点を活かしきれません。',
      practicalView:
          'ブラインドが極端に降りやすい相手なら、'
          'ブラインドを奪う目的だけで広げる余地はあります。'
          'ただしコールされた後は捨てる前提のプレイになります。'
          'この種の「ブラインドスチール専用」ハンドは、コールされた時点でほぼ価値を失うため、'
          '少しでもブラインドが手向かいしてくる相手が混ざっているテーブルでは、'
          '下限から J4o のようなハンドを外しておくほうが安定します。',
      commonMistake:
          '「BTN は何でもレイズしていい」と極端に覚えてしまうミスです。'
          'BTN が広いのは理由があってのことで、下限は存在します。'
          'BTN の広さは「ポジションを活かして小さなエッジを実現できる」ことが前提で、'
          'J4o のようにフロップで作れる形自体が乏しいハンドは、'
          'ポジションがあっても実現するエッジがそもそも存在しません。',
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
          '失敗したときの損だけが大きくなります。'
          '逆にミニレイズのように小さすぎるサイズは、コールする相手のポットオッズを良くしてしまい、'
          'KQo のような強いハンドで得たいはずの「レンジを絞る」効果を自ら打ち消してしまいます。'
          'ちょうどよいサイズは、この両極の間で相手に最も難しい判断を迫る位置にあります。',
      practicalView:
          'ブラインドがコールしすぎる相手なら、'
          'サイズを上げて強いレンジから多く取りにいく調整が有効です。'
          'オンラインの標準は 2〜2.5BB、ライブでは 3BB 前後が多く使われます。'
          'ライブでサイズが大きめになりやすいのは、対面のテーブルはオンラインよりコールされやすい傾向があるためで、'
          'KQo のようなハンドではその分バリューを厚く取りにいく方が噛み合います。',
      commonMistake:
          'ミニレイズにしてしまうミスです。'
          '安すぎるとブラインドがほぼ全ハンドでコールでき、'
          'レイズした意味（レンジを狭める）が消えます。'
          'KQo のようにフロップで当たったときに大きなポットを作りたいハンドほど、'
          'プリフロップの時点で参加人数を絞り、1 対 1 に近い形に持ち込む価値が大きくなります。',
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
          '全員降りた後の BTN は、6MAX でも 9MAX でも同じ条件になります。'
          'T9s はミドルカードのスーテッドコネクターで、単体の勝率よりもポジションを得たときの'
          'プレイのしやすさで価値が決まるハンドなので、後ろに残るのがブラインド 2 人だけという条件さえ揃えば、'
          'テーブル人数に関わらず同じ強さで扱えます。',
      practicalView:
          'ブラインドがタイトなら、さらに広げてブラインドを奪いにいけます。'
          '逆に BB がよく守る相手ならレンジは締めます。'
          '9MAX のブラインドは 6MAX よりもポジションの価値を強く意識してタイトに構えるプレイヤーが多い傾向があり、'
          'そうした相手には T9s よりさらに弱いコネクターまでオープンレンジを広げる調整も成立します。',
      commonMistake:
          '「9MAX だから全部タイトに」と機械的に締めてしまうミスです。'
          'アーリーが降りた後のレイトポジションは、人数に関係なく広く戦えます。'
          'UTG や HJ での締まったレンジのイメージを、BTN まで含めたテーブル全体に一律で適用してしまうと、'
          'T9s のように本来オープンできるハンドまで手放し、取れるはずのブラインドを取り逃すことになります。',
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
          '安く見て、当たったときだけ大きくするハンドに向いた場所です。'
          '33 はフロップで当たらなければ即座に見切りをつけられる一方、'
          'セットになれば UTG の強いレンジ（オーバーペアや AK 系のトップペア）から大きく取れる'
          '非対称なハンドで、BB というポジションの安さと組み合わさって初めて成立します。',
      practicalView:
          '有効スタックが浅いとセットになったときの取り分が減るため、'
          '20BB 程度しかない場合はこのコールの価値が下がります。'
          '100BB のような深いスタックほど、セットになったときに相手のスタック全体を狙える可能性が出てくるため、'
          '33 のようなハンドのコールの価値はスタックの深さにほぼ比例して上がっていきます。',
      commonMistake:
          '33 で 3Bet してしまうミスです。'
          '3Bet すると UTG の弱い部分が降りてしまい、'
          '残るのは 33 が負けているハンドばかりになります。'
          'UTG はただでさえレンジが強いポジションなので、そこにさらに 3Bet で圧力をかけても、'
          '返ってくるのは AA や KK、AK のような 33 が大きく負けているレンジに絞られてしまい、'
          'コールで安くセットを狙う方針より期待値が下がります。',
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
          'A5s のように自分では勝ちにくいがブロッカーが効くハンドを上の層に混ぜます。'
          'この二層構造にすることで、相手からは 3Bet レンジの中身が読みにくくなり、'
          '強いバリューハンドだけで 3Bet していたときよりも、相手のコールやフォールドの判断を難しくできます。',
      practicalView:
          '相手が 4Bet を多用するタイプなら 3Bet ブラフは減らします。'
          '逆にコールばかりで降りない相手なら、'
          '降ろす効果が消えるのでコールしてフロップを見るほうが得です。'
          '特に BTN がオープンに固執して 3Bet にもコールしがちなタイプの場合、'
          'A5s は 3Bet しても降ろせず、フロップでもキッカーの弱さから苦しい展開になりやすいため、'
          '素直にコールしてポジションを活かしたプレイに回すほうが安定します。',
      commonMistake:
          'A5s を「弱いエース」と考えて毎回フォールドしてしまうミスです。'
          '3Bet ブラフに求められるのは手の強さではなく、'
          'ブロッカーと、コールされたときの伸びしろです。'
          '同じ基準で見ると、A9o のようなブロッカーはあってもドローに向かえないハンドより、'
          'A5s のほうが 3Bet ブラフの候補として優れており、'
          '「弱いから降りる」という短絡的な判断は、3Bet レンジ全体の設計を見落とすことになります。',
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
          'レンジを狭めないコールのほうが噛み合います。'
          'BTN の 3Bet レンジには AJo や KQo のような AQo に負けている組み合わせも含まれているはずで、'
          '4Bet でそれらを降ろしてしまうと、残るのは AA・KK・AK という'
          'AQo が明確に負けているレンジだけになってしまいます。',
      practicalView:
          'BTN が 3Bet を乱発するタイプなら 4Bet の価値が上がり、'
          '3Bet が最強クラスしかない相手ならフォールドも十分ありえます。'
          '相手の 3Bet レンジの広さが、そのまま判断を動かします。'
          '3Bet の頻度が読めない初対面の相手に対しては、まずコールでフロップを見て、'
          '相手のベットパターンから 3Bet レンジの実際の強さを推測していく進め方が無難です。',
      commonMistake:
          '「AQ は強いから 4Bet」と手の絶対的な強さだけで決めてしまうミスです。'
          '重要なのは、その動きに対して相手が何を残すかです。'
          'AQo は単体で見れば上位ハンドですが、3Bet・4Bet という圧力の掛け合いの中では'
          '「自分が勝てる範囲を残したまま相手の弱い部分だけを降ろせるか」で価値が決まり、'
          'その基準で見るとコールのほうが理にかなう場面が多くなります。',
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
          '取れる額が増えているぶん、通常の 3Bet より広く行えます。'
          'QQ は UTG と CO のどちらのレンジに対してもオーバーペアとして優位に立てるハンドで、'
          'しかも 2 人分のブロッカー効果（相手が AA や KK を持っている確率を織り込んだうえでの優位）も加わるため、'
          'スクイーズの中でも最上位のバリューとして扱えます。',
      practicalView:
          'CO がコールしすぎるタイプなら、'
          'スクイーズのサイズを上げてバリューを厚く取りにいきます。'
          '逆に UTG がオープンに固執してほとんど降りないタイプなら、'
          'サイズを上げてもフォールドエクイティは増えないため、'
          'QQ というハンド自体の強さでバリューを稼ぐ意識に切り替えます。',
      commonMistake:
          'QQ でコールして 4 人でフロップを見てしまうミスです。'
          '多人数になるほど、オーバーペアが最後まで勝っている確率は下がります。'
          '4 人が絡むフロップでは、誰かがセットやツーペア、あるいはナッツドローを作る確率が'
          '単純に積み上がっていくため、QQ のようなハンドはむしろ参加人数を絞ってこそ強さを発揮できます。',
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
          '弱い相手が 1 人いるときは、後者の価値が特に大きくなります。'
          'ルース・パッシブなリンパーは弱いハンドでも降りずにフロップまで付き合ってくる傾向がある一方、'
          '後ろから 3Bet を打ってくることはほとんどないため、'
          'サイズを大きめにして他のプレイヤーを降ろしても、狙った相手だけはコールしてくれる構造が作りやすくなります。',
      practicalView:
          'サイズを通常の 2.5BB ではなく 4.5BB 程度に上げるのは、'
          'リンパーが 2.5BB ではまず降りず、'
          '後ろのプレイヤーにも安い参加を許してしまうためです。'
          '目安としては「リンプ 1 人につき通常のオープンサイズに 1BB ほど上乗せする」調整が使われ、'
          'リンパーが複数いる場合はさらにサイズを重ねていきます。',
      commonMistake:
          '一緒にリンプしてしまうミスです。'
          '一番弱い相手と 2 人で戦えるはずの場面で、'
          '5 人参加の運任せなポットにしてしまいます。'
          'ATo は 1 対 1 ならリンパーの広いレンジに対して優位に立てるハンドですが、'
          '多人数のポットになるとキッカーの弱さやツーペア・セットに沈むリスクが増え、'
          'せっかくの優位性が薄まってしまいます。',
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
          '20BB ではまだレイズ・フォールドという選択肢が生きています。'
          'AJo は 3Bet されたときに「降りるべき相手」と「コールで続けられる相手」がはっきり分かれるハンドなので、'
          '最初からオールインにしてこの判断の余地を消してしまうのはもったいない深さです。',
      practicalView:
          'ブラインドが頻繁にオールインを返してくる相手なら、'
          '2BB オープンの価値が下がるためレンジを締めます。'
          '20BB というスタックはブラインドにとってもオールインを仕掛けやすい深さなので、'
          'そうしたショートスタック戦に慣れた相手が座っているテーブルでは、'
          'AJo のような中間の強さのハンドは真っ先にレンジから外す対象になります。',
      commonMistake:
          '「浅いからとりあえずオールイン」と決めてしまうミスです。'
          '20BB を賭けて 1.5BB を取りにいく動きで、'
          'コールされるときはほぼ負けています。'
          '20BB は「浅いから何でもオールイン」と「100BB と同じように打つ」の中間にあたる深さで、'
          'AJo のようなハンドではむしろその中間性を活かし、'
          'レイズしてから相手の反応を見て判断する打ち方のほうが利益を残せます。',
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
          '選択肢が減った結果、オールインとフォールドの二択に収束していきます。'
          '12BB という深さでは、2.5BB 程度のオープンサイズでも実質的にスタックの 4 分の 1 近くを投入することになり、'
          '3Bet されたときに降りる選択肢がほとんど機能しないため、'
          '最初からオールインで押し切るほうがシンプルかつ強い打ち方になります。',
      practicalView:
          'BB がほとんどコールしない相手なら、'
          'オールインの成功率が上がるのでさらに広げられます。'
          '逆に何でもコールする相手なら、勝てるハンドだけに絞ります。'
          'コーリングステーション寄りの BB に対しては、A8o のようなハンドは単純に'
          '「コールされたときに勝てるかどうか」で判断し、フォールドエクイティに頼らないレンジ構成に切り替える必要があります。',
      commonMistake:
          '浅いスタックでリンプしてしまうミスです。'
          '降ろす機会を捨てたうえ、不利なポジションでフロップを迎えることになります。'
          '12BB でリンプすると、BB に無料でオプションを与えたうえ、'
          'フロップ以降も SB という最も不利なポジションから浅いスタックを動かすことになり、'
          'A8o が持っているはずのプッシュ力をまったく活かせません。',
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
          '大きすぎると AA しか残らず、小さすぎると相手に良いオッズを与えます。'
          'KK は AA 以外のあらゆるレンジに対して優位に立てるハンドなので、'
          '4Bet のサイズ設計はほぼ「いかに AA 以外を巻き込むか」に集約され、'
          '極端なサイズは避けて相手が続けやすい範囲に収めることが重要になります。',
      practicalView:
          '相手が 3Bet ブラフを多用するタイプなら、'
          '4Bet に対してさらに返してくる分だけ利益が増えます。'
          '3Bet が最強クラスしかない相手なら、KK でもコールに寄せる判断があります。'
          'BB の 3Bet レンジがブラフを含まず AA・KK・AK に極端に絞られていると読める場合は、'
          '24BB の 4Bet 自体が AA にしか呼んでもらえない動きになるため、'
          'コールしてフロップでのプレイに賭けるほうが実利につながることもあります。',
      commonMistake:
          '100BB でいきなりオールインしてしまうミスです。'
          'コールしてくれるのは AA だけになり、'
          '勝っている相手（QQ・JJ・AK）を全部逃がします。'
          'KK は AA 以外に負けないハンドなので、極端なサイズで相手のレンジを絞ってしまうこと自体が、'
          'KK というハンドの持つ優位性を自分で消してしまう行為になります。',
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
          '他のポジション相手より大幅に広く守れます。'
          'J8o は BTN や CO のオープンに対してはキッカーの弱さから守りにくいハンドですが、'
          'SB のオープンレンジ自体もそこまで強くない上に、フロップ以降ずっとポジションを握れることが加わり、'
          '同じハンドでも相手のポジションひとつで評価が大きく変わります。',
      practicalView:
          'SB が極端にタイトなレンジしかオープンしないなら、'
          '同じ値段でも降りる寄りに調整します。'
          'タイトな SB は強いハンドに絞ってオープンしてくるため、'
          'J8o のようなハンドはポジションがあってもキッカー勝負や上位ハンドとの衝突で苦しくなりやすく、'
          'レンジの広さは相手のオープン頻度に応じて機械的にではなく都度調整する必要があります。',
      commonMistake:
          '「BB はいつも不利」と思い込んで降りすぎるミスです。'
          'SB 相手のときだけはポジションが逆転します。'
          'BTN や CO のオープンに対する感覚をそのまま SB のオープンにも当てはめてしまうと、'
          '本来コールで十分戦える J8o のようなハンドまでフォールドしてしまい、'
          'SB vs BB という構造上の優位を活かせないまま終わります。',
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
          'BTN で、しかもブラインドがスクイーズしてこないなら条件が揃います。'
          '76s はヒットしなければ即座に降りられるうえ、ヒットすればストレートやフラッシュという'
          '相手に見えにくい強い形になるため、ポジションを保証されたコールとの相性が特に良いハンドです。',
      practicalView:
          '同じ 76s でも、CO でコールすると後ろに 3 人残るため条件が悪くなります。'
          'ブラインドがスクイーズを多用する相手でも、'
          'コールの価値は大きく下がります。'
          'スクイーズを受けると、せっかく安く見に行ったつもりのコールが一気に大きなポットに膨らみ、'
          'しかも 76s というハンド自体はそのポットサイズに見合う強さを持っていないため、'
          'フォールドせざるを得ない場面が増えます。',
      commonMistake:
          '「スーテッドコネクターはどこからでも参加できる」と考えるミスです。'
          '安く見られてポジションがあるときにだけ価値が出るハンドです。'
          '76s の価値は「フロップで大きく当たる確率」ではなく'
          '「安いコストでその可能性を保持できるかどうか」にあり、'
          '条件が崩れるとただの弱いハンドに戻ってしまうことを忘れてはいけません。',
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
          'その前提が消えると成立しません。'
          'SB からのコールはフロップ以降ずっと先に動く側になり、'
          'しかも BB というもう 1 人のプレイヤーが背後にいない代わりに BTN という強いポジションの相手と'
          '直接向き合うことになるため、76s の持つ「安く見て大きく取る」性質がそもそも機能しにくくなります。',
      practicalView:
          '有効スタックが 200BB あるなど、当たったときの取り分が跳ね上がる状況なら'
          'コールの余地が生まれます。100BB では足りません。'
          '深いスタックほどインプライドオッズが増え、'
          '76s のような「完成すれば強いが完成率は高くない」ハンドの価値が相対的に上がっていくため、'
          '同じ状況でもスタックの深さ次第で判断が変わる代表的なハンドです。',
      commonMistake:
          '「一度レイズしたから引けない」と考えてコールしてしまうミスです。'
          'すでに入れた 3BB は、これからの判断とは無関係です。'
          'サンクコストにとらわれると、本来なら降りるべき 76s を「もったいないから」という理由だけで'
          'コールしてしまい、不利なポジションでさらにチップを危険にさらすことになります。',
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
          'レーキの重い環境ほど、境界線上のハンドは降りる側に寄ります。'
          '65s はもともとレーキのない前提でも UTG では利益がわずかなハンドで、'
          'そこにレーキという固定コストが乗ると、獲得できるはずだった小さな利益がまるごと相殺されてしまいます。',
      practicalView:
          '同じ 65s でも、BTN や CO からなら降ろす手段があるためオープンできます。'
          'レーキの軽い高レートでは UTG からの下限も少し広がります。'
          '高レートほどレーキの絶対額に対してポットサイズが相対的に大きくなり、'
          'レーキ負けの影響が薄まるため、同じ 65s というハンドでもレートが上がるほど扱いが緩やかになります。',
      commonMistake:
          '「スーテッドコネクターはどこでも儲かる」と覚えてしまうミスです。'
          'このハンドの利益は、ポジションと値段の条件が揃ってはじめて出ます。'
          '65s という同じ 2 枚でも、UTG でのオープンと BTN でのオープンでは前提となる後ろの人数も'
          'レーキの重みへの耐性もまったく違い、'
          '「スーテッドコネクターだから」という理由だけで一律にオープンするのは危険です。',
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
          'A5s はエースブロッカーを持ち、コールされてもフラッシュと A2345 に向かえます。'
          'エースを 1 枚持っていることで、相手の AA・AK という 4Bet に強く反応してくる組み合わせの一部を'
          '先に減らしたうえで攻められるため、同じ「弱いハンドからの 4Bet」でもブロッカーのないハンドより'
          '実現できる効果が大きくなります。',
      practicalView:
          '相手が 4Bet にほとんど降りないタイプなら、この 4Bet は成立しません。'
          'その場合は素直にフォールドします。'
          '4Bet ブラフは「相手が降りる」ことが前提の動きです。'
          '相手の 3Bet レンジが広く、しかも 4Bet への耐性も低いタイプであるほどこの 4Bet の成功率は上がり、'
          '逆に 3Bet をバリュー中心にしか打たない相手には、A5s で無理に攻めてもコールされたときに苦しい展開が待っています。',
      commonMistake:
          '4Bet ブラフに 76s のような「降ろせても価値のない」ハンドを選ぶミスです。'
          'ブロッカーがないハンドは、相手が続行する確率をまったく下げられません。'
          '4Bet ブラフの候補を選ぶ基準は「自分がどれだけ強く見えるか」ではなく'
          '「相手の強いレンジをどれだけ減らせるか」であり、'
          'この基準を取り違えると、ブラフのはずが相手の強いレンジをそのまま残してしまうことになります。',
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
          'ここで動かないと、UTG のアクションを待つ側に回ることになります。'
          'コールしてしまうと、UTG がそのまま降りるか、あるいはさらに 4Bet してくるかを見届けなければならず、'
          'AKo というハンドで主導権を渡したまま 2 人の反応を待つ不安定な立場に置かれます。',
      practicalView:
          'CO が UTG のオープンに対してタイトにしか 3Bet しない相手なら、'
          'AKo でもコールに寄せる判断がありえます。'
          '3Bet レンジの広さがそのまま答えを動かします。'
          'CO のスクイーズが AA・KK・QQ・AK にほぼ限定されると読める場合、'
          'AKo は五分に近い勝負になるため、無理に 4Bet でポットを膨らませず、'
          'コールしてポジションとフロップの情報を活かす選択も十分成立します。',
      commonMistake:
          'AK を「コールして様子を見る」ハンドとして扱うミスです。'
          '3 人が絡む場面でコールすると、最も避けたい'
          '「弱いレンジのまま多人数でフロップ」という形になります。'
          'UTG がまだ控えている状態でコールすると、UTG にも安いオッズでの続行や再レイズの機会を与えてしまい、'
          'AKo が本来持っている「レイズで主導権を取り切る」強みを自分から手放すことになります。',
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
          '必要な取り分の目安は、支払う額のおよそ 10〜15 倍です。'
          'タイトな UTG のオープンレンジはオーバーペアや AK 系のトップペアに偏りやすく、'
          'セットになったハンドをそのまま隠しやすい形になるため、'
          '55 はこうした相手にこそ「大きく払わせられる」条件が揃います。',
      practicalView:
          '同じ 55 でも有効スタックが 40BB しかなければ、'
          'セットになっても取れる額が足りずフォールドが正解になります。'
          '深さがそのまま答えを変える代表例です。'
          '200BB のように極端に深いスタックでは、セット後にさらに複数ストリートでベットを重ねられる余地が生まれるため、'
          '55 のような小さいペアの価値はスタックが深くなるほど加速度的に上がっていきます。',
      commonMistake:
          '3Bet してしまうミスです。'
          '55 で 3Bet すると、降りるのは 55 に負けている手ばかりで、'
          '続けてくるのは 55 が勝てないハンドばかりになります。'
          'タイトな UTG は 3Bet に対してさらにタイトに絞って応じてくるため、'
          '55 が最も避けたいオーバーペアや AK 系との対決だけが残り、'
          'しかもセットを狙うという本来のプランも実行できなくなります。',
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
          '強いレンジ相手に不利なポジションから戦うのは不利が重なります。'
          '99 はコールで参加したことで、それ以上のペアや AK といった強いハンドはレイズしていたはずだという'
          '情報を相手に与えてしまっており、その状態でスクイーズに再度お金を払うのは、'
          '弱いと読まれたレンジのまま強く打ち返すという矛盾した動きになります。',
      practicalView:
          'BTN が明らかにスクイーズを多用する相手なら、'
          '99 で 4Bet して降ろしにいく調整もありえます。'
          'ただしその場合も、コールで受けるのは避けます。'
          'スクイーズの手が広いと分かっている相手には、フォールドかブラフの 4Bet かの二択で対応し、'
          '中途半端にコールしてポジションの悪いフロップに進むという選択肢自体を検討から外します。',
      commonMistake:
          '「ポケットペアだからセットを見にいく」と機械的にコールするミスです。'
          'セット狙いが成立するかどうかは、値段と残りスタックの比で決まります。'
          'ここでは 9.5BB 払って残り有効スタックが約 88BB しかなく、'
          'セット後に狙える利益の上限がすでに低くなっているうえ、'
          'HJ という不利なポジションと弱いレンジを晒した状態が重なり、セットを見にいくだけの土台が整っていません。',
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
          '不利なポジションではその差がさらに広がります。'
          'Q8o が Q や 8 でペアを作っても、タイトな UTG のレンジには'
          'AQ・KQ・QJ のようなクイーンで上回るハンドや、それ以上のオーバーペアが多く含まれているため、'
          '見た目のペアの強さほど実際の勝率は伸びません。',
      practicalView:
          '同じ Q8o でも、相手が BTN から広くオープンしている場面なら守れます。'
          '相手のレンジが狭いほど、支配される危険が増します。'
          'BTN の広いオープンには Q9o や QTo、あるいはそれ以下のハンドまで含まれるため、'
          'Q8o が優位に立てる組み合わせが十分残っていますが、'
          'タイトな UTG ではそうした「Q8o が勝てる相手」がほとんど姿を消します。',
      commonMistake:
          'ポットオッズの計算だけで判断してしまうミスです。'
          '計算はあくまで出発点で、'
          'その勝率をフロップ以降で実際に取れるかどうかまで含めて考えます。'
          '必要勝率だけを満たしているからとコールを続けると、タイトな相手に対して繰り返し'
          '「当たっても負けている」形でチップを投入することになり、'
          '長期的にはポットオッズ通りの結果を得られません。',
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
          '65s のような「作れば圧倒的に強い」ハンドは価値を上げます。'
          '参加人数が増えるほど、誰かがトップペアやオーバーペアを持っている確率も上がるため、'
          'ハイカード止まりのハンドはショーダウンで勝ちにくくなる一方、'
          '65s のようにストレートやフラッシュという「誰にも負けにくい」完成形を作れるハンドは、'
          '支払ってくれる相手の頭数が増えるぶん見返りも大きくなります。',
      practicalView:
          'ブラインドがスクイーズを多用する相手なら、'
          '2.5BB のつもりが 14BB になる危険があるためコールの価値が下がります。'
          'すでに 3 人がポットに絡んでいるとはいえ、スクイーズが入ればその全員がフォールドか大きなコールを'
          '迫られる展開になり、65s のような「安く見て大きく取る」ハンドの前提そのものが崩れてしまいます。',
      commonMistake:
          '「人数が多いから強い手だけで参加する」と一律に締めてしまうミスです。'
          '締めるべきは支配されやすいオフスートのブロードウェイで、'
          'スーテッドコネクターは逆に価値が上がります。'
          'KQo や AJo のようなハンドは多人数戦でキッカー勝負やドミネートされるリスクが増す一方、'
          '65s のようなハンドはむしろ支払ってくれる相手が増えることで得をするため、'
          '「多人数だから絞る」という発想を一律に当てはめると本来参加すべきハンドまで逃してしまいます。',
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
          'ないときは大きめ（4 倍以上）にして、相手のコール範囲を狭めます。'
          'BB は 3Bet 後もフロップ以降ずっと先に動く側になるため、ポジションの不利をサイズで補う必要があり、'
          'QQ のような強いハンドであっても、ポジションがない場面では大きめのサイズで'
          '相手のコール範囲を絞り込むことが重要になります。',
      practicalView:
          '相手が 3Bet にほとんど降りないタイプなら、'
          'QQ のような強いハンドではサイズをさらに上げてバリューを取りにいきます。'
          '逆に 3Bet にすぐ降りてしまう相手には、QQ というハンドの強さを活かしきれずにポットを取り切ってしまう'
          'ことになるため、相手のコールする傾向を見ながらサイズを微調整していく意識が必要です。',
      commonMistake:
          '5BB のような小さい 3Bet にしてしまうミスです。'
          'BTN は良いオッズとポジションの両方を得るため、'
          '広いレンジで気軽にコールしてきます。'
          'ポジションを持つ相手に安いオッズまで与えてしまうと、QQ のような強いハンドであっても'
          '多くの弱いハンドにフロップで居座られ、ポジションの不利な BB 側がフロップ以降ずっと'
          '難しい判断を強いられ続けることになります。',
      relatedRangeSpotId: '6max_bb_defense',
    ),
  ];
}
