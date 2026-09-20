// Edge Function: POST /read-hand
//
// テーブル全体の写真1枚を受け取り、Claude(Anthropic) の Vision でカードを
// 読み取って、位置ベースの役割(自分/場/相手)つきで返す。
// 仕様は docs/camera-hand-read.md を参照。
//
// APIキーはこの関数のシークレット(サーバー側)からのみ読む。アプリ側には置かない。
//   設定: Supabase ダッシュボード → Edge Functions → Secrets に
//         ANTHROPIC_API_KEY を追加する（または `supabase secrets set ANTHROPIC_API_KEY=...`）。
//   関数からの参照: Deno.env.get("ANTHROPIC_API_KEY")

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
// モデルは env で差し替え可能。既定は Vision 対応の Claude Sonnet。
const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT = [
  "あなたはポーカーのテーブル写真からカードを読み取る認識器です。",
  "- 見えているプレイングカードのランクとスートを読み取る(A,K,Q,J,T,9..2 と s,h,d,c)。10はTに正規化する。",
  "- 各カードの画面上の位置から役割を推定する:",
  "  画面下部の区切りゾーン=自分(me)、中央の並び=場(board、右から順に board_order を1から振る)、",
  "  その他のかたまり=相手(villain、人ごとに cluster を1から振る)。",
  "- 読めないカードは推測で埋めない。自信が低い場合は confidence を下げる。",
  "- カード以外(チップ額・人物など)は読み取らない。",
].join("\n");

const CARD_TOOL = {
  name: "report_cards",
  description: "読み取ったカードを役割つきで報告する",
  input_schema: {
    type: "object",
    properties: {
      cards: {
        type: "array",
        items: {
          type: "object",
          properties: {
            code: { type: "string", description: "例: Ah, Ts, 2c" },
            confidence: { type: "number", description: "0.0〜1.0" },
            suggested: { type: "string", enum: ["me", "board", "villain"] },
            board_order: { type: "integer", description: "場のみ。右端が1" },
            cluster: { type: "integer", description: "相手のみ。人ごとに1から" },
          },
          required: ["code", "confidence", "suggested"],
        },
      },
      warnings: { type: "array", items: { type: "string" } },
    },
    required: ["cards", "warnings"],
  },
} as const;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return json({ error: "ANTHROPIC_API_KEY is not configured" }, 500);
  }

  let imageBase64: string;
  let mediaType: string;
  try {
    const payload = await req.json();
    imageBase64 = String(payload.image_base64 ?? "");
    mediaType = String(payload.media_type ?? "image/jpeg");
    if (!imageBase64) throw new Error("image_base64 is required");
  } catch (_e) {
    return json({ error: "invalid request body" }, 400);
  }

  let anthropicRes: Response;
  try {
    anthropicRes = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        tools: [CARD_TOOL],
        tool_choice: { type: "tool", name: "report_cards" },
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: "この写真のカードを読み取り、report_cards で報告してください。",
              },
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: mediaType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
      }),
    });
  } catch (_e) {
    return json({ error: "failed to reach Anthropic API" }, 502);
  }

  if (!anthropicRes.ok) {
    const detail = await anthropicRes.text();
    return json(
      { error: "Anthropic API error", status: anthropicRes.status, detail },
      502,
    );
  }

  const data = await anthropicRes.json();
  const toolUse = (data.content ?? []).find(
    (block: { type?: string }) => block.type === "tool_use",
  );
  if (!toolUse) {
    return json({ error: "no structured output returned" }, 502);
  }

  // toolUse.input は { cards, warnings } の形。そのまま返す。
  return json(toolUse.input);
});
