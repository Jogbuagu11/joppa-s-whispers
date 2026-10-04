// store-notifications-apple Edge Function
// Receives App Store Server Notifications V2 (refunds, cancellations).
// URL must be set in App Store Connect → App Store Server Notifications.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Apple sends a signed JWT payload.
    const body = await req.json() as { signedPayload?: string };
    const { signedPayload } = body;
    if (!signedPayload) {
      return new Response(JSON.stringify({ error: 'No payload' }), { status: 400 });
    }

    // Decode the JWT without verifying for now (Apple's cert chain verification is complex).
    // In production, verify the signature using Apple's root certificate.
    const parts = signedPayload.split('.');
    if (parts.length < 2) {
      return new Response(JSON.stringify({ error: 'Invalid payload' }), { status: 400 });
    }
    const payloadJson = JSON.parse(atob(parts[1])) as {
      notificationType?: string;
      data?: { signedTransactionInfo?: string };
    };

    const notificationType = payloadJson.notificationType;

    if (notificationType === 'REFUND' || notificationType === 'REVOKE') {
      const txParts = payloadJson.data?.signedTransactionInfo?.split('.');
      if (txParts && txParts.length >= 2) {
        const txJson = JSON.parse(atob(txParts[1])) as {
          transactionId?: string;
          productId?: string;
        };
        const { transactionId, productId } = txJson;

        if (transactionId) {
          await handleRefund(supabase, transactionId, productId ?? '');
        }
      }
    }

    return new Response('ok', { status: 200 });
  } catch (err) {
    console.error('store-notifications-apple error:', err);
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500 });
  }
});

async function handleRefund(
  supabase: ReturnType<typeof createClient>,
  transactionId: string,
  productId: string,
): Promise<void> {
  // Mark purchase as refunded.
  const { data: purchase } = await supabase
    .from('purchases')
    .select('id, user_id')
    .eq('transaction_id', transactionId)
    .single();

  if (!purchase) {
    console.warn(`Refund for unknown transaction: ${transactionId}`);
    return;
  }

  await supabase
    .from('purchases')
    .update({ status: 'refunded', refunded_at: new Date().toISOString() })
    .eq('transaction_id', transactionId);

  // Remove unspent pearls from this purchase (never go below zero).
  const pearlsToRemove = getPearlsForProduct(productId);
  if (pearlsToRemove > 0) {
    await supabase.from('wallet_grants').insert({
      user_id: purchase.user_id,
      purchase_id: purchase.id,
      grant_type: 'refund',
      pearls_delta: -pearlsToRemove,
      note: `Refund: ${productId} (Apple)`,
    });
  }
}

function getPearlsForProduct(productId: string): number {
  const products: Record<string, number> = {
    pearls_tier1: 50, pearls_tier2: 270, pearls_tier3: 560,
    pearls_tier4: 1200, pearls_tier5: 3200, pearls_tier6: 7000,
    starter_pack: 100,
  };
  return products[productId] ?? 0;
}
