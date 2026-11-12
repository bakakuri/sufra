// Sends push for a new notification row: web push to browsers, and Firebase Cloud Messaging to the phone app
// (its devices are push_subs rows whose endpoint is "fcm:<token>"). Called by a database trigger with a shared secret header.
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

// Firebase: the server key lives in private.config (fcm_service_account), read through push_config like the VAPID keys
type ServiceAccount = { project_id: string; private_key: string; client_email: string; token_uri: string };
let fcmSA: ServiceAccount | null | undefined;
let fcmAuth: { token: string; until: number } | null = null;

function b64u(b: ArrayBuffer | string): string {
  const bytes = typeof b === "string" ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = "";
  for (const x of bytes) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function serviceAccount(c: Record<string, string>): ServiceAccount | null {
  if (fcmSA === undefined) {
    try {
      fcmSA = c.fcm_service_account ? JSON.parse(c.fcm_service_account) as ServiceAccount : null;
    } catch {
      fcmSA = null;
    }
  }
  return fcmSA;
}

// a Google access token for sending, made from the service account and kept for its hour
async function fcmToken(sa: ServiceAccount): Promise<string> {
  if (fcmAuth && fcmAuth.until > Date.now() + 60_000) return fcmAuth.token;
  const now = Math.floor(Date.now() / 1000);
  const head = b64u(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64u(JSON.stringify({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: sa.token_uri, iat: now, exp: now + 3600 }));
  const der = Uint8Array.from(atob(sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")), (ch) => ch.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claim}`));
  const r = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${head}.${claim}.${b64u(sig)}` }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error(`fcm auth ${r.status}`);
  fcmAuth = { token: j.access_token, until: Date.now() + (j.expires_in ?? 3600) * 1000 };
  return fcmAuth.token;
}

// one phone; true when its token is no longer valid (app removed or signed out) and the row should go
async function sendFcm(sa: ServiceAccount, token: string, m: { title: string; body: string; url: string; tag: string; kind: string }): Promise<boolean> {
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${await fcmToken(sa)}`, "content-type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: m.title, body: m.body },
        data: { url: m.url, kind: m.kind, tag: m.tag },
        android: { priority: "HIGH", ttl: "3600s", notification: { channel_id: "peera", tag: m.tag, sound: "default", color: "#4F46E5" } },
      },
    }),
  });
  if (r.ok) return false;
  const t = await r.text();
  return r.status === 404 || /UNREGISTERED/.test(t) || (r.status === 400 && /registration token/i.test(t));
}

// the "good idea" reaction is stored as 🍷 and shown as a light bulb
const emo = (e: string | undefined, d: string) => e === "🍷" ? "💡" : (e ?? d);

const DK: Record<string, string> = { exam: "🎓 გამოცდა", midterm: "📝 შუალედური", quiz: "❓ ქვიზი", task: "✏️ დავალება", project: "📁 პროექტი" };

