// Sends web push for a new notification row. Called by a database trigger with a shared secret header.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
let cfg: Record<string, string> | null = null;

async function config() {
  if (!cfg) {
    const { data, error } = await sb.rpc("push_config");
    if (error) throw error;
    cfg = data as Record<string, string>;
    webpush.setVapidDetails(cfg.vapid_subject, cfg.vapid_public, cfg.vapid_private);
  }
  return cfg!;
}

function text(kind: string, name: string, ref: Record<string, string>): string {
  switch (kind) {
    case "react": return `${name} · ${ref.emoji ?? "👍"} შენს პოსტზე`;
    case "comment": return `${name} · ახალი კომენტარი: ${ref.text ?? ""}`;
    case "friend_req": return `${name} · მეგობრობის მოთხოვნა`;
    case "friend_ok": return `${name} · მეგობრობა დადასტურდა`;
    case "message": return `${name}: ${ref.text ?? ""}`;
    case "gift": return `${name} · საჩუქარი ${ref.emoji ?? "🎁"}`;
    case "match": return `${name} · წყვილი ხართ!`;
    case "super": return `${name} · სუპერ მოწონება ⭐`;
    case "verified": return "შენი პროფილი ვერიფიცირდა ✓";
    case "verify_rejected": return "ვერიფიკაცია ვერ დადასტურდა. სცადე ახალი სელფით";
    case "ad_ok": return "შენი რეკლამა დამტკიცდა და უკვე ჩანს";
    case "ad_rejected": return "რეკლამა არ დამტკიცდა, მონეტები დაგიბრუნდა";
    default: return `${name} · ახალი შეტყობინება`;
  }
}

function route(kind: string, ref: Record<string, string>): string {
  if (kind === "message" && ref.conv) return `/#chat-${ref.conv}`;
  if ((kind === "react" || kind === "comment") && ref.post) return `/#post-${ref.post}`;
  if (kind === "match" || kind === "super") return "/#date";
  return "/#notifications";
}

Deno.serve(async (req) => {
  try {
    const c = await config();
    if (req.headers.get("x-push-secret") !== c.push_secret) return new Response("forbidden", { status: 403 });
    const { id } = await req.json();
    const { data: n } = await sb.from("notifications").select("id,user_id,actor,kind,ref").eq("id", id).maybeSingle();
    if (!n) return new Response("ok");
    let name = "სუფრა";
    if (n.actor) {
      const { data: a } = await sb.from("profiles").select("name").eq("id", n.actor).maybeSingle();
      if (a?.name) name = a.name;
    }
    const ref = (n.ref ?? {}) as Record<string, string>;
    const payload = JSON.stringify({ title: "სუფრა", body: text(n.kind, name, ref), url: route(n.kind, ref), tag: `${n.kind}-${ref.conv ?? ref.post ?? n.id}` });
    const { data: subs } = await sb.from("push_subs").select("id,endpoint,p256dh,auth").eq("user_id", n.user_id);
    await Promise.all((subs ?? []).map(async (s) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 3600 });
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) await sb.from("push_subs").delete().eq("id", s.id);
      }
    }));
    return new Response("ok");
  } catch (e) {
    return new Response(String((e as Error).message ?? e), { status: 500 });
  }
});
