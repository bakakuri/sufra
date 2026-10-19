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
    case "comment_reply": return `${name} გიპასუხა: ${ref.text ?? ""}`;
    case "comment_like": return `${name} · მოიწონა შენი კომენტარი`;
    case "repost": return `${name} · ${String(ref.quote) === "true" ? "გააზიარა შენი პოსტი თავისი სიტყვით" : "გააზიარა შენი პოსტი"}`;
    case "story_mention": return `${name} მოგნიშნა თავის ისტორიაზე`;
    case "recipe_cook": return `${name} · შენი რეცეპტით მოამზადა კერძი 🍲`;
    case "jk_invite": return `${name} გეპატიჟება ჯოკერზე 🃏`;
    case "grade_plus": return `${name} · შენს ფოტოს „5+“ დაუწერა${Number(ref.coins) > 0 ? ` (+${ref.coins} მონეტა)` : ""}`;
    case "mention": return `${name} მოგიხსენია${ref.comment ? " კომენტარში" : ""}: ${ref.text ?? ""}`;
    case "msg_react": return `${name} · ${ref.emoji ?? "❤️"} შენს მესიჯზე`;
    case "story_react": return `${name} · ${ref.emoji ?? "❤️"} შენს ისტორიაზე`;
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
    case "room_invite": return `${name} გეპატიჟება ${ref.kind === "birja" ? "ბირჟაზე" : ref.kind === "live" ? "ლაივზე" : "სუფრაზე"}: ${ref.title ?? ""}`;
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
    case "birthday_me": return "სუფრა გილოცავს დაბადების დღეს! 🎉";
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
  if (kind === "repost" && ref.post) return `/#post-${String(ref.quote) === "true" && ref.by ? ref.by : ref.post}`;
  if ((kind === "react" || kind === "comment" || kind === "comment_reply" || kind === "comment_like") && ref.post) return `/#post-${ref.post}`;
  if ((kind === "mention" || kind === "grade_plus") && ref.post) return `/#post-${ref.post}`;
  if (kind === "msg_react" && ref.conv) return `/#chat-${ref.conv}`;
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