function text(kind: string, name: string, ref: Record<string, string>): string {
  switch (kind) {
    case "lesson_soon": return `მალე იწყება: ${ref.title ?? ""}${ref.starts ? " · " + ref.starts : ""}${ref.place ? " · " + ref.place : ""}`;
    case "deadline_soon": return `${ref.when === "today" ? "დღეს" : "ხვალ"}: ${DK[ref.kind] ?? ""} · ${ref.title ?? ""}`;
    case "study_deadline": return `${name} დაამატა ${DK[ref.kind] ?? ""} ჯგუფში „${ref.gname ?? ""}“: ${ref.title ?? ""}`;
    case "react": return `${name} · ${emo(ref.emoji, "👍")} შენს პოსტზე`;
    case "comment": return `${name} · ახალი კომენტარი: ${ref.text ?? ""}`;
    case "comment_reply": return `${name} გიპასუხა: ${ref.text ?? ""}`;
    case "comment_like": return `${name} · მოიწონა შენი კომენტარი`;
    case "repost": return `${name} · ${String(ref.quote) === "true" ? "გააზიარა შენი პოსტი თავისი სიტყვით" : "გააზიარა შენი პოსტი"}`;
    case "promo": return `${ref.text ?? ""}`;
    case "admin_msg": return `Peera-ს გუნდი: ${ref.text ?? ""}`;
    case "admin_coins": return `${Number(ref.coins) > 0 ? "+" : ""}${ref.coins ?? ""} მონეტა · ${ref.note ?? ""}`;
    case "story_mention": return `${name} მოგნიშნა თავის ისტორიაზე`;
    case "recipe_cook": return `${name} · შენი კონსპექტით ისწავლა 📚`;
    case "jk_invite": return `${name} გეპატიჟება ჯოკერზე 🃏`;
    case "grade_plus": return `${name} · შენს ფოტოს „5+“ დაუწერა${Number(ref.coins) > 0 ? ` (+${ref.coins} მონეტა)` : ""}`;
    case "mention": return `${name} მოგიხსენია${ref.comment ? " კომენტარში" : ""}: ${ref.text ?? ""}`;
    case "msg_react": return `${name} · ${emo(ref.emoji, "❤️")} შენს მესიჯზე`;
    case "story_react": return `${name} · ${emo(ref.emoji, "❤️")} შენს ისტორიაზე`;
    case "event_invite": return `${name} გეპატიჟება: ${ref.title ?? ""}`;
    case "event_soon": return `მალე იწყება: ${ref.title ?? ""}`;
    case "album_invite": return `${name} დაგამატა ალბომში „${ref.title ?? ""}“`;
    case "album_photo": return `${name} ფოტოები დაამატა ალბომში „${ref.title ?? ""}“`;
    case "group_request": return `${name} ითხოვს გაწევრიანებას: ${ref.name ?? ""}`;
    case "group_ok": return `მიგიღეს ჯგუფში: ${ref.name ?? ""}`;
    case "group_pending": return `${name} · პოსტი ელოდება დამტკიცებას: ${ref.name ?? ""}`;
    case "group_post_ok": return `შენი პოსტი დამტკიცდა: ${ref.name ?? ""}`;
    case "group_post_no": return `შენი პოსტი არ დამტკიცდა: ${ref.name ?? ""}`;
    case "group_admin": return `${name} ადმინი გაგხადა: ${ref.name ?? ""}`;
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
    case "room_invite": return `${name} გეპატიჟება ${ref.kind === "birja" ? "დისკუსიაზე" : ref.kind === "live" ? "ლაივზე" : "სასწავლო ოთახში"}: ${ref.title ?? ""}`;
    case "bet_won": return `მოიგე ${ref.coins ?? ""} მონეტა · ${ref.match ?? ""} ${ref.score ?? ""}`;
    case "bet_lost": return `${ref.match ?? ""} ${ref.score ?? ""} · პროგნოზი არ გამართლდა`;
    case "bet_refund": return `${ref.match ?? ""} · მონეტები დაგიბრუნდა`;
    case "ride_req": return `${name} ითხოვს ${ref.seats ?? 1} ადგილს · ${ref.route ?? ""}`;
    case "ride_ok": return `${name} დაგიდასტურა ადგილი · ${ref.route ?? ""}`;
    case "ride_no": return `${name}: ადგილი ვერ დაგიდასტურა · ${ref.route ?? ""}`;
    case "ride_cancel": return `${name} გააუქმა ჯავშანი · ${ref.route ?? ""}`;
    case "job_apply": return `${name} გამოეხმაურა ვაკანსიას: ${ref.title ?? ""}`;
    case "job_invited": return `გასაუბრებაზე მიგიწვიეს: ${ref.title ?? ""}`;
    case "job_rejected": return `${ref.title ?? ""} · სამწუხაროდ, სხვა კანდიდატი შეირჩა`;
    case "nameday": return `${ref.label ?? "ანგელოზის დღე"}: ${name}${Number(ref.n) > 1 ? ` და კიდევ ${Number(ref.n) - 1} მეგობარი` : ""} · მიულოცე!`;
    case "birthday": return `დაბადების დღე: ${name}${Number(ref.n) > 1 ? ` და კიდევ ${Number(ref.n) - 1} მეგობარი` : ""} · მიულოცე! 🎉`;
    case "nameday_me": return `გილოცავ ანგელოზის დღეს! ${ref.label ?? ""}`;
    case "birthday_me": return "Peera გილოცავს დაბადების დღეს! 🎉";
    case "kin_req": return `${name} გთავაზობს ოჯახის ხეში დაკავშირებას`;
    case "kin_ok": return `${name} დაადასტურა ნათესაობა`;
    case "help_new": return `${ref.kind === "blood" ? "🩸 საჭიროა დონორი" + (ref.blood ? " " + ref.blood : "") : ref.kind === "volunteer" ? "🤝 საჭიროა მოხალისე" : "🐾 " + (ref.kind === "found_pet" ? "ნაპოვნია" : "დაიკარგა")} · ${ref.title ?? ""} · ${ref.region ?? ""}`;
    case "help_offer": return `${name} გთავაზობს დახმარებას: ${ref.title ?? ""}`;
    case "help_done": return `${ref.title ?? ""} · მოგვარდა. მადლობა, რომ გამოეხმაურე`;
    case "live_start": return `${name} ცოცხალ ეთერშია: ${ref.title ?? ""}`;
    default: return `${name} · ახალი შეტყობინება`;
  }
}

