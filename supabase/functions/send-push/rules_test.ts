// Run with: deno test supabase/functions/send-push/rules_test.ts
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';
import { checkPush } from './rules.ts';

Deno.test('a complete push to a known audience may be sent, trimmed', () => {
  const result = checkPush({ topic: 'events', title: ' Boat Festival ', body: 'It begins today.' });
  assertEquals(result, {
    ok: true,
    push: { topic: 'events', title: 'Boat Festival', body: 'It begins today.' },
  });
});

Deno.test('unknown audiences and junk are refused', () => {
  assertEquals(checkPush({ topic: 'everyone', title: 'a', body: 'b' }).ok, false);
  assertEquals(checkPush({ topic: 'events' }).ok, false);
  assertEquals(checkPush(null).ok, false);
  assertEquals(checkPush('events').ok, false);
});

Deno.test('empty or over-long text is refused', () => {
  assertEquals(checkPush({ topic: 'chapters', title: '  ', body: 'b' }).ok, false);
  assertEquals(checkPush({ topic: 'chapters', title: 'x'.repeat(51), body: 'b' }).ok, false);
  assertEquals(checkPush({ topic: 'chapters', title: 'a', body: '' }).ok, false);
  assertEquals(checkPush({ topic: 'chapters', title: 'a', body: 'x'.repeat(151) }).ok, false);
});
