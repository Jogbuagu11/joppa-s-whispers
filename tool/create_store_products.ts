// Creates the game's in-app purchases in App Store Connect and Google Play.
//
// Run from the project folder (nothing is created without --apply):
//   deno run -A tool/create_store_products.ts                 # show the plan
//   deno run -A tool/create_store_products.ts --apply --apple
//   deno run -A tool/create_store_products.ts --apply --google
//   ... --only=pearls_tier5,pearls_tier6      # just these products
//
// What to create is in tool/store_products.json. The amounts in each
// description ({pearls}, {manna}) are filled in from content/products.json,
// so the store text can never promise something the game does not give.
//
// Secrets come from .env (never in git):
//   APPLE_API_KEY_PATH=AuthKey_XXXXXXXXXX.p8
//   APPLE_API_KEY_ID=XXXXXXXXXX
//   APPLE_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
//   GOOGLE_PLAY_SERVICE_ACCOUNT_PATH=play-service-account.json
//
// Safe to run again: products that already exist are left as they are and
// only their missing pieces (text, price, availability) are added.

interface Product {
  id: string;
  consumable: boolean;
  usd: string;
  name: string;
  description: string;
}
interface Result {
  store: string;
  id: string;
  outcome: string;
}

const args = new Set(Deno.args);
const apply = args.has("--apply");
const config = JSON.parse(await Deno.readTextFile("tool/store_products.json"));
const content = JSON.parse(
  await Deno.readTextFile("content/products.json"),
) as Array<
  Record<string, unknown>
>;
const results: Result[] = [];

function env(): Record<string, string> {
  const out: Record<string, string> = {};
  try {
    for (const line of Deno.readTextFileSync(".env").split("\n")) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m) out[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  } catch (_) {
    // No .env file: every secret counts as missing and is reported below.
  }
  return out;
}

/** The products with their descriptions filled in from the game's content. */
function products(): Product[] {
  // --only=id,id limits a run to some products (to finish ones that failed).
  const only = Deno.args.find((x) => x.startsWith("--only="))?.slice(7).split(
    ",",
  );
  return (config.products as Product[]).filter((p) =>
    !only || only.includes(p.id)
  ).map((p) => {
    const gives = content.find((c) => c.id === p.id);
    if (!gives) throw new Error(`${p.id} is not in content/products.json`);
    if ((gives.type === "consumable") !== p.consumable) {
      throw new Error(
        `${p.id}: consumable does not match content/products.json`,
      );
    }
    const number = (n: unknown) => Number(n ?? 0).toLocaleString("en-US");
    return {
      ...p,
      description: p.description
        .replace("{pearls}", number(gives.pearls))
        .replace("{manna}", number(gives.manna)),
    };
  });
}

const b64url = (input: string | Uint8Array) => {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

function importKey(
  pem: string,
  algorithm: EcKeyImportParams | RsaHashedImportParams,
) {
  const body = pem.replace(/-----(BEGIN|END)( RSA)? PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const bytes = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", bytes.buffer, algorithm, false, [
    "sign",
  ]);
}

// ---------------------------------------------------------------- Apple

