// Deletes the signed-in user's account and uploaded files.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: { user }, error } = await admin.auth.getUser(token);
    if (error || !user) return json({ error: "not_signed_in" }, 401);
    const { action } = await req.json();
    if (action !== "delete") return json({ error: "bad_action" }, 400);
    for (const bucket of ["media", "verify"]) {
      const { data: files } = await admin.storage.from(bucket).list(user.id, { limit: 1000 });
      const paths = (files ?? []).map((f) => `${user.id}/${f.name}`);
      if (paths.length) await admin.storage.from(bucket).remove(paths);
    }
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) return json({ error: delErr.message }, 500);
    return json({ ok: true });
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});
