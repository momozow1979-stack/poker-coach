import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import 'range_action.dart';
import 'range_entry.dart';
import 'range_spot.dart';

/// ハンドをタップしたときに表示する解説。
class RangeHandGuidance {
  const RangeHandGuidance({
    required this.hand,
    required this.action,
    required this.frequencyLabel,
    required this.reason,
    required this.beginnerNote,
    required this.gtoNote,
    required this.practicalNote,
    this.blend,
  });

  final StartingHand hand;
  final RangeAction action;
  final String frequencyLabel;

  /// なぜそのアクションなのか。
  final String reason;
  final String beginnerNote;
  final String gtoNote;
  final String practicalNote;

  /// [action] が [RangeAction.mixed] のときだけ埋まる、内訳データ
  /// （[RangeEntry.blend] をそのまま引き継いだもの）。
  ///
  /// [frequencyLabel] はこれをテキスト化した文言だが、UI 側で帯グラフ
  /// （`ActionFrequencyBar`）のような視覚的な表現を作りたい場合は、
  /// テキストを再パースするのではなくこちらを直接参照する。
  final RangeActionBlend? blend;
}

/// レンジ表の解説文を組み立てる。
///
/// ソルバーの厳密な頻度を作らず、「なぜ」を言語化することに集中する。
///
/// オープンレイズ（raise/fold の境界）だけでなく、vsOpen シナリオ
/// （3Bet/Call/Fold の境界）の解説にも同じ考え方を適用する。MIX ハンドの
/// 内訳（[RangeEntry.blend] の主・副アクションの割合）も、実測ソルバー値
/// ではなく「標準的なプリフロップ理論に基づいて整理した学習用の目安」
/// であり、これを厳密なGTO頻度として断定しない。
///
/// vsOpen シナリオ（[RangeDefinitions._vsOpen] で追加した11件）の裏取りに
/// ついて: この env のネットワーク境界上、主要なプリフロップチャート配信
/// サイト（RangeConverter・PreflopWizard・RedChipPoker・PokerCoaching・
/// TwoPlusTwo・Scribd 等）は個別ページの直接取得ができず、検索結果の
/// スニペット経由でのみ内容を確認できた。得られた範囲で確認できたのは:
/// 「3Bet頻度は早いポジションのオープンほど低く（UTGクラス想定で目安7.5%）、
/// 遅いポジションほど広がる（COクラス想定で目安16%）」「典型的な3Betレンジは
/// QQ+/AKs/AKo中心の価値に、A5s-A2s等のブロッカーやスーテッドコネクターの
/// ブラフを添える構成」「SBはBBよりも引き締めた3Bet/Foldに寄りやすい」
/// という、独立した複数の情報源に共通する一般論——このアプリの11シナリオ
/// （UTGクラス対面ほど価値のみ、レイトポジション対面ほどA5s-A2s系ブロッカー
/// ブラフを追加、SBをBB防衛より引き締める、という設計）と方向性が一致する
/// ことを確認した。ただしハンド単位の完全一致を検証したわけではなく、
/// 自前のソルバー（`solver/vendor/TexasSolver`）でのクロスチェックは、
/// このツールがプリフロップ単独（ボード無し）の解を出せない仕様のため
/// 実施できなかった（2026年9月、`solver/vendor/TexasSolver/src/tools/
/// CommandLineTool.cpp` の `set_board` がボード無し入力を受け付けないことを
/// ソースコードで確認済み）。この注記はポーカーに詳しい人間によるレビュー
/// の代わりにはならず、あくまで「学習用の目安」という位置づけは変えない。
abstract final class RangeGuidanceBuilder {
  static RangeHandGuidance build({
    required RangeSpot spot,
    required RangeEntry entry,
  }) {
    final hand = entry.hand;
    final position = spot.heroPosition;
    return RangeHandGuidance(
      hand: hand,
      action: entry.action,
      frequencyLabel: _frequencyLabel(entry),
      reason: _reason(spot, entry),
      beginnerNote: _beginnerNote(position, entry),
      gtoNote: _gtoNote(spot, entry),
      practicalNote: _practicalNote(spot, entry),
      blend: entry.blend,
    );
  }

  static String _frequencyLabel(RangeEntry entry) {
    if (entry.action == RangeAction.mixed) {
      final blend = entry.blend;
      if (blend == null) {
        return '状況次第（ミックス）';
      }
      final primaryPercent = (blend.primaryShare * 100).round();
      final secondaryPercent = (blend.secondaryShare * 100).round();
      return '${blend.primary.label} $primaryPercent% / '
          '${blend.secondary.label} $secondaryPercent%（ミックス）';
    }
    if (entry.frequency >= 0.99) {
      return '常に ${entry.action.label}';
    }
    return '目安 ${(entry.frequency * 100).round()}% で ${entry.action.label}';
  }

