import '../../../../shared/models/position.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/models/table_type.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';
import 'quiz_builder.dart';

/// ターンの出題。
///
/// 前提（テーブル・有効スタック・ポジション・相手タイプ）を必ず明示し、
/// 正解がその前提から導けるスポットだけを扱う。
abstract final class TurnQuizzes {
  static List<Quiz> get all => _quizzes;

  static Quiz _q({
    required String id,
    required QuizDifficulty difficulty,
    Street street = Street.turn,
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
      category: QuizCategory.turn,
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
      id: 'tn001',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Kd',
      board: 'Kc 7s 2h 5d',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: BB check',
        'ターン時点のポットは 12BB',
      ],
      question: '6MAX・100BB。K72 の後、ターンに 5。AK のトップペア・トップキッカーでどうしますか。',
      choices: ['Check', 'Bet', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          '5 は相手のレンジをほとんど助けないカードです。'
          'AK は今も最上位クラスなので、'
          'K7・77・55・フラッシュドローなどから 2 回目のバリューを取ります。',
      gtoView:
          'ターンで打つかどうかは「そのカードで相手のレンジが強くなったか」で決めます。'
          '5 は相手の 5x をわずかに増やすだけで、'
          'こちらの優位はほとんど変わっていません。',
      practicalView:
          '相手がフロップのコール後に降りやすいタイプなら、'
          'ターンのベットで多くのポットを取れます。'
          '逆に降りない相手なら、純粋にバリューを取る目的になります。',
      commonMistake:
          '「フロップで打ったから十分」と 1 回で止めてしまうミスです。'
          'ポットは 3 回打ってはじめて大きくなります。',
    ),
    _q(
      id: 'tn002',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Qc Jd',
      board: 'Kh 8h 3c 2h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: ハートが 3 枚目。BB check',
      ],
      question: '6MAX・100BB。ターンでハートが 3 枚になりました。QJ（ハート無し）でどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          'フロップをコールしたレンジにはハートのドローが多く含まれ、'
          'その多くがターンで完成しています。'
          'こちらは何も無く、打っても降りてくれる相手が減っています。',
      gtoView:
          'ドローが完成するカードは、'
          'コールしていた側のレンジを一気に強くします。'
          '相手が強くなったカードでブラフを増やすのは逆方向の動きです。',
      practicalView:
          'ハートを 1 枚持っていれば話が変わります。'
          '相手がフラッシュを持つ組み合わせを減らせるうえ、'
          'リバーで自分が完成する可能性も残るからです。',
      commonMistake:
          '「怖いカードだから相手も降りるはず」と考えるミスです。'
          '怖いカードは、相手がすでに完成しているカードでもあります。',
    ),
    _q(
      id: 'tn003',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Qh',
      board: 'Kh 8h 3c 2d',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。ナッツフラッシュドロー + A のオーバーカードです。ターンでどうしますか。',
      choices: ['Check', 'Bet', 'Fold', '無料でリバーを見る'],
      correctIndex: 1,
      shortReason:
          'ハート 9 枚に加え、A の 3 枚でも勝てる可能性があります。'
          '降ろせれば良し、コールされても'
          '完成したときに大きなポットを取れる準備になります。',
      gtoView:
          'エクイティの高いドローは、'
          'バリューハンドと同じタイミングで打つことで'
          'レンジ全体のバランスが取れます。'
          'こちらのベットが「強い手だけ」にならずに済みます。',
      practicalView:
          '相手が K をなかなか降ろさないタイプなら、'
          '狙いは「降ろす」ではなく'
          '「フラッシュが完成したときに大きく払わせる」に変わります。',
      commonMistake:
          'ドローだから無料でリバーを見よう、とチェックしてしまうミスです。'
          'ターンでポットを大きくしておかないと、'
          '完成したリバーで取れる額が小さくなります。',
    ),
    _q(
      id: 'tn004',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Jd Ts',
      board: 'Ah 7c 4d 2s',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → CO bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。JT ハイでドローもありません。ターンでどうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          'エクイティもブロッカーもありません。'
          'A742 というボードで JT が次に強くなる道はほぼ無く、'
          '打ち続ける材料がありません。',
      gtoView:
          'ブラフに選ばれるのは、'
          'エクイティが残っているハンドか、'
          '相手の強い手を減らすブロッカーを持つハンドです。'
          'JT はそのどちらでもありません。',
      practicalView:
          '相手がフロップのコールから降りやすいタイプなら、'
          'ターンのブラフも成立します。'
          'ただしその場合も「何を降ろしたいのか」は明確にしてください。',
      commonMistake:
          '「フロップで打ったからターンも打つ」という惰性のブラフです。'
          '打ち続ける理由が無いなら、'
          'そこで止めるのが一番安く済みます。',
    ),
    _q(
      id: 'tn005',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh 9h',
      board: 'Ah 5h 2c 8d',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: BB check → BTN bet 3BB',
      ],
      question: '6MAX・100BB。ポット 12BB に 3BB（1/4）のベット。フラッシュドローでどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          '必要勝率は 3 ÷（12 + 3 + 3 ＝ 18）＝ 約17%。'
          'ターン 1 枚での完成率は約19% なので、'
          'これだけでコールが成立します。',
      gtoView:
          '小さいベットは、そのまま良いオッズを与えます。'
          '同じフラッシュドローでも、'
          '大きいベットなら降りる場面がここでは受けられます。',
      practicalView:
          '完成したリバーで追加のバリューが取れることを考えると、'
          '実際にはさらに有利なコールです。'
          '相手にスタックが残っているほど、この上乗せが効きます。',
      commonMistake:
          'ベットサイズを見ずに「ターンのドローは降りる」と'
          '決めてしまうミスです。'
          '1/4 ポットと 3/4 ポットでは、必要勝率が倍以上違います。',
    ),
    _q(
      id: 'tn006',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '9c 8c',
      board: 'Th 7d 2s 6h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: 6 でストレートが完成'],
      question: '6MAX・100BB。ターンの 6 で 98 のストレートが完成しました。BB のあなたはどうしますか。',
      choices: ['Check（相手に打たせる）', 'Bet', 'Fold', '様子を見る'],
      correctIndex: 1,
      shortReason:
          'ストレートは今ほぼ最強です。'
          'ボードにハートが 2 枚あり、'
          'Tx や 7x のペア、ドローから払ってもらえるうちに打ちます。',
      gtoView:
          '強い手を持ったときの目標は、'
          '残り 2 ストリートでできるだけ大きなポットを作ることです。'
          'ターンでチェックすると、その機会を 1 回失います。',
      practicalView:
          '相手がとても攻撃的で、'
          'チェックすればほぼ確実に打ってくるタイプなら、'
          'チェックして相手のブラフを取る選択も生きます。'
          '相手が受け身なら、必ず自分から打ちます。',
      commonMistake:
          '「完成したから隠したい」とチェックしてしまうミスです。'
          '相手がハートを持っていた場合、'
          'ただでリバーを見せていることになります。',
    ),
    _q(
      id: 'tn007',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Qh Qs',
      board: '8c 5d 2h 8s',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: 8 でボードがペアに。BB check',
      ],
      question: '6MAX・100BB。ターンでボードが 8 のペアになりました。QQ でどうしますか。',
      choices: ['Check', 'Bet', 'Fold', '相手のベットを待つ'],
      correctIndex: 1,
      shortReason:
          '8 は 4 枚のうち 2 枚が見えているので、'
          '相手が 8 を持っている組み合わせはごくわずかです。'
          'QQ はほぼ勝っており、5x やドローから払ってもらえます。',
      gtoView:
          'ボードがペアになったとき、'
          'そのランクを持っている組み合わせは半分に減ります。'
          '見た目の怖さと、実際の危険度は一致しません。',
      practicalView:
          'ボードがペアになると相手が慎重になりやすいので、'
          'サイズを少し落としてコールしてもらいやすくする調整が有効です。',
      commonMistake:
          '「ペアになった＝相手がスリーカードかも」と'
          '止まってしまうミスです。'
          '組み合わせを数えれば、その可能性は小さいと分かります。',
    ),
    _q(
      id: 'tn008',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ad Jc',
      board: '9h 6c 3d Jd',
      potBb: 5.5,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN も check（何も無かった）',
        'ターン: J でトップペアに。BB check',
      ],
      question: '6MAX・100BB。フロップをチェックで回し、ターンの J でトップペアになりました。どうしますか。',
      choices: ['Check', 'Bet', 'Fold', 'もう一度 Check'],
      correctIndex: 1,
      shortReason:
          'トップペア・トップキッカー相当まで強くなりました。'
          '相手のレンジは「フロップで打たれなかったので弱い手も残っている」状態で、'
          '9x や 6x から払ってもらえます。',
      gtoView:
          'フロップでチェックしたことで、'
          'こちらのレンジには弱い手も強い手も残っています。'
          'その状態からターンで打つのは自然な形で、'
          '相手からは読みにくくなります。',
      practicalView:
          'フロップでチェックした後にターンで打つ動きは、'
          '相手のレンジが弱いままなので成功率が高くなります。'
          '意識して使えると、チェックの価値が上がります。',
      commonMistake:
          '「フロップで打たなかったから、もう打てない」と'
          '思い込んでしまうミスです。'
          '手が強くなったターンは、打ち始める絶好の場面です。',
    ),
    _q(
      id: 'tn009',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kd Qc',
      board: 'Kc 8h 4s 7d',
      potBb: 12,
      villainProfile: VillainProfile.nit,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: BB check → CO bet 8BB → BB raise to 26BB',
      ],
      question: '6MAX・100BB。タイトな BB にターンでチェックレイズされました。KQ のトップペアでどうしますか。',
      choices: ['Fold', 'Call', 'Re-raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          'タイト・パッシブな相手のターンでのチェックレイズは、'
          'ツーペア以上に強く偏ります。'
          'トップペアではその大半に負けています。',
      gtoView:
          'チェックレイズという行動は、'
          '本来ブラフとバリューが混ざっているものです。'
          'しかしブラフをしない相手なら、'
          'その行動はバリューだけを意味します。',
      practicalView:
          '同じチェックレイズでも、'
          '相手がルース・アグレッシブなら受ける場面です。'
          '相手のタイプが答えを 180 度変えるスポットです。',
      commonMistake:
          '「トップペアは強いから」と払ってしまうミスです。'
          '強さは相対的で、相手のレンジと比べてはじめて決まります。',
    ),
    _q(
      id: 'tn010',
      difficulty: QuizDifficulty.beginner,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '7h 6h',
      board: 'Kd 9h 4c 2s',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。ターンでフラッシュドローも消え、76s は何も残っていません。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          'フロップではハートのバックドアがありましたが、'
          'ターンの 2s でその可能性も消えました。'
          'ドローもブロッカーも無く、打ち続ける材料がありません。',
      gtoView:
          'すべてのブラフを最後まで続ける必要はありません。'
          'ターンで「どのブラフを捨てるか」を決めるのが、'
          'そのままレンジ構成になります。'
          '一番弱いものから捨てます。',
      practicalView:
          'チェックすれば、リバーで相手も何も無いときに'
          '7 ハイのまま勝てる回がわずかに残ります。'
          'ブラフを続けるより価値があります。',
      commonMistake:
          '「一度打ったから引けない」と続けてしまうミスです。'
          '打ち続けるかどうかは、'
          'そのカードで自分の状況が良くなったかどうかで決めます。',
    ),
    _q(
      id: 'tn011',
      difficulty: QuizDifficulty.beginner,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Qd Jd',
      board: '9c 6h 3s Ad',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: A が落ちた。BB check',
      ],
      question: '6MAX・100BB。ターンで A が落ちました。QJ（ダイヤのバックドア付き）でどうしますか。',
      choices: ['Check', 'Bet', 'Fold', '諦めて Check'],
      correctIndex: 1,
      shortReason:
          'A はこちらのレンジ（オープンした側）には多く、'
          '相手のフロップコールレンジには少ないカードです。'
          '9x や 6x のペアで受けていた相手は、'
          'A に対して降りざるを得なくなります。',
      gtoView:
          'ターンで打つかどうかは、'
          'そのカードがどちらのレンジを強くしたかで決めます。'
          '高いカードはレイズした側のレンジを強くするため、'
          'ブラフの成功率が上がります。',
      practicalView:
          'ダイヤをもう 1 枚引けばフラッシュドローになるので、'
          'リバーで打ち続ける材料も増えます。'
          '降ろせなかった場合の保険があります。',
      commonMistake:
          '「A が落ちて自分も当たっていないから諦める」と'
          '考えてしまうミスです。'
          '重要なのは、そのカードで相手が困るかどうかです。',
    ),
    _q(
      id: 'tn012',
      difficulty: QuizDifficulty.beginner,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Jh Th',
      board: '9c 8d 2s Ks',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: BB check → BTN bet 9BB',
      ],
      question: '6MAX・100BB。ポット 12BB に 9BB（3/4）のベット。オープンエンド（8 アウツ）でどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 0,
      shortReason:
          '必要勝率は 9 ÷（12 + 9 + 9 ＝ 30）＝ 30%。'
          'ターン 1 枚での完成率は 8 アウツで約17% しかなく、大きく足りません。',
      gtoView:
          'ターンは「必要勝率が上がる一方で、'
          '残りのカードが 1 枚に減る」ストリートです。'
          'フロップで受けられたドローの多くが、ターンでは受けられなくなります。',
      practicalView:
          '完成したときに相手から追加で取れる額を足しても、'
          'この差を埋めるのは簡単ではありません。'
          '相手が浅いスタックならなおさら降りる寄りです。',
      commonMistake:
          'フロップで使った「アウツ×4」を'
          'ターンでも使ってしまうミスです。'
          'ターンでは×2 で、完成率は半分になります。',
    ),
    // ── 中級 ──────────────────────────────────────────────
    _q(
      id: 'tn013',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Qs Js',
      board: 'Ks Ts 5d 3h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。QJs でストレートドロー + フラッシュドロー。ターンの狙いはどれですか。',
      choices: [
        'バリューベット（今が最強のつもりで打つ）',
        'セミブラフ（降ろす + 完成したときの準備）',
        'ポットコントロールのチェック',
        'ブラフキャッチのためのチェック',
      ],
      correctIndex: 1,
      shortReason:
          'QJs は今は QJ ハイですが、'
          'A・9・スペードのどれかで一気に最強クラスになります。'
          '降ろせれば良し、コールされても次で逆転できる形です。',
      gtoView:
          'セミブラフは「相手が降りる利益」と'
          '「降りなかったときに完成する利益」の両方から成り立ちます。'
          'ブラフの中でも優先度が高いのはこのためです。',
      practicalView:
          '相手がまったく降りないタイプなら、'
          'フォールドエクイティは期待できません。'
          'その場合は「完成したときのポットを育てる」目的だけで打つことになります。',
      commonMistake:
          'セミブラフを「ただのブラフ」と考えて、'
          'コールされた瞬間に諦めてしまうミスです。'
          '完成する可能性が残っているうちは、まだ終わっていません。',
    ),
    _q(
      id: 'tn014',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ac Qd',
      board: 'Jd 8c 3s 4h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: 4 が落ちた。BB check',
      ],
      question: '6MAX・100BB。ターンの 4 で AQ ハイのまま。2 回目のベットをどうしますか。',
      choices: ['Check', 'Bet 66%', 'Bet 120%（オーバーベット）', 'All-in'],
      correctIndex: 0,
      shortReason:
          '4 は誰のレンジも変えていない「無関係なカード」です。'
          '相手のレンジは J8 のフロップをコールした強めのままで、'
          'AQ には降ろす力もドローもありません。',
      gtoView:
          '2 回目のベットは、'
          '「そのカードで相手のレンジが弱くなったか」が判断基準になります。'
          '何も変わらないカードでは、ブラフの成功率も変わりません。',
      practicalView:
          'A や K が落ちていれば話は別で、'
          'そのときは相手の Jx が苦しくなるため打てます。'
          'AQ は 6 アウツのショーダウンバリューを残してチェックします。',
      commonMistake:
          '「フロップで打ったからターンも打つ」と'
          'カードを見ずに続けてしまうミスです。'
          'どのカードが自分に味方したかを毎回確認します。',
    ),
    _q(
      id: 'tn015',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ah Jc',
      board: 'Jh 9c 5d 7s',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。AJ のトップペアですが、ターンで 7 が落ちました。どうしますか。',
      choices: ['Check', 'Bet 33%', 'Bet 75%', 'All-in'],
      correctIndex: 0,
      shortReason:
          '7 で 86 や T8 のストレートが完成し、'
          'さらに 68・T8 のドローも増えました。'
          'AJ は勝っている相手からしか払ってもらえず、'
          '打つとレイズされたときに困ります。',
      gtoView:
          '中程度の強さのハンドは、'
          'ポットを小さく保ったままショーダウンに向かうのが基本です。'
          '打つほど「勝っている相手は降り、負けている相手が残る」構造になります。',
      practicalView:
          'チェックすれば、相手のブラフを受けることもできます。'
          'AJ は降りるには強すぎ、大きなポットを作るには弱すぎる、'
          'ちょうど中間のハンドです。',
      commonMistake:
          '「トップペアだから毎回打つ」と決めてしまうミスです。'
          'ボードが伸びたぶんだけ、トップペアの相対的な強さは落ちています。',
    ),
    _q(
      id: 'tn016',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: '6s 5s',
      board: '9s 7d 2c 8h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → BTN bet 33% → BB call', 'ターン: 8 でストレートが完成'],
      question: '6MAX・100BB。ターンの 8 で 65s のストレートが完成。BB のあなたはどうしますか。',
      choices: ['Check（相手に打たせる）', 'Bet（リード）', 'Fold', 'ポットコントロール'],
      correctIndex: 1,
      shortReason:
          '9872 は BB のレンジにしか無い完成形（65・T6・JT）が多いボードです。'
          '相手はストレートを持ちにくいので、'
          '自分から打ってポットを育てにいきます。',
      gtoView:
          '「自分のレンジにしか無い強い形」がある状況を'
          'ナッツ有利と呼びます。'
          'ナッツ有利がある側は、'
          '不利なポジションからでも自分から打つ理由があります。',
      practicalView:
          'チェックすると、'
          '相手も 9x でポットコントロールしてきて'
          '何も起きないまま進む回が増えます。'
          '打たないとポットが育ちません。',
      commonMistake:
          '「BB は常にチェックから」と機械的に進めてしまうミスです。'
          'ボードによっては、自分から打つほうが利益になります。',
    ),
    _q(
      id: 'tn017',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kc Kd',
      board: '9h 8h 4c 7h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: ハートが 3 枚目。BB が自分から 9BB をベット',
      ],
      question:
          '6MAX・100BB。ターンでフラッシュが完成しうるボードで BB がリードしてきました。KK（ハート無し）でどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          'KK はフラッシュとストレートに負けていますが、'
          '相手のリードレンジにはブラフとドローも含まれます。'
          '必要勝率は 9 ÷ 30 ＝ 30% で、'
          'オーバーペアはまだそれを満たす見込みがあります。',
      gtoView:
          '相手がリードしてくるボードでは、'
          'こちらのレンジは受けに回ります。'
          'その中でオーバーペアは上位のブラフキャッチャーで、'
          '降りるには強すぎます。',
      practicalView:
          'レイズはしません。'
          'レイズすると、相手のブラフは降り、'
          'フラッシュだけが残って大きく払うことになります。',
      commonMistake:
          '「KK だから強い」とレイズしてしまうミスです。'
          'このボードで KK は守るハンドであって、攻めるハンドではありません。',
    ),
    _q(
      id: 'tn018',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ah 5c',
      board: 'Kh Qh 6d 2s',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → CO bet 33% → BB call', 'ターン: BB check'],
      question: '6MAX・100BB。A5o で何も当たっていません。Ah を持っていることの意味はどれですか。',
      choices: [
        'A が落ちればトップペアになるので価値がある',
        '相手のハートのフラッシュドローを減らしているので、ブラフが通りやすい',
        'A はどのボードでも強いカードだから',
        'Ah は次のカードに影響しない',
      ],
      correctIndex: 1,
      shortReason:
          'Ah を自分が持っていることで、'
          '相手が Ah を含むフラッシュドローを持つ可能性が消えます。'
          '相手の続行レンジが減るぶん、ブラフの成功率が上がります。',
      gtoView:
          'ブロッカーは「相手が何を持てるか」を直接削る道具です。'
          '相手が最も強く続行する部分'
          '（ここではナッツフラッシュドロー）を減らせるハンドが、'
          '最も良いブラフ候補になります。',
      practicalView:
          '相手がハートを追いかけるタイプであるほど、'
          'この効果は大きくなります。'
          'フラッシュドローで受けている相手を降ろせないなら、'
          'ブロッカーの価値も下がります。',
      commonMistake:
          'ブロッカーを「自分が当たる可能性」と混同するミスです。'
          'ブロッカーの価値は、自分が当たることではなく'
          '相手が持てなくなることにあります。',
    ),
    _q(
      id: 'tn019',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.bb,
      villain: Position.co,
      heroCards: 'Ac Kh',
      board: 'Ad 9s 4c 6h',
      potBb: 40,
      stackBb: 60,
      villainProfile: VillainProfile.reg,
      history: [
        'BB（あなた）が 3Bet、CO がコール',
        'フロップ: BB bet → CO call',
        'ターン: ポット 40BB / 残りスタック 60BB（SPR 1.5）',
      ],
      question: '6MAX。3Bet ポットのターンで SPR 1.5、AK のトップペア・トップキッカーです。方針はどれですか。',
      choices: [
        'チェックしてポットコントロールする',
        'ベットして、リバーでスタックが入る形を作る',
        '小さく打って安く進める',
        'リバーまで待ってから打つ',
      ],
      correctIndex: 1,
      shortReason:
          'SPR 1.5 なので、'
          'ターンとリバーで打てばちょうどスタックが入ります。'
          'AK は 3Bet ポットのこの深さでは十分に強く、'
          'スタックを入れにいくハンドです。',
      gtoView:
          '浅い SPR では、'
          '「どのハンドでスタックを入れるか」を先に決めておくのが基本です。'
          'AK のトップペア・トップキッカーは、その基準の上側に入ります。',
      practicalView:
          'ここでチェックすると、'
          'リバーで一気に大きく打つしかなくなり、'
          '相手が降りやすくなります。'
          '2 回に分けたほうが、相手も付いてきやすくなります。',
      commonMistake:
          '100BB の感覚のままポットコントロールしてしまうミスです。'
          'SPR 1.5 では、コントロールする余地がそもそもありません。',
    ),
    _q(
      id: 'tn020',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ts 9s',
      board: 'Kd 7c 3h 7s',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: 7 でボードがペアに。BB check',
      ],
      question: '6MAX・100BB。ターンでボードが 7 のペアになりました。T9s（何も無し）でどうしますか。',
      choices: ['Check', 'Bet', 'Fold', '諦めて Check'],
      correctIndex: 1,
      shortReason:
          'ボードがペアになると、'
          '相手の 3x や小さいポケットペアは'
          '「フルハウスに負けているかもしれない」という不安を抱えます。'
          'ブラフが通りやすくなるカードです。',
      gtoView:
          'ペアになったカードは、'
          '両者ともに強い完成形を作りにくくします。'
          'その状況では、'
          '先に攻めている側（レンジが強い側）が押しやすくなります。',
      practicalView:
          '相手が「ペアボードでは降りない」と決めているタイプなら'
          'このブラフは機能しません。'
          'ただし多くのプレイヤーは、'
          'ボードがペアになると弱い手を手放しやすくなります。',
      commonMistake:
          '「7 が来て自分は何も無いから諦める」と考えるミスです。'
          '自分が当たったかではなく、相手が困ったかで判断します。',
    ),
    _q(
      id: 'tn021',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '5c 5d',
      board: 'Kh 5s 2h 9h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: ハートが 3 枚目に。BB check',
      ],
      question: '6MAX・100BB。セット（555）ですが、ターンでハートが 3 枚になりました。どうしますか。',
      choices: ['Check', 'Bet', 'Fold', '安全に Check'],
      correctIndex: 1,
      shortReason:
          'フラッシュには負けていますが、'
          '相手のレンジの大半はまだ Kx やペアです。'
          'しかもリバーでボードがペアになればフルハウスで逆転できます。'
          '打って払わせ、フラッシュドローを降ろします。',
      gtoView:
          'セットは「今負けている相手が限られていて、'
          'かつ逆転する手段も残っている」強いハンドです。'
          'フラッシュが完成しうるボードでも、'
          '打つ理由のほうが大きくなります。',
      practicalView:
          'レイズされたら考え直します。'
          'ただしこちらから打たなければ、'
          'フラッシュドローの相手にただでリバーを見せることになります。',
      commonMistake:
          '「3 枚目が落ちたから危ない」と'
          '止まってしまうミスです。'
          '相手がフラッシュを完成させている組み合わせは、レンジのごく一部です。',
    ),
    _q(
      id: 'tn022',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Ac Th',
      board: '8c 6d 3s Kd',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: K が落ちた。BB check',
      ],
      question: '6MAX・100BB。863 の後、ターンで K。AT ハイでどうしますか。',
      choices: ['Check', 'Bet', 'Fold', 'ドローが無いので Check'],
      correctIndex: 1,
      shortReason:
          'K はこちらのレンジ（BTN のオープン）には多く含まれ、'
          '相手のフロップコールレンジには少ないカードです。'
          '8x や 6x のペアで受けていた相手が、'
          'K に対して続けにくくなります。',
      gtoView:
          'ターンで打つかどうかは、'
          '「そのカードが自分のレンジと相手のレンジのどちらを強くしたか」で決めます。'
          '高いカードは、レイズした側のレンジを強くします。',
      practicalView:
          'A のオーバーカードも残っているので、'
          'コールされてもリバーで A が落ちれば勝てる回があります。'
          '完全なブラフではありません。',
      commonMistake:
          '「自分が K を持っていないから打てない」と考えるミスです。'
          'ベットの根拠は、'
          '相手が K を持ちにくいというレンジの話です。',
    ),
    _q(
      id: 'tn023',
      difficulty: QuizDifficulty.intermediate,
      hero: Position.co,
      villain: Position.bb,
      heroCards: '9d 8d',
      board: 'Ks Qh 4c 2s',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: ['フロップ: BB check → CO bet 33% → BB call', 'ターン: BB check'],
      question:
          '6MAX・100BB。ターンで 98s は完全に何も無くなりました。'
          'ブラフを続けるかどうかの判断基準として最も適切なものはどれですか。',
      choices: [
        '自分がここまで打った額が大きいので、取り返すために続ける',
        '次のカードで強くなれる可能性があるか、相手の強い手を減らせているかで決める',
        'ブラフは一度始めたら最後まで続ける',
        'ポットが大きいので必ず続ける',
      ],
      correctIndex: 1,
      shortReason:
          '98s はストレートドローもフラッシュドローも無く、'
          'K も Q もブロックしていません。'
          '続ける材料がないので、ここで止めるのが正しい判断です。',
      gtoView:
          'ブラフを続けるハンドは、'
          '「エクイティが残っている」か'
          '「相手の続行レンジを減らしている」かで選びます。'
          'どちらも無いものから順に捨てていきます。',
      practicalView:
          '同じ状況でも QJ を持っていれば、'
          'ガットショットと K・Q のブロッカーがあるので続けられます。'
          '手札によって、続けるか止めるかが変わります。',
      commonMistake:
          'すでに入れた額を理由に続けてしまうミスです。'
          '過去に払った分は取り戻せず、判断材料になりません。',
    ),
    // ── 上級 ──────────────────────────────────────────────
    _q(
      id: 'tn024',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: 'Kc Kh',
      board: 'Kd 8s 3c 6h',
      potBb: 24,
      stackBb: 76,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet → BB call',
        'ターン: ポット 24BB / 残りスタック 76BB。BB check',
      ],
      question:
          '6MAX。セット（KKK）でポット 24BB、残り 76BB。リバーでスタックを入れ切るには、ターンでいくら打つべきですか。',
      choices: ['6BB', '12BB', '24BB', '76BB（オールイン）'],
      correctIndex: 2,
      shortReason:
          'ターンで 24BB 打ってコールされると、'
          'ポットは 72BB、残りスタックは 52BB になります。'
          'リバーでほぼポットサイズのオールインになり、自然に入り切ります。',
      gtoView:
          '一番強い手を持ったときは、'
          '「残り 2 ストリートで無理なくスタックを入れる」逆算をします。'
          '各ストリートで同じくらいの割合を打つのが、最も自然な積み上げ方です。',
      practicalView:
          '6BB のような小さいベットにすると、'
          'リバーで残り 70BB をポット 36BB に打つことになり、'
          '不自然なオールインになって相手が降りやすくなります。',
      commonMistake:
          '各ストリートを別々に考えてしまうミスです。'
          'ターンのサイズは「リバーでいくら残るか」から逆算して決めます。',
    ),
    _q(
      id: 'tn025',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Ah 7h',
      board: 'Kh 9h 4c 2d',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: BB check → BTN bet 8BB',
      ],
      question: '6MAX・100BB。ターンで打たれました。ナッツフラッシュドロー（Ah7h）でどうしますか。',
      choices: ['Fold', 'Call', 'Check-Raise to 26BB', 'All-in'],
      correctIndex: 2,
      shortReason:
          'Ah を持っているので、相手がナッツフラッシュドローを持つ可能性を消しています。'
          '完成すれば必ず最強なので、'
          '再レイズされてもエクイティで戦えます。降ろせればそのまま勝ちです。',
      gtoView:
          'レイズのブラフには「降ろせなかったときに困らない」ハンドを選びます。'
          'ナッツフラッシュドローは、'
          '相手の最強ドローをブロックしつつ自分は最強に化けられる、最良の候補です。',
      practicalView:
          '相手がターンのレイズにほとんど降りないタイプなら、'
          'コールに寄せてリバーで安く完成を狙うほうが良い場合もあります。'
          'レイズの価値は、相手が降りるかどうかで決まります。',
      commonMistake:
          'ナッツフラッシュドローを毎回コールで受けてしまうミスです。'
          '一番強いドローをコールに置くと、'
          'レイズレンジがバリューだけになって読まれやすくなります。',
    ),
    _q(
      id: 'tn026',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Ad Kc',
      board: 'Qh 7d 3s Jc',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      question: '6MAX・100BB。Q73 の後ターンで J。AK ハイでどうしますか。',
      choices: ['Check', 'Bet', 'Fold', 'ドローが無いので Check'],
      correctIndex: 1,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: J が落ちた。BB check',
      ],
      shortReason:
          'J でこちらは T のガットショット（AKQJ→T）を持ち、'
          'さらに A・K のオーバーカードも残っています。'
          'J はこちらのレンジ（AJ・KJ・JT）にも当たるカードで、押しやすくなりました。',
      gtoView:
          '同じ「何もペアになっていない」でも、'
          'ガットショットとオーバーカードがあれば'
          'ブラフとして続ける根拠になります。'
          'エクイティがある側が押すのが基本です。',
      practicalView:
          '相手が 7x や 3x で受けていた場合、'
          'Q と J の 2 枚に対して続けるのは苦しくなります。'
          'ブラフの成功率が上がった場面です。',
      commonMistake:
          'ガットショットを「無いも同然」と切り捨てるミスです。'
          'ナッツになるガットショットは、ブラフを続ける十分な理由になります。',
    ),
    _q(
      id: 'tn027',
      difficulty: QuizDifficulty.advanced,
      hero: Position.bb,
      villain: Position.btn,
      heroCards: 'Qh Qd',
      board: 'Ac Kd 8s 5h',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: BB check → BTN bet 9BB',
      ],
      question: '6MAX・100BB。AK8 のボードで QQ。2 回目のベットを受けてどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          '必要勝率は 9 ÷ 30 ＝ 30%。'
          'QQ は Ax・Kx に負けていますが、'
          '相手の 2 回打つレンジにはブラフも含まれます。'
          'ブラフキャッチャーとしては上位で、まだ降りる強さではありません。',
      gtoView:
          'A も K も落ちたボードでは、'
          'QQ は「オーバーペア」ではなく'
          '「相手のブラフにだけ勝てるハンド」に変わっています。'
          '役割が変われば、扱い方も変わります。',
      practicalView:
          'リバーでさらに大きく打たれたら降りる準備をしておきます。'
          'ターンで受けることと、リバーまで受け続けることは別の判断です。',
      commonMistake:
          '「QQ はオーバーペアだから強い」と'
          'ボードを見ずに評価してしまうミスです。'
          'A と K が落ちた時点で、QQ はもう上から 3 番目のペアです。',
    ),
    _q(
      id: 'tn028',
      difficulty: QuizDifficulty.advanced,
      hero: Position.btn,
      villain: Position.bb,
      heroCards: '7h 6h',
      board: 'Kh Qc 5h 2h',
      potBb: 12,
      villainProfile: VillainProfile.looseAggressive,
      history: [
        'フロップ: BB check → BTN bet 33% → BB call',
        'ターン: ハートが 3 枚目。BB check',
      ],
      question: '6MAX・100BB。ターンで下位のフラッシュ（76 のハート）が完成しました。どうしますか。',
      choices: ['Check', 'Bet 33%（小さく）', 'Bet 100%', 'All-in'],
      correctIndex: 1,
      shortReason:
          'フラッシュは完成していますが、'
          'Ah・Jh・Th などを持つ相手には負けています。'
          '小さく打てば、Kx や Qx から払ってもらいつつ、'
          'レイズされたときの損も抑えられます。',
      gtoView:
          '「完成しているが最強ではない」ハンドは、'
          '大きいポットを作りたくないハンドです。'
          'バリューは取りたいが、'
          '上のフラッシュに大きく払いたくないという二つの要求を両立させます。',
      practicalView:
          '相手がルース・アグレッシブでブラフも多いため、'
          'チェックして相手のブラフを受ける選択も有力です。'
          'ただし Kx や Qx から取り逃がすことになります。',
      commonMistake:
          '「フラッシュが完成した」と大きく打ってしまうミスです。'
          '上のフラッシュにだけコールされ、'
          '弱い手はすべて降りるという最悪の結果になります。',
    ),
    _q(
      id: 'tn029',
      difficulty: QuizDifficulty.advanced,
      hero: Position.co,
      villain: Position.bb,
      heroCards: 'Kc Qc',
      board: 'Kd 9h 4s 4d',
      potBb: 12,
      villainProfile: VillainProfile.reg,
      history: [
        'フロップ: BB check → CO bet 33% → BB call',
        'ターン: 4 でボードがペアに。BB check',
      ],
      question:
          '6MAX・100BB。KQ のトップペアで、ターンでボードがペアになりました。'
          'ここでチェックする戦略的な意味はどれですか。',
      choices: [
        'トップペアは弱いので、これ以上ポットを大きくしたくないから',
        'チェックするレンジに強い手も混ぜておかないと、'
            'チェックした瞬間に弱いと決めつけられるから',
        'ボードがペアになると必ずチェックすべきだから',
        '相手が必ず打ってくるので待つべきだから',
      ],
      correctIndex: 1,
      shortReason:
          'ターンで打つ手ばかりを強くしてしまうと、'
          'チェックしたときのレンジが弱い手だけになります。'
          'そうなると、相手はチェックを見た瞬間に安全に攻められます。',
      gtoView:
          'これが「チェックレンジの保護」です。'
          'どの行動を取ったときも'
          'ある程度の強さが混ざっている状態を保つことで、'
          '相手はこちらの行動から情報を得られなくなります。',
      practicalView:
          '相手がこちらのチェックに対してほとんど攻めてこないタイプなら、'
          '保護を気にせず強い手は常に打って構いません。'
          'この考え方が効くのは、観察して攻めてくる相手に対してです。',
      commonMistake:
          '毎回「一番得なアクション」だけを選び続けるミスです。'
          '短期的には正しくても、'
          '行動と手の強さが 1 対 1 で結びつくと読まれます。',
    ),
    _q(
      id: 'tn030',
      difficulty: QuizDifficulty.advanced,
      hero: Position.hj,
      villain: Position.bb,
      heroCards: 'Ah Ks',
      board: 'Kh 8d 5c 3h',
      potBb: 26,
      villainProfile: VillainProfile.reg,
      history: [
        'HJ raise、CO call、BB call の 3 人',
        'フロップ: 全員チェック',
        'ターン: BB check → CO bet 8BB → あなた（HJ）の番',
      ],
      question:
          '6MAX・100BB。3 人のポットで、フロップ全員チェックの後 CO が打ってきました。AK のトップペアでどうしますか。',
      choices: ['Fold', 'Call', 'Raise', 'All-in'],
      correctIndex: 1,
      shortReason:
          'フロップが全員チェックで進んだため、'
          '強い Kx はレンジから減っています。'
          'AK は降りるには強すぎますが、'
          '後ろに BB が残っているのでレイズして大きくするのも危険です。',
      gtoView:
          '多人数のポットでは、'
          'まだ行動していない相手が残っている間はレイズの価値が下がります。'
          '「後ろに何人残っているか」がそのままリスクの大きさです。',
      practicalView:
          'CO が「全員チェックの後は必ず打つ」タイプなら、'
          'そのレンジは広く、AK は明確に勝っています。'
          'それでもレイズせずコールに留めるのは、BB の存在が理由です。',
      commonMistake:
          '2 人のときと同じ感覚でレイズしてしまうミスです。'
          '後ろに 1 人残っているだけで、'
          '「レイズしたら被せられる」という新しいリスクが生まれます。',
    ),
  ];
}
