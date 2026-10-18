// Builds a link preview card (title, description, image) for a public web page. Results are cached for a week.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

function safeUrl(raw: string): URL | null {
  let u: URL;
  try { u = new URL(raw); } catch { return null; }
  if (u.protocol !== "https:" && u.protocol !== "http:") return null;
  if (u.username || u.password) return null;
  if (u.port && u.port !== "80" && u.port !== "443") return null;
  const h = u.hostname.toLowerCase();
  if (!h.includes(".") || h === "localhost" || h.endsWith(".local") || h.endsWith(".internal") || h.endsWith(".localhost")) return null;
  if (/^\[|^\d+$|^0x/i.test(h)) return null;
  const m = h.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (m) {
    const [a, b] = [Number(m[1]), Number(m[2])];
    if (a === 10 || a === 127 || a === 0 || a >= 224 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127)) return null;
  }
  u.hash = "";
  return u;
}
const privateIp = (ip: string) => {
  const m = ip.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
  if (!m) return /^(::1|fe80:|fc|fd|::ffff:)/i.test(ip);
  const [a, b] = [Number(m[1]), Number(m[2])];
  return a === 10 || a === 127 || a === 0 || a >= 224 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127);
};
async function publicHost(h: string): Promise<boolean> {
  try {
    const ips = [...await Deno.resolveDns(h, "A").catch(() => [] as string[]), ...await Deno.resolveDns(h, "AAAA").catch(() => [] as string[])];
    return ips.length === 0 ? true : !ips.some(privateIp);
  } catch { return true; }
}
const decode = (s: string) => s.replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n))).replace(/\s+/g, " ").trim();
function meta(html: string, keys: string[]): string {
  for (const k of keys) {
    const re1 = new RegExp(`<meta[^>]+(?:property|name)=["']${k}["'][^>]*content=["']([^"']*)["']`, "i");
    const re2 = new RegExp(`<meta[^>]+content=["']([^"']*)["'][^>]*(?:property|name)=["']${k}["']`, "i");
    const m = html.match(re1) || html.match(re2);
    if (m && m[1].trim()) return decode(m[1]);
  }
  return "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { url } = await req.json();
    const u = safeUrl(String(url ?? "").slice(0, 2000));
    if (!u) return json({ error: "bad_url" }, 400);
    const key = u.toString();
    const { data: hit } = await sb.from("link_cache").select("data,fetched_at").eq("url", key).maybeSingle();
    if (hit && Date.now() - new Date(hit.fetched_at).getTime() < 7 * 864e5) return json(hit.data);
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), 6000);
    let final = u, r: Response | null = null;
    for (let hop = 0; hop < 4; hop++) {
      if (!(await publicHost(final.hostname))) return json({ error: "bad_url" }, 400);
      r = await fetch(final.toString(), { signal: ctl.signal, redirect: "manual", headers: { "User-Agent": "Mozilla/5.0 (compatible; SufraBot/1.0; +https://sufra-phi.vercel.app)", "Accept": "text/html,application/xhtml+xml", "Accept-Language": "ka,en;q=0.8" } });
      if (r.status >= 300 && r.status < 400 && r.headers.get("location")) {
        const next = safeUrl(new URL(r.headers.get("location")!, final).toString());
        if (!next) return json({ error: "bad_url" }, 400);
        final = next; r = null; continue;
      }
      break;
    }
    clearTimeout(t);
    if (!r) return json({ error: "too_many_redirects" }, 422);
    if (!r.ok || !(r.headers.get("content-type") ?? "").includes("html")) return json({ error: "not_html" }, 422);
    const reader = r.body!.getReader();
    let html = "", size = 0;
    const dec = new TextDecoder();
    while (size < 600_000) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      html += dec.decode(value, { stream: true });
      if (/<\/head>/i.test(html)) break;
    }
    try { reader.cancel(); } catch { /* ignore */ }
    const title = meta(html, ["og:title", "twitter:title"]) || decode((html.match(/<title[^>]*>([^<]*)<\/title>/i) ?? [])[1] ?? "");
    if (!title) return json({ error: "no_title" }, 422);
    let image = meta(html, ["og:image", "og:image:url", "twitter:image", "twitter:image:src"]);
    if (image) { try { const iu = new URL(image, final); image = iu.protocol === "https:" || iu.protocol === "http:" ? iu.toString() : ""; } catch { image = ""; } }
    const data = {
      url: key,
      title: title.slice(0, 200),
      description: (meta(html, ["og:description", "twitter:description", "description"]) || "").slice(0, 300),
      image: image.slice(0, 1000),
      site: (meta(html, ["og:site_name"]) || final.hostname.replace(/^www\./, "")).slice(0, 80),
    };
    await sb.from("link_cache").upsert({ url: key, data, fetched_at: new Date().toISOString() });
    return json(data);
  } catch (e) {
    return json({ error: String((e as Error).message ?? e).slice(0, 200) }, 500);
  }
});
