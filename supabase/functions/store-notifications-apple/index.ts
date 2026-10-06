// store-notifications-apple Edge Function
// Receives App Store Server Notifications V2. Its URL is set in App Store
// Connect → App Information → App Store Server Notifications.
//
// Anyone can call this URL, so what a notification says is never trusted:
// it only names a transaction to look at. Apple is then asked directly
// whether that transaction was refunded, and only Apple's answer counts.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { appleRefundCandidate, isAppleRevoked } from '../_shared/refund_rules.ts';
import { recordRefund } from '../_shared/refunds.ts';
import { fetchAppleTransaction } from '../_shared/stores.ts';

serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  try {
    const transactionId = appleRefundCandidate(await req.json().catch(() => null));
    // Not about a refund (or unreadable): nothing to do.
    if (!transactionId) return new Response('ok', { status: 200 });

    const bundleId = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.whispersofjoppa.game';
    const found = await fetchAppleTransaction(bundleId, transactionId);
    if (found.status === 'not_configured') {
      // Apple retries later; by then the keys may be in place.
      return new Response('Not configured', { status: 500 });
    }
    if (!isAppleRevoked(found.tx, { bundleId, transactionId })) {
      console.warn(`Apple does not report ${transactionId} as refunded; ignored`);
      return new Response('ok', { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const marked = await recordRefund(supabase, transactionId, 'Apple');
    console.log(`Apple refund ${transactionId}: ${marked ? 'recorded' : 'nothing to change'}`);
    return new Response('ok', { status: 200 });
  } catch (err) {
    // A 500 makes Apple send the notification again later.
    console.error('store-notifications-apple error:', err);
    return new Response('Internal error', { status: 500 });
  }
});
