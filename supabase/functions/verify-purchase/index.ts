// verify-purchase Edge Function
// Confirms a purchase with Apple or Google and records it for the player.
// NEVER trust the phone: only this function decides a purchase is real, and
// what it checks is what the STORE says, not what the app claims.
//
// The decisions live in rules.ts (tested by rules_test.ts). This file only
// does the talking: to the caller, the stores and the database.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  b64url,
  checkAppleTransaction,
  checkGooglePurchase,
  decideGrant,
  decodeJwsPayload,
  PRODUCTS,
  type Check,
} from './rules.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

interface VerifyRequest {
  platform: 'ios' | 'android';
  product_id: string;
  transaction_id: string;
  receipt_data: string; // Android: the purchase token. iOS: unused.
}

/** What a store said, plus what is needed to finish the purchase there. */
interface StoreResult {
  check: Check;
  raw: unknown;
  consumedAtStore: boolean;
  /** Tells the store the purchase is delivered (Google only). */
  settle?: () => Promise<void>;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // The caller must be a signed-in player.
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Unauthorized' }, 401);
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );
    if (authError || !user) return json({ error: 'Unauthorized' }, 401);

    const body = await req.json() as Partial<VerifyRequest>;
    const { platform, product_id, transaction_id, receipt_data } = body;
    const product = typeof product_id === 'string' ? PRODUCTS[product_id] : undefined;
    if (
      (platform !== 'ios' && platform !== 'android') ||
      !product || typeof product_id !== 'string' ||
      typeof transaction_id !== 'string' || transaction_id.length === 0
    ) {
      return json({ success: false, error: 'Bad request' }, 400);
    }

    // 1. Ask the store. What it says decides everything that follows.
    const store = platform === 'ios'
      ? await verifyApple(product_id, transaction_id, user.id)
      : await verifyGoogle(product_id, String(receipt_data ?? ''), user.id);
    if (!store.check.ok) {
      console.warn(`Rejected ${platform} ${product_id}: ${store.check.reason}`);
      return json({ success: false, error: 'Verification failed' }, 400);
    }
    // The transaction id comes from the store, never from the app.
    const transactionId = store.check.transactionId;

    // 2. Has this transaction been recorded before, and for whom?
    const { data: existing, error: lookupError } = await supabase
      .from('purchases')
      .select('user_id, status')
      .eq('transaction_id', transactionId)
      .maybeSingle();
    if (lookupError) throw lookupError;

    const decision = decideGrant(existing, {
      userId: user.id,
      consumable: product.consumable,
      consumedAtStore: store.consumedAtStore,
    });
    if (decision === 'reject') {
      console.warn(`Rejected ${platform} ${transactionId}: not grantable to this player`);
      return json({ success: false, error: 'Verification failed' }, 400);
    }

    if (decision === 'grant') {
      // 3. Record it. The unique transaction id makes a double grant impossible.
      const { data: inserted, error: insertError } = await supabase
        .from('purchases')
        .insert({
          user_id: user.id,
          platform,
          product_id,
          transaction_id: transactionId,
          status: 'granted',
          raw_verification: store.raw as Record<string, unknown>,
          granted_at: new Date().toISOString(),
        })
        .select('id')
        .single();
      if (insertError) {
        // 23505: two requests raced; the other one recorded it.
        if (insertError.code !== '23505') throw insertError;
      } else {
        await supabase.from('wallet_grants').insert({
          user_id: user.id,
          purchase_id: inserted.id,
          grant_type: 'purchase',
          pearls_delta: product.pearls ?? 0,
          items_delta: product.generator_level
            ? [{ type: 'generator', level: product.generator_level }]
            : [],
          note: `Purchase: ${product_id}`,
        });
      }
    }

    // 4. Only now is the store told the purchase is delivered.
    try {
      await store.settle?.();
    } catch (err) {
      // The grant stands; the app also settles on its side.
      console.error('Could not settle with the store:', err);
    }

    return json({
      success: true,
      already_granted: decision === 'already_granted',
      transaction_id: transactionId,
    }, 200);
  } catch (err) {
    console.error('verify-purchase error:', err);
    return json({ success: false, error: 'Internal error' }, 500);
  }
});