function route(kind: string, ref: Record<string, string>): string {
  if (kind === "message" && ref.conv) return `/#chat-${ref.conv}`;
  if (kind === "lesson_soon") return "/#schedule";
  if (kind === "deadline_soon" || kind === "study_deadline") return "/#exams";
  if (kind === "repost" && ref.post) return `/#post-${String(ref.quote) === "true" && ref.by ? ref.by : ref.post}`;
  if ((kind === "react" || kind === "comment" || kind === "comment_reply" || kind === "comment_like") && ref.post) return `/#post-${ref.post}`;
  if ((kind === "mention" || kind === "grade_plus") && ref.post) return `/#post-${ref.post}`;
  if (kind === "msg_react" && ref.conv) return `/#chat-${ref.conv}`;
  if (kind === "promo" && /^#[a-z]+(-[^\s"'<>()]+)?$/.test(String(ref.link ?? ""))) return `/${ref.link}`;
  if (kind === "admin_coins") return "/#coins";
  if (kind === "recipe_cook" && ref.recipe) return `/#recipe-${ref.recipe}`;
  if (kind === "jk_invite" && ref.table) return `/#jktable-${ref.table}`;
  if (kind === "story_mention" && ref.story) return `/#storyv-${ref.story}`;
  if (kind.startsWith("event_") && ref.event) return `/#event-${ref.event}`;
  if (kind.startsWith("album_") && ref.album) return `/#album-${ref.album}`;
  if (kind === "group_post_ok" && ref.post) return `/#post-${ref.post}`;
  if (kind.startsWith("group_") && ref.group) return `/#group-${ref.group}`;
  if (kind === "match" || kind === "super") return "/#date";
  if (kind === "room_invite" && ref.room) return `/#room-${ref.room}`;
  if (kind.startsWith("bet_") && ref.fixture) return `/#fixture-${ref.fixture}`;
  if (kind.startsWith("ride_") && ref.ride) return `/#ride-${ref.ride}`;
  if (kind.startsWith("job_") && ref.job) return `/#job-${ref.job}`;
  if (kind === "nameday" || kind === "birthday") return "/#calendar";
  if (kind === "nameday_me") return "/#namedays";
  if (kind.startsWith("kin_")) return kind === "kin_req" ? "/#tree" : `/#tree-${ref.owner ?? ""}`;
  if (kind.startsWith("help_") && ref.help) return `/#helpreq-${ref.help}`;
  if (kind === "live_start" && ref.room) return `/#room-${ref.room}`;
  return "/#notifications";
}

Deno.serve(async (req) => {
  try {
    const c = await config();
    if (req.headers.get("x-push-secret") !== c.push_secret) return new Response("forbidden", { status: 403 });
    const { id } = await req.json();
    const { data: n } = await sb.from("notifications").select("id,user_id,actor,kind,ref").eq("id", id).maybeSingle();
    if (!n) return new Response("ok");
    // muted categories and quiet hours: the notification stays in the app, only the push is skipped
    const { data: allowed, error: pe } = await sb.rpc("push_allowed", { p_user: n.user_id, p_kind: n.kind });
    if (!pe && allowed === false) return new Response("quiet");
    let name = "Peera";
    if (n.actor) {
      const { data: a } = await sb.from("profiles").select("name").eq("id", n.actor).maybeSingle();
      if (a?.name) name = a.name;
    }
    const ref = (n.ref ?? {}) as Record<string, string>;
    const body = text(n.kind, name, ref), url = route(n.kind, ref), tag = `${n.kind}-${ref.conv ?? ref.post ?? n.id}`;
    const payload = JSON.stringify({ title: "Peera", body, url, tag });
    const { data: subs } = await sb.from("push_subs").select("id,endpoint,p256dh,auth").eq("user_id", n.user_id);
    await Promise.all((subs ?? []).map(async (s) => {
      try {
        if (s.endpoint.startsWith("fcm:")) {
          const sa = serviceAccount(c);
          if (!sa) return;
          // a message reads like a chat: the sender above, the words below
          const m = n.kind === "message" ? { title: name, body: String(ref.text ?? "") || "ახალი შეტყობინება" } : { title: "Peera", body };
          if (await sendFcm(sa, s.endpoint.slice(4), { ...m, url, tag, kind: n.kind })) await sb.from("push_subs").delete().eq("id", s.id);
          return;
        }
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