  static String _handClass(StartingHand hand) {
    if (hand.isPair) {
      if (hand.high.strength >= 12) return 'プレミアムペア';
      if (hand.high.strength >= 9) return 'ミドルペア';
      return 'スモールペア';
    }
    final gap = hand.high.strength - hand.low.strength;
    if (hand.high.strength == 14) {
      return hand.shape == HandShape.suited ? 'スーテッドエース' : 'オフスートエース';
    }
    if (hand.high.strength >= 11 && hand.low.strength >= 10) {
      return 'ブロードウェイ';
    }
    if (gap == 1) {
      return hand.shape == HandShape.suited ? 'スーテッドコネクター' : 'オフスートコネクター';
    }
    if (gap <= 3 && hand.shape == HandShape.suited) {
      return 'スーテッドギャッパー';
    }
    return hand.shape == HandShape.suited ? 'スーテッドハンド' : 'オフスートハンド';
  }

  static String _reason(RangeSpot spot, RangeEntry entry) {
    final handClass = _handClass(entry.hand);
    final position = spot.heroPosition;
    final positionNote = switch (position) {
      Position.btn => 'BTN は全ストリートで最後に動ける最も有利な席です',
      Position.sb => 'SB は BB とのヘッズアップですが、ポストフロップは常に不利です',
      Position.bb => 'BB はすでにブラインドを払っているぶん、必要なオッズが良くなります',
      Position.co => 'CO の後ろは BTN と 2 つのブラインドだけです',
      _ => '${position.label} は後ろに残っているプレイヤーが多い席です',
    };

    return switch (entry.action) {
      RangeAction.raise =>
        '${entry.hand.code}は$handClass。$positionNote。'
            'レイズして主導権を取る価値のあるハンドです。',
      RangeAction.call =>
        '${entry.hand.code}は$handClass。レイズするほど強くはありませんが、'
            '$positionNote。ポットに参加する価値はあります。',
      RangeAction.threeBet =>
        '${entry.hand.code}は$handClass。相手のオープンに対して'
            '3Bet でプレッシャーをかけられる強さ、またはブロッカーがあります。',
      RangeAction.fourBet =>
        '${entry.hand.code}は$handClass。3Bet に対しても降りずに'
            '4Bet で戦えるレンジの上位に入ります。',
      RangeAction.mixed =>
        '${entry.hand.code}は$handClass。境界線上のハンドで、'
            'テーブルの傾向によってプレイするかどうかが変わります。',
      RangeAction.fold =>
        '${entry.hand.code}は$handClass。${position.label} からはレンジ外で、'
            '参加しても長期的にはマイナスになりやすいハンドです。',
    };
  }

  static String _beginnerNote(Position position, RangeEntry entry) {
    return switch (entry.action) {
      RangeAction.fold =>
        '迷ったら降りてかまいません。プリフロップで参加するハンドを絞るだけで、'
            '難しいポストフロップの判断を大きく減らせます。',
      RangeAction.mixed =>
        'まずは「参加しない」で固定して大丈夫です。慣れてきたら、'
            'テーブルが受け身なときだけ入れてみましょう。',
      RangeAction.call => 'コールで参加するときは、フロップで何を狙うのかを先に決めておきましょう。',
      _ =>
        'リンプ（コールだけで入る）ではなくレイズで入るのが基本です。'
            'サイズは ${position == Position.sb ? '3BB' : '2.5BB'} 前後をひとつの目安にしてください。',
    };
  }

  static String _gtoNote(RangeSpot spot, RangeEntry entry) {
    if (entry.action == RangeAction.fold) {
      return 'ソルバーの解でも、${spot.heroPosition.label} のオープンレンジからは外れる領域です。'
          '無理に広げるとレンジ全体の強さが落ちます。';
    }
    if (entry.action == RangeAction.mixed) {
      final blend = entry.blend;
      if (blend != null) {
        return 'ソルバーはこの種のハンドを一定の頻度で混ぜます。'
            'このアプリでは ${blend.primary.label} ${(blend.primaryShare * 100).round()}% / '
            '${blend.secondary.label} ${(blend.secondaryShare * 100).round()}% という内訳を、'
            '標準的なプリフロップ理論に基づいて整理した学習用の目安として表示しています'
            '（実測のソルバー出力そのものではありません）。';
      }
      return 'ソルバーはこの種のハンドを一定の頻度で混ぜます。'
          'ここでは正確な頻度は表示せず「境界線上」とだけ扱っています。';
    }
    return 'ソルバーの解でも ${spot.heroPosition.label} のレンジに含まれる領域です。'
        'このアプリでは厳密な頻度ではなく、学習しやすい目安として表示しています。';
  }

  static String _practicalNote(RangeSpot spot, RangeEntry entry) {
    if (entry.action == RangeAction.fold) {
      return 'テーブルが極端に受け身（誰もリレイズしてこない）なら、'
          'この付近のスーテッドハンドは少し広げても機能します。';
    }
    return switch (spot.heroPosition) {
      Position.btn || Position.co =>
        '後ろのブラインドがタイトならさらに広げ、'
            '3Bet を多用してくる相手がいるならレンジを締めます。',
      Position.sb =>
        'BB がディフェンスの緩い相手ならレイズを増やし、'
            '3Bet が多い相手なら弱いハンドから外していきます。',
      _ =>
        '同じテーブルに攻撃的な相手が後ろにいる場合は、'
            'レンジの下限から少しずつ外していくのが安全です。',
    };
  }
}