// ---- Apple ----

async function appleToken(bundleId: string): Promise<string | null> {
  const keyId = Deno.env.get('APPLE_IAP_KEY_ID');
  const issuerId = Deno.env.get('APPLE_IAP_ISSUER_ID');
  const privateKey = Deno.env.get('APPLE_IAP_PRIVATE_KEY');
  if (!keyId || !issuerId || !privateKey) {
    console.error('Apple IAP secrets not configured');
    return null;
  }
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = b64url(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 600,
    aud: 'appstoreconnect-v1',
    bid: bundleId,
  }));
  const key = await importPkcs8(privateKey, { name: 'ECDSA', namedCurve: 'P-256' });
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  );
  return `${header}.${payload}.${b64url(new Uint8Array(sig))}`;
}

async function verifyApple(
  productId: string,
  transactionId: string,
  userId: string,
): Promise<StoreResult> {
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.whispersofjoppa.game';
  const fail = (reason: string, raw: unknown = null): StoreResult => ({
    check: { ok: false, reason },
    raw,
    consumedAtStore: false,
  });
  const token = await appleToken(bundleId);
  if (!token) return fail('Apple keys not configured');

  // Production first, then the sandbox (testers and App Review use it).
  let reply: Record<string, unknown> | null = null;
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const res = await fetch(
      `https://${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (res.ok) {
      reply = await res.json();
      break;
    }
    await res.body?.cancel();
  }
  if (!reply) return fail('Apple does not know this transaction');

  // The reply was fetched from Apple over TLS with our own key, so its
  // signed payload is read directly.
  const tx = decodeJwsPayload(reply.signedTransactionInfo);
  return {
    check: checkAppleTransaction(tx, { bundleId, productId, transactionId, userId }),
    raw: tx,
    consumedAtStore: false,
  };
}

// ---- Google ----

async function googleAccessToken(): Promise<string | null> {
  const serviceAccount = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT');
  if (!serviceAccount) {
    console.error('Google Play service account not configured');
    return null;
  }
  const sa = JSON.parse(serviceAccount) as { client_email: string; private_key: string };
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 600,
  }));
  const key = await importPkcs8(sa.private_key, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' });
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
  const data = await res.json() as { access_token?: string };
  return data.access_token ?? null;
}

async function verifyGoogle(
  productId: string,
  purchaseToken: string,
  userId: string,
): Promise<StoreResult> {
  const packageName = Deno.env.get('ANDROID_PACKAGE_NAME') ?? 'com.whispersofjoppa.game';
  const fail = (reason: string, raw: unknown = null): StoreResult => ({
    check: { ok: false, reason },
    raw,
    consumedAtStore: false,
  });
  if (!purchaseToken) return fail('no purchase token');
  const accessToken = await googleAccessToken();
  if (!accessToken) return fail('Google keys not configured');

  const base =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}` +
    `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;
  const auth = { Authorization: `Bearer ${accessToken}` };
  const res = await fetch(base, { headers: auth });
  if (!res.ok) return fail('Google does not know this purchase', await res.json());
  const purchase = await res.json() as Record<string, unknown>;

  const consumable = PRODUCTS[productId]?.consumable ?? false;
  return {
    check: checkGooglePurchase(purchase, { userId }),
    raw: purchase,
    // consumptionState: 0 not yet consumed, 1 consumed.
    consumedAtStore: purchase.consumptionState === 1,
    // A pack is used up so it can be bought again; a one-time product is
    // acknowledged so Google does not refund it automatically.
    settle: async () => {
      if (consumable && purchase.consumptionState === 0) {
        await (await fetch(`${base}:consume`, { method: 'POST', headers: auth })).body?.cancel();
      } else if (!consumable && purchase.acknowledgementState === 0) {
        await (await fetch(`${base}:acknowledge`, { method: 'POST', headers: auth })).body?.cancel();
      }
    },
  };
}

// ---- shared ----

function importPkcs8(pem: string, algorithm: EcKeyImportParams | RsaHashedImportParams) {
  const body = pem
    .replace(/\\n/g, '\n')
    .replace(/-----(BEGIN|END)( RSA)? PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const bytes = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', bytes.buffer, algorithm, false, ['sign']);
}
