// send-push Edge Function
// Sends a push notification to everyone who has turned on event news or
// new-chapter news, through Firebase Cloud Messaging.
//
// Only an admin may call it: the caller must be signed in, and their account
// must be listed in the `admins` table. At most one push goes out a day
// (enforced in the database by reserve_push).
// The decisions live in rules.ts (tested by rules_test.ts).
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { b64url } from '../verify-purchase/rules.ts';
import { checkPush } from './rules.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // 1. Who is asking? A signed-in admin, or nobody.
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Sign in first' }, 401);
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );
    if (authError || !user) return json({ error: 'Sign in first' }, 401);
    const { data: admin, error: adminError } = await supabase
      .from('admins')
      .select('user_id')
      .eq('user_id', user.id)
      .maybeSingle();
    if (adminError) throw adminError;
    if (!admin) return json({ error: 'Only an admin can send notifications' }, 403);

    // 2. Is the request one that may be sent?
    const checked = checkPush(await req.json().catch(() => null));
    if (!checked.ok) return json({ error: checked.reason }, 400);
    const push = checked.push;

    const serviceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccount) {
      return json({ error: 'Push is not set up yet (the Firebase key is missing)' }, 503);
    }
    const sa = JSON.parse(serviceAccount) as {
      client_email: string;
      private_key: string;
      project_id: string;
    };
    const accessToken = await firebaseAccessToken(sa);

    // 3. Record it BEFORE sending. The database allows one record a day,
    //    under a lock, so two requests at once cannot both get through and a
    //    push can never go out unrecorded.
    const { data: reserved, error: reserveError } = await supabase.rpc('reserve_push', {
      p_type: push.topic,
      p_audience: `topic:${push.topic}`,
      p_title: push.title,
      p_body: push.body,
    });
    if (reserveError) throw reserveError;
    if (!reserved) {
      return json({ error: 'A notification was already sent in the last 24 hours' }, 429);
    }

    // 4. Send it.
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            topic: push.topic,
            notification: { title: push.title, body: push.body },
            data: { type: push.topic },
          },
        }),
      },
    );
    if (!res.ok) {
      console.error('FCM refused the push:', await res.text());
      // Nothing went out, so today's allowance is given back. If this
      // fails the record stays and no second push can go: the safe side.
      const { error: undoError } = await supabase
        .from('notifications_log').delete().eq('id', reserved);
      if (undoError) console.error('Could not give back the push allowance:', undoError);
      return json({ error: 'Firebase did not accept the notification' }, 502);
    }
    await res.body?.cancel();
    const { error: markError } = await supabase
      .from('notifications_log').update({ sent_count: 1 }).eq('id', reserved);
    if (markError) console.error('Push sent; its record was not marked sent:', markError);

    return json({ success: true }, 200);
  } catch (err) {
    console.error('send-push error:', err);
    return json({ error: 'Internal error' }, 500);
  }
});

async function firebaseAccessToken(
  sa: { client_email: string; private_key: string },
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 600,
  }));
  const body = sa.private_key
    .replace(/\\n/g, '\n')
    .replace(/-----(BEGIN|END)( RSA)? PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const bytes = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  );
  const jwt = `${header}.${payload}.${b64url(new Uint8Array(sig))}`;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json() as { access_token?: string; error_description?: string };
  if (!data.access_token) {
    // Google's own reason (a wrong or revoked key, say) goes to the log.
    console.error('Google refused the Firebase key:', data.error_description ?? res.status);
    throw new Error('Firebase did not give an access token');
  }
  return data.access_token;
}
