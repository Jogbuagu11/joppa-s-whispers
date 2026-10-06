// Whispers of Joppa admin panel: what a valid event looks like.
// Plain JavaScript, loaded before admin.js.
const TEMPLATE = {
  board: { cols: 5, rows: 7 },
  chain: {
    id: "my_chain",
    placeholder_color: "#3A7CA5",
    name: "Chain name",
    tiers: [1, 2, 3, 4, 5, 6].map((t) => ({
      tier: t,
      item_id: "my_chain_0" + t,
      name: "Item " + t,
      sell: t,
    })),
  },
  generator: {
    id: "gen_my_event",
    name: "Generator name",
    chain_id: "my_chain",
    col: 2,
    row: 6,
    levels: [{ level: 1, odds: { "1": 0.85, "2": 0.15 } }],
  },
  milestones: [{ points: 10, manna: 10 }, { points: 30, talents: 30 }],
};

// The checks the game makes before it will show an event (the game also
// tries building the event's board, and checks again on every phone, so a
// mistake that slips past here still cannot reach a player).
// Keep in step with lib/data/event_validator.dart.
function eventProblems(ev) {
  const p = [];
  const short = (v) => typeof v === "string" && v.trim() !== "" && v.length <= 40;
  if (!/^[a-z0-9_]{1,40}$/.test(ev.id || "")) p.push("Id must be lowercase letters, digits and _.");
  if (!short(ev.name)) p.push("Name must be 1 to 40 characters.");
  const s = Date.parse(ev.starts_at), e = Date.parse(ev.ends_at);
  if (isNaN(s) || isNaN(e)) p.push("Start and end must both be set.");
  else if (e <= s) p.push("The event must end after it starts.");
  const c = ev.config;
  if (!c || typeof c !== "object") return p.concat("The settings box is empty.");
  const cols = c.board && c.board.cols, rows = c.board && c.board.rows;
  if (
    !Number.isInteger(cols) || !Number.isInteger(rows) || cols < 3 || cols > 7 || rows < 3 ||
    rows > 9
  ) p.push("Board must be 3-7 columns by 3-9 rows.");
  const tiers = c.chain && c.chain.tiers;
  if (
    !c.chain || typeof c.chain.id !== "string" || !Array.isArray(tiers) || tiers.length < 2 ||
    tiers.length > 12
  ) p.push("The chain needs an id and 2 to 12 tiers.");
  else {
    const ids = new Set();
    tiers.forEach((t, i) => {
      const art = t && t.asset;
      const artOk = art == null ||
        (typeof art === "string" && art.length <= 120 &&
          (art === "" || /^assets\/items\/[A-Za-z0-9_.]+$/.test(art)));
      if (
        !t || t.tier !== i + 1 || !Number.isInteger(t.tier) || !short(t.item_id) ||
        !short(t.name) || !Number.isInteger(t.sell) ||
        !artOk || ids.has(t.item_id)
      ) p.push("Chain tier " + (i + 1) + " is wrong or repeated.");
      if (t) ids.add(t.item_id);
    });
    if (c.chain.placeholder_color != null && typeof c.chain.placeholder_color !== "string") {
      p.push('placeholder_color must be text like "#3A7CA5".');
    }
  }
  const g = c.generator, max = Array.isArray(tiers) ? tiers.length : 0;
  if (!g || typeof g !== "object") p.push("The generator is missing.");
  else {
    if (!short(g.id) || !short(g.name)) p.push("The generator needs an id and a name.");
    if (!c.chain || g.chain_id !== c.chain.id) {
      p.push("The generator's chain_id must be the event chain's id.");
    }
    if (
      g.energy_cost != null &&
      (!Number.isInteger(g.energy_cost) || g.energy_cost < 0 || g.energy_cost > 20)
    ) p.push("energy_cost must be 0 to 20.");
    if (
      !Number.isInteger(g.col) || !Number.isInteger(g.row) || g.col < 0 || g.row < 0 ||
      g.col >= cols || g.row >= rows
    ) p.push("The generator must sit on the event board.");
    if (!Array.isArray(g.levels) || g.levels.length === 0) {
      p.push("The generator needs at least one level.");
    } else {g.levels.forEach((l, i) => {
        if (!l || l.level !== i + 1 || !l.odds || typeof l.odds !== "object") {
          p.push("Generator level " + (i + 1) + " is wrong.");
          return;
        }
        let total = 0, bad = false;
        if (Object.keys(l.odds).length === 0) bad = true;
        for (const [k, v] of Object.entries(l.odds)) {
          const t = /^[0-9]+$/.test(k) ? parseInt(k, 10) : NaN;
          if (!(t >= 1 && t <= max) || typeof v !== "number" || v <= 0) bad = true;
          total += v;
        }
        if (bad) p.push("Generator level " + (i + 1) + " has odds for a tier that does not exist.");
        else if (Math.abs(total - 1) > 0.001) {
          p.push("Generator level " + (i + 1) + " odds must add up to 1.");
        }
      });}
  }
  const m = c.milestones;
  if (!Array.isArray(m) || m.length === 0 || m.length > 40) {
    p.push("There must be 1 to 40 reward steps.");
  } else {
    let last = 0;
    for (const step of m) {
      if (!step || !Number.isInteger(step.points) || step.points <= last) {
        p.push("Reward step points must keep rising.");
        break;
      }
      last = step.points;
      const manna = step.manna == null ? 0 : step.manna,
        talents = step.talents == null ? 0 : step.talents;
      if (!Number.isInteger(manna) || !Number.isInteger(talents) || manna < 0 || talents < 0) {
        p.push("Step at " + step.points + " has a bad reward.");
      } else if (manna === 0 && talents === 0) p.push("Step at " + step.points + " gives nothing.");
      else if (manna > 500 || talents > 5000) {
        p.push("Step at " + step.points + " gives too much (max 500 Manna, 5000 Talents).");
      }
    }
  }
  return p;
}
