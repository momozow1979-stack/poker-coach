import '../../domain/trainer_scenario.dart';

/// 設問のそばに置く用語補足。
///
/// 同じ用語を場面ごとに違う言葉で説明するとかえって混乱するため、
/// 説明文はここに集約して使い回す。専門用語で専門用語を説明しないこと。
abstract final class TrainerTerms {
  static const ip = TermNote(
    term: 'IP（インポジション）',
    meaning: '相手より後に行動できる席のこと。相手の出方を見てから決められるぶん有利です。',
  );

  static const oop = TermNote(
    term: 'OOP（アウトオブポジション）',
    meaning: '相手より先に行動しなければならない席のこと。情報が少ないまま決めるので不利です。',
  );

  static const openRaise = TermNote(
    term: 'オープンレイズ',
    meaning: 'まだ誰も参加していないところに、最初にレイズして入ること。',
  );

  static const limp = TermNote(
    term: 'リンプ',
    meaning: 'レイズせず、BB と同じ額のコールだけで参加すること。相手を降ろす機会と主導権を捨てる形になります。',
  );

  static const cbet = TermNote(
    term: 'Cベット（継続ベット）',
    meaning: 'プリフロップでレイズした人が、フロップでもそのまま打つこと。',
  );

  static const rangeAdvantage = TermNote(
    term: 'レンジ有利',
    meaning:
        'そのボードで、自分が持ちうる手の集まり全体が相手より強い状態のこと。'
        '1回の手札の強さではなく、「ありえる手ぜんぶ」を比べた話です。',
  );

  static const dryBoard = TermNote(
    term: 'ドライなボード',
    meaning: 'ストレートやフラッシュのドローがほとんど無い、形の変わりにくいボード。',
  );

  static const wetBoard = TermNote(
    term: 'ウェットなボード',
    meaning: 'ストレートやフラッシュのドローが多く、次のカードで順位が入れ替わりやすいボード。',
  );

  static const monotoneBoard = TermNote(
    term: 'モノトーンボード',
    meaning:
        'フロップの3枚が全部同じスートのボード。'
        '相手がその色を2枚持っていれば、その時点でフラッシュが完成しています。',
  );

  static const threeBetPot = TermNote(
    term: '3ベットポット',
    meaning:
        'プリフロップでレイズにレイズし返して作られたポット。'
        '最初から大きいので、フロップの時点で残りスタックとの差が小さく、'
        '1回の判断が重くなります。',
  );

  static const rangeCap = TermNote(
    term: 'レンジが上限で止まっている',
    meaning:
        'その相手が、一番強い手の並びをもう持っていない状態のこと。'
        '例えばプリフロップでレイズし返さなかった側は、'
        'AA や KK を持っている可能性がぐっと下がります。',
  );

  static const potOdds = TermNote(
    term: 'ポットオッズ',
    meaning:
        '「いくら払って、勝てばいくら取れるか」の比率。'
        'コールが得かどうかを、感覚ではなく計算で判断するための道具です。',
  );

  static const requiredEquity = TermNote(
    term: '必要勝率',
    meaning:
        'そのコールが損得ゼロになる勝率。'
        'これを超えて勝てそうならコール、下回るならフォールドが基準になります。',
  );

  static const spr = TermNote(
    term: 'SPR',
    meaning:
        'ポットに対する残りスタックの比率（スタック ÷ ポット）。'
        '小さいほど「もう降りられない」状況に近く、大きいほど慎重さが要ります。',
  );

  static const kicker = TermNote(
    term: 'キッカー',
    meaning: 'ペアになっていないほうのカード。同じペア同士がぶつかったとき、この高さで勝負が決まります。',
  );

  static const valueBet = TermNote(
    term: 'バリューベット',
    meaning:
        '自分より弱い手に払ってもらう目的のベット。'
        '「誰が払ってくれるのか」を言えないなら、それはバリューベットではありません。',
  );

  static const bluff = TermNote(
    term: 'ブラフ',
    meaning:
        '自分より強い手を降ろす目的のベット。'
        '「誰が降りてくれるのか」を言えないなら、それはブラフとして成立していません。',
  );

  static const nuts = TermNote(term: 'ナッツ', meaning: 'そのボードで作れる最強のハンド。');

  static const blocker = TermNote(
    term: 'ブロッカー',
    meaning:
        '自分が持っていることで、相手がその手を持てなくなるカード。'
        '例えば A を1枚持っていれば、相手が A のペアやナッツフラッシュを持つ組み合わせが減ります。',
  );

  static const checkRaise = TermNote(
    term: 'チェックレイズ',
    meaning: '自分は一度チェックして相手に打たせ、そのうえでレイズし返すこと。',
  );

  static const polarized = TermNote(
    term: 'ポラライズ（二極化）',
    meaning:
        '打つ手が「とても強い手」と「ほぼ何も無い手」の両極端に寄っている状態。'
        '中くらいの強さの手は打たずにチェックへ回します。',
  );

  static const scareCard = TermNote(
    term: 'スケアカード',
    meaning:
        '落ちたことで、それまでの強い手が急に不安になるカード。'
        '「そのカードで誰が強くなったか」を考えると扱いやすくなります。',
  );

  static const equity = TermNote(
    term: 'エクイティ（勝率）',
    meaning: '最後まで進んだときにポットを取れる見込み。ドローも「まだ勝っていないが勝つ見込み」として数えます。',
  );
}
