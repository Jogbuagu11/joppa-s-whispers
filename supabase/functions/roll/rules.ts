// The decisions the roll function makes, kept free of network and database
// calls so they can be tested (see rules_test.ts). The draw is the same sum
// as the game's own (lib/domain/chance.dart): the odds a player is shown
// and the odds a prize is drawn with come from one table.

export interface Prize {
  id: string;
  name: string;
  weight: number;
  manna?: number;
  talents?: number;
  pearls?: number;
  items?: string[];
  generators?: string[];
  /** Never given for a paid try: Pearls are not won with Pearls. */
  free_only?: boolean;
}

export interface Tables {
  wheel: Prize[];
  jars: Record<string, Prize[]>;
}

/** The prizes that can come on a try. A paid try leaves out free-only ones. */
export function openPrizes(prizes: Prize[], paid: boolean): Prize[] {
  return prizes.filter((p) => p.weight > 0 && !(paid && p.free_only));
}

/**
 * The prize for a random number [r] (0 up to, not including, 1), by weight;
 * null if there is nothing to draw.
 */
export function pickPrize(prizes: Prize[], paid: boolean, r: number): Prize | null {
  const open = openPrizes(prizes, paid);
  const total = open.reduce((sum, p) => sum + p.weight, 0);
  if (total <= 0) return null;
  let roll = r;
  for (const prize of open) {
    roll -= prize.weight / total;
    if (roll < 0) return prize;
  }
  // Rounding left a sliver over: it belongs to the last prize.
  return open[open.length - 1];
}

/** The table a request asks to draw from, or null if there is no such. */
export function tableFor(
  tables: Tables,
  request: { kind?: unknown; jar?: unknown },
): Prize[] | null {
  if (request.kind === 'wheel') return tables.wheel;
  if (request.kind === 'jar' && typeof request.jar === 'string') {
    return Object.hasOwn(tables.jars, request.jar) ? tables.jars[request.jar] : null;
  }
  return null;
}

/** A random number from the system's secure source, 0 up to (not including) 1. */
export function secureRandom(): number {
  const buffer = new Uint32Array(1);
  crypto.getRandomValues(buffer);
  return buffer[0] / 0x100000000;
}

// A player cannot stake Pearls faster than this; a program asking over and
// over (to fill the table, or to fish for a prize) is turned away.
export const ROLL_WINDOW_MS = 60_000;
export const MAX_ROLLS_PER_WINDOW = 20;

/** Whether a player with [recent] draws in the last window has had enough. */
export const tooManyRolls = (recent: number): boolean => recent >= MAX_ROLLS_PER_WINDOW;
