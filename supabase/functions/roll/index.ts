// roll Edge Function
// Draws a prize for a paid try at the Blessing Wheel or a bought Jar of
// Clay, on the server, from the same table the player is shown, and keeps a
// record of every draw. The game asks here when a player stakes Pearls on
// chance; free tries are drawn on the phone.
//
// The decisions live in rules.ts (tested by rules_test.ts).
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { pickPrize, type Prize, secureRandom, tableFor } from './rules.ts';
import { CONTENT_VERSION, TABLES } from './tables.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Unauthorized' }, 401);
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );
    if (authError || !user) return json({ error: 'Unauthorized' }, 401);

    const body = await req.json() as Record<string, unknown>;
    // The game says which tables it is showing the player. If they are not
    // the ones this function holds, it must not draw: the game then draws
    // on the phone, from the table on the screen.
    if (body.content_version !== CONTENT_VERSION) {
      return json({ success: false, error: 'Other tables', version: CONTENT_VERSION }, 409);
    }
    const table = tableFor(TABLES, body);
    if (!table) return json({ success: false, error: 'Bad request' }, 400);
    const paid = body.paid !== false;
    const prize: Prize | null = pickPrize(table, paid, secureRandom());
    if (!prize) return json({ success: false, error: 'Nothing to draw' }, 400);

    // Kept for the record: what was drawn, for whom, from which tables.
    const { error: logError } = await supabase.from('rolls').insert({
      user_id: user.id,
      kind: body.kind === 'jar' ? `jar:${body.jar}` : 'wheel',
      paid,
      prize_id: prize.id,
      content_version: CONTENT_VERSION,
    });
    if (logError) throw logError;

    return json({ success: true, prize_id: prize.id }, 200);
  } catch (err) {
    console.error('roll error:', err);
    return json({ success: false, error: 'Internal error' }, 500);
  }
});
