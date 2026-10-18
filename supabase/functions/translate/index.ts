// Translates user text into the site language. Uses Claude when ANTHROPIC_API_KEY is set, otherwise the free MyMemory API.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const NAMES: Record<string, string> = { ka: "Georgian", en: "English", ru: "Russian", de: "German", tr: "Turkish", uk: "Ukrainian", hy: "Armenian", az: "Azerbaijani", fr: "French", es: "Spanish", it: "Italian" };
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { text, source, target = "ka" } = await req.json();
    const src = String(text ?? "").slice(0, 3000);
    if (!src.trim()) return json({ error: "empty" }, 400);
    const targetName = NAMES[target] ?? "Georgian";
    const key = Deno.env.get("ANTHROPIC_API_KEY");
    if (key) {
      const prompt = `You translate short user-generated text inside a ${targetName}-language social network.\nRules:\n- If the text is Georgian written with Latin letters (informal transliteration such as \"gamarjoba rogor xar\"), rewrite it in standard Georgian script with correct spelling. Keep the meaning unchanged.\n- Otherwise translate it into natural, conversational ${targetName}.\n- Keep emoji, names, @mentions, numbers and links unchanged.\nReply with only JSON: {\"source\":\"<source language name written in ${targetName}>\",\"text\":\"<result>\"}\n\nText:\n\"\"\"${src}\"\"\"`;
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
        body: JSON.stringify({ model: "claude-haiku-5-5", max_tokens: 1500, messages: [{ role: "user", content: prompt }] }),
      });
      if (r.ok) {
        const d = await r.json();
        const out = String(d?.content?.[0]?.text ?? "");
        const m = out.match(/\{[\s\S]*\}/);
        if (m) {
          const p = JSON.parse(m[0]);
          if (p?.text) return json({ text: String(p.text), source: String(p.source ?? ""), engine: "claude" });
        }
      }
    }
    if (source === "ka-lat") return json({ error: "translit_local" }, 422);
    const from = source && NAMES[source] && source !== target ? source : "en";
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(src.slice(0, 480))}&langpair=${from}|${target}`;
    const r2 = await fetch(url);
    const d2 = await r2.json();
    const out2 = d2?.responseData?.translatedText;
    if (!out2) return json({ error: "no_translation" }, 502);
    return json({ text: String(out2), source: from, engine: "mymemory" });
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});
