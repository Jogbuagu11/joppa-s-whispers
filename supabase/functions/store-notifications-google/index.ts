// store-notifications-google Edge Function
// Called two ways, both with ?key=<STORE_NOTIFY_SECRET> in the URL:
//  - by a Google Cloud Pub/Sub push subscription, when Google Play sends a
//    real-time developer notification;
//  - once a day by a scheduled job with ?sweep=1, as a safety net.
//
// What a notification says is never trusted. It is only a nudge to ask
// Google for its list of voided (refunded or charged-back) purchases, and
// only purchases on that list are marked refunded.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  googleNotificationKind,
  sameSecret,
  voidedOrderIds,
} from '../_shared/refund_rules.ts';
import { recordRefund } from '../_shared/refunds.ts';
import { googleAccessToken } from '../_shared/stores.ts';

const MAX_PAGES = 20;

serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const url = new URL(req.url);
  if (!sameSecret(url.searchParams.get('key'), Deno.env.get('STORE_NOTIFY_SECRET'))) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const packageName = Deno.env.get('ANDROID_PACKAGE_NAME') ?? 'com.whispersofjoppa.game';
    const sweep = url.searchParams.get('sweep') === '1';
    if (!sweep) {
      const body = await req.json().catch(() => null);
      // Other notifications (a purchase made, a test message) need nothing.
      if (googleNotificationKind(body, packageName) !== 'voided') {
        return new Response('ok', { status: 200 });
      }
    }

    const accessToken = await googleAccessToken();
    if (!accessToken) return new Response('Not configured', { status: 500 });
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Google's list covers the last 30 days; recording is safe to repeat.
    let pageToken: string | undefined;
    let recorded = 0;
    for (let page = 0; page < MAX_PAGES; page++) {
      const listUrl = new URL(
        `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}` +
          '/purchases/voidedpurchases',
      );
      if (pageToken) listUrl.searchParams.set('token', pageToken);
      const res = await fetch(listUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
      if (!res.ok) throw new Error(`Voided purchases list failed: ${res.status}`);
      const reply = await res.json() as {
        tokenPagination?: { nextPageToken?: string };
      };
      for (const orderId of voidedOrderIds(reply)) {
        if (await recordRefund(supabase, orderId, 'Google')) recorded++;
      }
      pageToken = reply.tokenPagination?.nextPageToken;
      if (!pageToken) break;
    }
    console.log(`Google voided purchases checked: ${recorded} newly recorded`);
    return new Response('ok', { status: 200 });
  } catch (err) {
    // A 500 makes Pub/Sub deliver the notification again later.
    console.error('store-notifications-google error:', err);
    return new Response('Internal error', { status: 500 });
  }
});
