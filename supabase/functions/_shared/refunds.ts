// Records a refund the store has confirmed.
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { refundPearls } from './refund_rules.ts';

/**
 * Marks the purchase with this transaction id refunded and logs the Pearls
 * to take back. Only a purchase that still stands is changed, so the same
 * refund arriving twice (or from both the notification and the daily check)
 * is recorded once. Returns true if a purchase was marked.
 *
 * The app takes the Pearls out of the player's game the next time it reads
 * its purchases (never below zero).
 */
export async function recordRefund(
  // deno-lint-ignore no-explicit-any
  supabase: SupabaseClient<any, any, any>,
  transactionId: string,
  store: 'Apple' | 'Google',
): Promise<boolean> {
  const { data, error } = await supabase
    .from('purchases')
    .update({ status: 'refunded', refunded_at: new Date().toISOString() })
    .eq('transaction_id', transactionId)
    .eq('status', 'granted')
    .select('id, user_id, product_id');
  if (error) throw error;
  if (!data || data.length === 0) return false;
  for (const purchase of data) {
    const { error: logError } = await supabase.from('wallet_grants').insert({
      user_id: purchase.user_id,
      purchase_id: purchase.id,
      grant_type: 'refund',
      pearls_delta: -refundPearls(purchase.product_id as string),
      // The most that can be taken back; the app takes what is left unspent.
      note: `Refund: ${purchase.product_id} (${store}); up to this many Pearls removed`,
    });
    // The purchase is already marked; a missing audit line must not undo it.
    if (logError) console.error('Could not log refund:', logError);
  }
  return true;
}
