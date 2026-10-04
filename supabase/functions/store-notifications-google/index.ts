// store-notifications-google Edge Function
// Receives Google Play real-time developer notifications via Pub/Sub.
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

    // Pub/Sub message format.
    const pubsubMessage = await req.json() as {
      message?: { data?: string };
    };
    const data = pubsubMessage.message?.data;
    if (!data) {
      return new Response('ok', { status: 200 }); // acknowledge empty
    }

    const notification = JSON.parse(atob(data)) as {
      packageName?: string;
      oneTimeProductNotification?: {
        sku?: string;
        purchaseToken?: string;
        notificationType?: number;
      };
      voidedPurchaseNotification?: {
        purchaseToken?: string;
        productType?: number;
      };
    };

    // Notification type 4 = PURCHASED, 1 = CANCELED/REFUNDED.
    const otp = notification.oneTimeProductNotification;
    const voided = notification.voidedPurchaseNotification;

    if (otp?.notificationType === 1 || voided) {
      const purchaseToken = otp?.purchaseToken ?? voided?.purchaseToken;
      if (purchaseToken) {
        await handleVoidedPurchase(supabase, purchaseToken, otp?.sku ?? '');
      }
    }

    return new Response('ok', { status: 200 });
  } catch (err) {
    console.error('store-notifications-google error:', err);
    return new Response('ok', { status: 200 }); // always 200 to Pub/Sub
  }
});

async function handleVoidedPurchase(
  supabase: ReturnType<typeof createClient>,
  purchaseToken: string,
  productId: string,
): Promise<void> {
  // Google uses purchase_token as the transaction_id in our schema.
  const { data: purchase } = await supabase
    .from('purchases')
    .select('id, user_id, product_id')
    .eq('transaction_id', purchaseToken)
    .single();

  if (!purchase) {
    console.warn(`Refund for unknown token: ${purchaseToken}`);
    return;
  }

  const resolvedProductId = productId || (purchase.product_id as string);

  await supabase
    .from('purchases')
    .update({ status: 'refunded', refunded_at: new Date().toISOString() })
    .eq('transaction_id', purchaseToken);

  const pearlsToRemove = getPearlsForProduct(resolvedProductId);
  if (pearlsToRemove > 0) {
    await supabase.from('wallet_grants').insert({
      user_id: purchase.user_id,
      purchase_id: purchase.id,
      grant_type: 'refund',
      pearls_delta: -pearlsToRemove,
      note: `Refund: ${resolvedProductId} (Google)`,
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
