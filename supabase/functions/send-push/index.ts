// send-push Edge Function
// Sends push notifications through FCM HTTP v1 API.
// Called from the admin panel or on a schedule.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface PushRequest {
  // Send to a specific user by user_id, or to a topic (e.g. "events", "chapters").
  target_type: 'user' | 'topic';
  target: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Only service-role callers (admin panel, scheduled jobs).
    const authHeader = req.headers.get('Authorization');
    if (authHeader !== `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { target_type, target, title, body, data }: PushRequest = await req.json();
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!;
    const accessToken = await getFirebaseAccessToken();

    let sentCount = 0;

    if (target_type === 'topic') {
      // FCM topic message.
      await sendFcm(accessToken, projectId, {
        topic: target,
        notification: { title, body },
        data,
      });
      sentCount = 1;
    } else {
      // Individual user — look up their FCM tokens.
      const { data: tokens } = await supabase
        .from('device_tokens')
        .select('fcm_token, notify_events, notify_chapters, notify_reminders')
        .eq('user_id', target);

      for (const row of (tokens ?? [])) {
        await sendFcm(accessToken, projectId, {
          token: row.fcm_token as string,
          notification: { title, body },
          data,
        });
        sentCount++;
      }
    }

    // Log the push.
    await supabase.from('notifications_log').insert({
      notification_type: (data?.type ?? 'general') as string,
      audience: target,
      title,
      body,
      sent_count: sentCount,
    });

    return new Response(
      JSON.stringify({ success: true, sent_count: sentCount }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('send-push error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

async function sendFcm(
  accessToken: string,
  projectId: string,
  message: Record<string, unknown>,
): Promise<void> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message }),
    },
  );
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`FCM error: ${err}`);
  }
}

async function getFirebaseAccessToken(): Promise<string> {
  // Uses the Firebase service account JSON stored in FIREBASE_SERVICE_ACCOUNT secret.
  const sa = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!) as {
    client_email: string;
    private_key: string;
  };

  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }));

  const pemKey = sa.private_key.replace(/\\n/g, '\n');
  const keyData = pemKey
    .replace('-----BEGIN RSA PRIVATE KEY-----', '')
    .replace('-----END RSA PRIVATE KEY-----', '')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', keyBytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );

  const sigInput = new TextEncoder().encode(`${header}.${payload}`);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, sigInput);
  const jwt = `${header}.${payload}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await tokenRes.json() as { access_token: string };
  return tokenData.access_token;
}
