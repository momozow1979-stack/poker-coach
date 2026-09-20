# AI プロンプト設計（Phase 6 / 7 で使用）

このドキュメントは仕様書 5 章の内容を、実装時にそのまま参照できる形にまとめたもの。
現時点ではアプリ内のローカル解析（`MockHandReviewRepository` / `MockCoachRepository`）が
同じ入出力形式を守っているため、Edge Function を実装しても画面側の変更は不要。

> **重要**: OpenAI の API キーはアプリに埋め込まない。
> 呼び出しは必ず Supabase Edge Function（サーバー側）から行う。

## 1. ハンドレビュー System Prompt

```
あなたは初心者〜中級者を指導するプロのNo-Limit Texas Hold'emポーカーコーチです。

目的:
ユーザーが「なぜそのプレイが良い / 悪いのか」を理解し、
次回の実戦で再現できるようにしてください。

ルール:
- 結論だけでなく理由を説明する。
- 専門用語を使う場合は初心者向けに説明する。
- GTO視点と実戦的なエクスプロイト視点を分ける。
- 不確実なスポットでは断定しすぎない。
- 正確なsolver結果が入力として提供されていない場合、solverの厳密な頻度を捏造しない。
- EV値を推測して作らない。
- ユーザーを責める表現は禁止。
- 最も重要な改善点を1つ明確にする。
- 回答は指定JSON形式のみ。
```

## 2. 入力 JSON

`HandReviewInput.toJson()`（`lib/features/hand_review/domain/hand_review_input.dart`）が
この形式を生成する。

```json
{
  "game_type": "cash",
  "table_type": "6max",
  "small_blind": 0.5,
  "big_blind": 1,
  "effective_stack_bb": 100,
  "hero_position": "BTN",
  "hero_hand": ["Ah", "Js"],
  "villain_position": "BB",
  "villain_profile": "unknown",
  "environment": "online",
  "preflop": [{ "actor": "hero", "action": "Raise" }],
  "flop": { "board": ["Qs", "7d", "2c"], "actions": [] },
  "turn": { "card": null, "actions": [] },
  "river": { "card": null, "actions": [] },
  "user_question": ""
}
```

## 3. 出力 JSON

`HandReviewResult.fromJson()` がこの形式を読む。Structured Output で固定すること。

```json
{
  "score": 82,
  "summary": "",
  "good_points": [],
  "main_improvement": "",
  "street_analysis": { "preflop": "", "flop": "", "turn": "", "river": "" },
  "gto_view": "",
  "practical_adjustment": "",
  "alternative_lines": [],
  "next_focus": "",
  "related_quiz_topics": []
}
```

`related_quiz_topics` には `QuizCategory` の ID
（`preflop` / `flop` / `turn` / `river` / `position` / `bet_sizing` / `pot_odds` /
`value_bluff` / `gto` / `exploit`）を返す。

## 4. クイズ解説 Prompt

```
役割: 初心者向けポーカーコーチ。

回答内容:
1. 正解
2. 30〜100文字程度の短い理由
3. GTOではどう考えるか
4. 実戦ではどう調整するか
5. 初心者が間違えやすいポイント

注意:
- solverの正確な数値がない場合、架空の頻度を出さない。
- 説明はできるだけ平易にする。
```

出力は `QuizExplanation` の 4 フィールド
（`shortReason` / `gtoView` / `practicalView` / `commonMistake`）に対応させる。

## 5. Edge Function エンドポイント

| メソッド | パス | 対応する Repository |
| --- | --- | --- |
| GET | `/quiz/today` | `QuizRepository.dailyQuizzes` |
| POST | `/quiz/answer` | `LearningStore.recordAttempt` |
| GET | `/range` | `RangeRepository.spotsFor` / `chartFor` |
| POST | `/review` | `HandReviewRepository.review` |
| POST | `/read-hand` | カメラ写真からカードを読む（Vision）。詳細は `docs/camera-hand-read.md` |
| GET | `/review/history` | `handReviewHistoryProvider` |
| GET | `/coach/today` | `CoachRepository.briefing` |
