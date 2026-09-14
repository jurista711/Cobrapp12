import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const emailFrom = Deno.env.get("EMAIL_FROM") ?? "Roots Cobrança <onboarding@resend.dev>";

  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return new Response("Unauthorized", { status: 401 });

  const ownerId = String(user.app_metadata?.owner_id ?? user.id);
  if (!resendKey) {
    return Response.json({
      sent: 0,
      queued: true,
      configured: false,
      message: "RESEND_API_KEY não configurada",
    });
  }

  const admin = createClient(url, service);
  const { data: rows, error } = await admin
    .from("cobrapp_email_reminders")
    .select("id,email,subject,body")
    .eq("user_id", ownerId)
    .eq("status", "queued")
    .lte("scheduled_for", new Date().toISOString().slice(0, 10))
    .limit(50);

  if (error) return Response.json({ error: error.message }, { status: 500 });

  let sent = 0;
  for (const row of rows ?? []) {
    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: emailFrom,
          to: [row.email],
          subject: row.subject,
          text: row.body,
        }),
      });
      if (!response.ok) throw new Error(await response.text());
      await admin
        .from("cobrapp_email_reminders")
        .update({
          status: "sent",
          sent_at: new Date().toISOString(),
          error_text: null,
        })
        .eq("id", row.id);
      sent++;
    } catch (e) {
      await admin
        .from("cobrapp_email_reminders")
        .update({ status: "error", error_text: String(e) })
        .eq("id", row.id);
    }
  }

  return Response.json({ sent, configured: true });
});
