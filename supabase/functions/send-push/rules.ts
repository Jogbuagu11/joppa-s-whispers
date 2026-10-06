// The decisions send-push makes, kept free of network and database calls so
// they can be tested (rules_test.ts).

/** The audiences a push can go to: the topics phones join from Settings. */
export const TOPICS = ['events', 'chapters'] as const;
export type Topic = (typeof TOPICS)[number];

export interface PushRequest {
  topic: Topic;
  title: string;
  body: string;
}

/** A request that may be sent, or the reason it may not. */
export function checkPush(
  raw: unknown,
): { ok: true; push: PushRequest } | { ok: false; reason: string } {
  if (!raw || typeof raw !== 'object') return { ok: false, reason: 'Nothing to send' };
  const { topic, title, body } = raw as Record<string, unknown>;
  if (typeof topic !== 'string' || !(TOPICS as readonly string[]).includes(topic)) {
    return { ok: false, reason: 'Choose who it goes to: events or chapters' };
  }
  if (typeof title !== 'string' || title.trim().length === 0 || title.length > 50) {
    return { ok: false, reason: 'The title must be 1 to 50 characters' };
  }
  if (typeof body !== 'string' || body.trim().length === 0 || body.length > 150) {
    return { ok: false, reason: 'The message must be 1 to 150 characters' };
  }
  return { ok: true, push: { topic: topic as Topic, title: title.trim(), body: body.trim() } };
}
