// verify-purchase Edge Function
// Verifies a purchase receipt with Apple or Google, grants items to the player.
// NEVER trust the on-device result — only this function grants items.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface VerifyRequest {
  platform: 'ios' | 'android';
  product_id: string;
  transaction_id: string;
  receipt_data: string; // base64 receipt (iOS) or purchase token (Android)
}

interface ProductGrant {
  pearls?: number;
  manna?: number;
  generator_level?: number;
}

// Product catalog — must match products.json in the app.
const PRODUCTS: Record<string, ProductGrant> = {
  pearls_tier1: { pearls: 50 },
  pearls_tier2: { pearls: 270 },
  pearls_tier3: { pearls: 560 },
  pearls_tier4: { pearls: 1200 },
  pearls_tier5: { pearls: 3200 },
  pearls_tier6: { pearls: 7000 },
  starter_pack: { pearls: 100, manna: 100, generator_level: 2 },
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Authenticate the request — user must be signed in.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body: VerifyRequest = await req.json();
    const { platform, product_id, transaction_id, receipt_data } = body;

    // 1. Check for duplicate transaction (prevents double-grants).
    const { data: existing } = await supabase
      .from('purchases')
      .select('id, status')
      .eq('transaction_id', transaction_id)
      .single();

    if (existing) {
      if (existing.status === 'granted') {
        return new Response(
          JSON.stringify({ success: true, already_granted: true }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
    }

    // 2. Verify with the store.
    let verified = false;
    let rawVerification: unknown = null;

    if (platform === 'ios') {
      ({ verified, rawVerification } = await verifyApple(product_id, transaction_id, receipt_data));
    } else {
      ({ verified, rawVerification } = await verifyGoogle(product_id, receipt_data));
    }

    if (!verified) {
      return new Response(
        JSON.stringify({ success: false, error: 'Verification failed' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // 3. Insert the purchase record (unique constraint prevents duplicates).
    const { error: insertError } = await supabase.from('purchases').insert({
      user_id: user.id,
      platform,
      product_id,
      transaction_id,
      status: 'granted',
      raw_verification: rawVerification as Record<string, unknown>,
      granted_at: new Date().toISOString(),
    });

    if (insertError) {
      // If unique constraint violation, the purchase was already granted.
      if (insertError.code === '23505') {
        return new Response(
          JSON.stringify({ success: true, already_granted: true }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      throw insertError;
    }

    // 4. Grant items.
    const grant = PRODUCTS[product_id];
    if (grant) {
      await supabase.from('wallet_grants').insert({
        user_id: user.id,
        grant_type: 'purchase',
        pearls_delta: grant.pearls ?? 0,
        items_delta: grant.generator_level
          ? [{ type: 'generator', level: grant.generator_level }]
          : [],
        note: `Purchase: ${product_id}`,
      });
    }

    return new Response(
      JSON.stringify({ success: true, grant }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('verify-purchase error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

// ---- Platform verifiers ----

async function verifyApple(
  productId: string,
  transactionId: string,
  receiptData: string,
): Promise<{ verified: boolean; rawVerification: unknown }> {
  // Apple App Store Server API verification.
  // Secrets loaded from Supabase Edge Function secrets (never in code).
  const keyId = Deno.env.get('APPLE_IAP_KEY_ID');
  const issuerId = Deno.env.get('APPLE_IAP_ISSUER_ID');
  const privateKey = Deno.env.get('APPLE_IAP_PRIVATE_KEY');
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.whispersofjoppa.game';

  if (!keyId || !issuerId || !privateKey) {
    console.error('Apple IAP secrets not configured');
    return { verified: false, rawVerification: null };
  }

  // Build a JWT for the App Store Server API.
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 3600,
    aud: 'appstoreconnect-v1',
    bid: bundleId,
  }));

  // Import the private key and sign.
  const pemKey = privateKey.replace(/\\n/g, '\n');
  const keyData = pemKey
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', keyBytes.buffer,
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'],
  );
  const sigInput = new TextEncoder().encode(`${header}.${payload}`);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, cryptoKey, sigInput);
  const token = `${header}.${payload}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`;

  // Verify the transaction.
  const url = `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) {
    // Try sandbox if production fails.
    const sandboxUrl = `https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/${transactionId}`;
    const sandboxRes = await fetch(sandboxUrl, { headers: { Authorization: `Bearer ${token}` } });
    if (!sandboxRes.ok) return { verified: false, rawVerification: await sandboxRes.json() };
    const data = await sandboxRes.json();
    return { verified: (data as Record<string, unknown>).bundleId === bundleId, rawVerification: data };
  }
  const data = await res.json();
  return { verified: (data as Record<string, unknown>).bundleId === bundleId, rawVerification: data };
}

async function verifyGoogle(
  productId: string,
  purchaseToken: string,
): Promise<{ verified: boolean; rawVerification: unknown }> {
  // Google Play Developer API verification.
  const serviceAccount = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT');
  const packageName = Deno.env.get('ANDROID_PACKAGE_NAME') ?? 'com.whispersofjoppa.game';

  if (!serviceAccount) {
    console.error('Google Play service account not configured');
    return { verified: false, rawVerification: null };
  }

  const sa = JSON.parse(serviceAccount) as {
    client_email: string;
    private_key: string;
  };

  // Get an access token via JWT.
  const now = Math.floor(Date.now() / 1000);
  const jwtHeader = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const jwtPayload = btoa(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
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
  const sigInput = new TextEncoder().encode(`${jwtHeader}.${jwtPayload}`);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, sigInput);
  const jwt = `${jwtHeader}.${jwtPayload}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await tokenRes.json() as { access_token?: string };
  if (!tokenData.access_token) return { verified: false, rawVerification: tokenData };

  // Verify the purchase.
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${tokenData.access_token}` },
  });
  if (!res.ok) return { verified: false, rawVerification: await res.json() };
  const data = await res.json() as { purchaseState?: number };
  // purchaseState 0 = Purchased.
  return { verified: data.purchaseState === 0, rawVerification: data };
}