async function appleToken(e: Record<string, string>): Promise<string> {
  const key = await importKey(await Deno.readTextFile(e.APPLE_API_KEY_PATH), {
    name: "ECDSA",
    namedCurve: "P-256",
  });
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(
    JSON.stringify({ alg: "ES256", kid: e.APPLE_API_KEY_ID, typ: "JWT" }),
  );
  const body = b64url(JSON.stringify({
    iss: e.APPLE_API_ISSUER_ID,
    iat: now,
    exp: now + 900,
    aud: "appstoreconnect-v1",
  }));
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${head}.${body}`),
  );
  return `${head}.${body}.${b64url(new Uint8Array(sig))}`;
}

async function apple(e: Record<string, string>) {
  const token = await appleToken(e);
  const api = async (method: string, path: string, body?: unknown) => {
    const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    const data = text ? JSON.parse(text) : {};
    if (!res.ok) {
      const detail = (data.errors ?? []).map((
        x: { detail?: string; title?: string },
      ) => x.detail ?? x.title).join("; ");
      throw new Error(
        `${method} ${path.split("?")[0]} → ${res.status}: ${detail}`,
      );
    }
    return data;
  };

  const appId = config.apple_app_id as string;
  const existing = await api(
    "GET",
    `/v1/apps/${appId}/inAppPurchasesV2?limit=200`,
  );
  const byProductId = new Map<string, string>(
    existing.data.map((
      d: { id: string; attributes: { productId: string } },
    ) => [
      d.attributes.productId,
      d.id,
    ]),
  );
  const territories = (await api("GET", "/v1/territories?limit=200")).data.map(
    (t: { id: string }) => ({ type: "territories", id: t.id }),
  );

  for (const p of products()) {
    const done: string[] = [];
    try {
      let iap = byProductId.get(p.id);
      if (!iap) {
        const created = await api("POST", "/v2/inAppPurchases", {
          data: {
            type: "inAppPurchases",
            attributes: {
              name: p.name,
              productId: p.id,
              inAppPurchaseType: p.consumable ? "CONSUMABLE" : "NON_CONSUMABLE",
            },
            relationships: { app: { data: { type: "apps", id: appId } } },
          },
        });
        iap = created.data.id as string;
        done.push("created");
      } else {
        done.push("already existed");
      }
      const rel = { data: { type: "inAppPurchases", id: iap } };

      const texts = await api(
        "GET",
        `/v2/inAppPurchases/${iap}/inAppPurchaseLocalizations`,
      );
      if (
        !texts.data.some((l: { attributes: { locale: string } }) =>
          l.attributes.locale === config.locale
        )
      ) {
        await api("POST", "/v1/inAppPurchaseLocalizations", {
          data: {
            type: "inAppPurchaseLocalizations",
            attributes: {
              locale: config.locale,
              name: p.name,
              description: p.description,
            },
            relationships: { inAppPurchaseV2: rel },
          },
        });
        done.push("English text added");
      }

      // Apple lists several hundred price points, a page at a time.
      let point: { id: string } | undefined;
      let page: string | null =
        `/v2/inAppPurchases/${iap}/pricePoints?filter[territory]=USA&limit=200`;
      while (page && !point) {
        const points = await api("GET", page);
        point = points.data.find(
          (x: { attributes: { customerPrice: string } }) =>
            Number(x.attributes.customerPrice) === Number(p.usd),
        );
        const next = points.links?.next as string | undefined;
        page = next
          ? next.replace("https://api.appstoreconnect.apple.com", "")
          : null;
      }
      if (!point) throw new Error(`Apple has no US price point of $${p.usd}`);
      await api("POST", "/v1/inAppPurchasePriceSchedules", {
        data: {
          type: "inAppPurchasePriceSchedules",
          relationships: {
            inAppPurchase: rel,
            baseTerritory: { data: { type: "territories", id: "USA" } },
            manualPrices: {
              data: [{ type: "inAppPurchasePrices", id: "${price}" }],
            },
          },
        },
        included: [{
          type: "inAppPurchasePrices",
          id: "${price}",
          attributes: { startDate: null },
          relationships: {
            inAppPurchasePricePoint: {
              data: { type: "inAppPurchasePricePoints", id: point.id },
            },
          },
        }],
      });
      done.push(`US price $${p.usd} (other countries set by Apple)`);

      await api("POST", "/v1/inAppPurchaseAvailabilities", {
        data: {
          type: "inAppPurchaseAvailabilities",
          attributes: { availableInNewTerritories: true },
          relationships: {
            inAppPurchase: rel,
            availableTerritories: { data: territories },
          },
        },
      });
      done.push(`available in ${territories.length} countries`);
      results.push({ store: "Apple", id: p.id, outcome: done.join(", ") });
    } catch (err) {
      results.push({
        store: "Apple",
        id: p.id,
        outcome: `${done.join(", ")}${done.length ? "; then " : ""}FAILED: ${
          (err as Error).message
        }`,
      });
    }
  }
}

// ---------------------------------------------------------------- Google

async function googleToken(e: Record<string, string>): Promise<string> {
  const sa = JSON.parse(
    await Deno.readTextFile(e.GOOGLE_PLAY_SERVICE_ACCOUNT_PATH),
  );
  const key = await importKey(sa.private_key, {
    name: "RSASSA-PKCS1-v1_5",
    hash: "SHA-256",
  });
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const body = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 900,
  }));
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${head}.${body}`),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${head}.${body}.${
        b64url(new Uint8Array(sig))
      }`,
  });
  const data = await res.json();
  if (!data.access_token) {
    throw new Error(`Google sign-in failed: ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

