// Talking to Apple and Google with the server's own keys. Used by
// verify-purchase and by the refund notification functions.
import { b64url, decodeJwsPayload } from '../verify-purchase/rules.ts';
import { isAppleNotFound } from './refund_rules.ts';

function importPkcs8(pem: string, algorithm: EcKeyImportParams | RsaHashedImportParams) {
  const body = pem
    .replace(/\\n/g, '\n')
    .replace(/-----(BEGIN|END)( RSA)? PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const bytes = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', bytes.buffer, algorithm, false, ['sign']);
}

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

export type AppleLookup =
  | { status: 'not_configured' | 'unknown'; tx: null }
  | { status: 'found'; tx: Record<string, unknown> | null };

/**
 * A transaction as Apple itself reports it (Get Transaction Info). The reply
 * is fetched from Apple over TLS with our own key, so its signed payload is
 * read directly.
 */
export async function fetchAppleTransaction(
  bundleId: string,
  transactionId: string,
): Promise<AppleLookup> {
  const token = await appleToken(bundleId);
  if (!token) return { status: 'not_configured', tx: null };
  // Production first, then the sandbox (testers and App Review use it).
  let failure: number | null = null;
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const res = await fetch(
      `https://${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (res.ok) {
      const reply = await res.json() as Record<string, unknown>;
      return { status: 'found', tx: decodeJwsPayload(reply.signedTransactionInfo) };
    }
    await res.body?.cancel();
    if (!isAppleNotFound(res.status)) failure = res.status;
  }
  // "Apple has no such transaction" is an answer. Anything else (Apple busy
  // or down, a key problem) is not: the caller must try again later rather
  // than take it as "unknown".
  if (failure !== null) throw new Error(`Apple could not be asked (HTTP ${failure})`);
  return { status: 'unknown', tx: null };
}

// ---- Google ----

export async function googleAccessToken(): Promise<string | null> {
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