async function google(e: Record<string, string>) {
  const token = await googleToken(e);
  const base =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${config.android_package}/inappproducts`;
  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
  for (const p of products()) {
    try {
      const found = await fetch(`${base}/${p.id}`, { headers });
      await found.body?.cancel();
      if (found.ok) {
        results.push({
          store: "Google",
          id: p.id,
          outcome: "already existed (left as it is)",
        });
        continue;
      }
      const res = await fetch(`${base}?autoConvertMissingPrices=true`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          packageName: config.android_package,
          sku: p.id,
          status: "active",
          // Google has one product kind for both; the game consumes Pearl
          // packs after delivery and never consumes the starter pack.
          purchaseType: "managedUser",
          defaultLanguage: config.locale,
          defaultPrice: {
            priceMicros: String(Math.round(Number(p.usd) * 1e6)),
            currency: "USD",
          },
          listings: {
            [config.locale]: { title: p.name, description: p.description },
          },
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(
          `${res.status}: ${data.error?.message ?? JSON.stringify(data)}`,
        );
      }
      results.push({
        store: "Google",
        id: p.id,
        outcome:
          `created, active, US price $${p.usd} (other countries converted by Google)`,
      });
    } catch (err) {
      results.push({
        store: "Google",
        id: p.id,
        outcome: `FAILED: ${(err as Error).message}`,
      });
    }
  }
}

// ---------------------------------------------------------------- main

const e = env();
console.log("Products to create (text filled in from the game's content):\n");
for (const p of products()) {
  console.log(
    `  ${p.id.padEnd(13)} ${
      p.consumable ? "Consumable    " : "Non-consumable"
    } $${p.usd.padStart(5)}  ` +
      `"${p.name}" — "${p.description}"`,
  );
}
const missing = (keys: string[]) => keys.filter((k) => !e[k]);
const appleMissing = missing([
  "APPLE_API_KEY_PATH",
  "APPLE_API_KEY_ID",
  "APPLE_API_ISSUER_ID",
]);
const googleMissing = missing(["GOOGLE_PLAY_SERVICE_ACCOUNT_PATH"]);
console.log(
  `\nApple:  ${
    appleMissing.length
      ? "missing in .env: " + appleMissing.join(", ")
      : "ready"
  }`,
);
console.log(
  `Google: ${
    googleMissing.length
      ? "missing in .env: " + googleMissing.join(", ")
      : "ready"
  }`,
);

if (!apply) {
  console.log(
    "\nNothing was created. Add --apply with --apple and/or --google to create them.",
  );
} else {
  if (args.has("--apple")) {
    if (appleMissing.length) console.log("\nSkipping Apple: not configured.");
    else {await apple(e).catch((err) =>
        results.push({
          store: "Apple",
          id: "(all)",
          outcome: `FAILED: ${err.message}`,
        })
      );}
  }
  if (args.has("--google")) {
    if (googleMissing.length) console.log("\nSkipping Google: not configured.");
    else {await google(e).catch((err) =>
        results.push({
          store: "Google",
          id: "(all)",
          outcome: `FAILED: ${err.message}`,
        })
      );}
  }
  console.log("\nResult:");
  for (const r of results) {
    console.log(`  ${r.store.padEnd(6)} ${r.id.padEnd(13)} ${r.outcome}`);
  }
}
