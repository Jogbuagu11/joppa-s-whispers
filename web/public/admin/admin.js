// Whispers of Joppa admin panel. No build step: plain JavaScript.
// The address and public key of the game's server. This key is the same one
// inside the game; by itself it can only do what any player can do.
const SUPABASE_URL = "https://sincvubcsnqzjefzsifq.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpbmN2dWJjc25xemplZnpzaWZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTExNDQxMDUsImV4cCI6MjEwNjcyMDEwNX0.hUOLkC_F_iV3-aH4X3zO9uGc9eTS7Q4W4agQOOv9RNk";
// The sign-in is kept in memory only: closing or reloading the page signs
// out, so nothing is left behind in the browser for another script to find.
const db = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: true },
});
if (window.top !== window.self) document.body.replaceChildren(); // never inside another page's frame
const $ = (id) => document.getElementById(id);
const say = (id, text, good) => {
  const el = $(id);
  el.textContent = text || "";
  el.className = "msg " + (good ? "ok" : "bad");
};

const toLocalInput = (iso) => {
  const d = new Date(iso);
  if (isNaN(d)) return "";
  const z = (n) => String(n).padStart(2, "0");
  return d.getFullYear() + "-" + z(d.getMonth() + 1) + "-" + z(d.getDate()) + "T" +
    z(d.getHours()) + ":" + z(d.getMinutes());
};
const fromLocalInput = (v) => {
  const d = new Date(v);
  return isNaN(d) ? "" : d.toISOString();
};
const pretty = (iso) => {
  const d = new Date(iso);
  return isNaN(d) ? "" : d.toLocaleString();
};

let events = [];
let editingId = null;

async function loadEvents() {
  const { data, error } = await db.from("events").select(
    "id, name, starts_at, ends_at, config, is_active",
  ).order("starts_at", { ascending: false });
  if (error) {
    say("eventsMsg", "Could not read events: " + error.message);
    return;
  }
  events = data;
  const body = $("eventRows");
  body.replaceChildren();
  const now = Date.now();
  for (const ev of events) {
    const tr = document.createElement("tr");
    const live = ev.is_active && Date.parse(ev.starts_at) <= now && now < Date.parse(ev.ends_at);
    const state = !ev.is_active
      ? "No (switched off)"
      : live
      ? "Yes, now"
      : now < Date.parse(ev.starts_at)
      ? "Not yet (starts later)"
      : "No (ended)";
    for (const text of [ev.name + "\n" + ev.id, pretty(ev.starts_at), pretty(ev.ends_at), state]) {
      const td = document.createElement("td");
      td.textContent = text;
      td.className = "pre";
      tr.appendChild(td);
    }
    const td = document.createElement("td");
    const b = document.createElement("button");
    b.textContent = "Open";
    b.className = "plain";
    b.onclick = () => openEvent(ev);
    td.appendChild(b);
    tr.appendChild(td);
    body.appendChild(tr);
  }
  if (events.length === 0) say("eventsMsg", "No events yet.", true);
  else say("eventsMsg", "");
}

function openEvent(ev) {
  editingId = ev ? ev.id : null;
  $("eventForm").hidden = false;
  $("eventFormTitle").textContent = ev ? "Edit event" : "New event";
  $("evId").value = ev ? ev.id : "";
  $("evId").disabled = !!ev;
  $("evName").value = ev ? ev.name : "";
  $("evStart").value = ev ? toLocalInput(ev.starts_at) : "";
  $("evEnd").value = ev ? toLocalInput(ev.ends_at) : "";
  $("evActive").checked = ev ? ev.is_active : false;
  $("evConfig").value = JSON.stringify(ev ? ev.config : TEMPLATE, null, 2);
  $("deleteEventBtn").hidden = !ev;
  say("eventMsg", "");
  $("eventForm").scrollIntoView({ behavior: "smooth" });
}

async function saveEvent() {
  let config;
  try {
    config = JSON.parse($("evConfig").value);
  } catch (e) {
    say("eventMsg", "The settings box is not valid JSON: " + e.message);
    return;
  }
  const ev = {
    id: $("evId").value.trim(),
    name: $("evName").value.trim(),
    starts_at: fromLocalInput($("evStart").value),
    ends_at: fromLocalInput($("evEnd").value),
    config,
    is_active: $("evActive").checked,
  };
  const problems = eventProblems(ev);
  if (problems.length) {
    say("eventMsg", "Not saved:\n• " + problems.join("\n• "));
    return;
  }
  if (!editingId && events.some((e) => e.id === ev.id)) {
    say("eventMsg", "Not saved: that id is already used. Event ids are never re-used.");
    return;
  }
  $("saveEventBtn").disabled = true;
  const { data: saved, error } = editingId
    ? await db.from("events").update(ev).eq("id", editingId).select("id")
    : await db.from("events").insert(ev).select("id");
  $("saveEventBtn").disabled = false;
  if (error) {
    say("eventMsg", "Not saved: " + error.message);
    return;
  }
  if (!saved || saved.length !== 1) {
    say("eventMsg", "Not saved: this event no longer exists (was it deleted in another window?).");
    await loadEvents();
    return;
  }
  say("eventMsg", "Saved.", true);
  editingId = ev.id;
  $("evId").disabled = true;
  $("deleteEventBtn").hidden = false;
  await loadEvents();
}

async function deleteEvent() {
  if (
    !editingId ||
    !confirm(
      'Delete "' + editingId + '" for good? Players in the middle of it will lose the event board.',
    )
  ) return;
  const { error } = await db.from("events").delete().eq("id", editingId);
  if (error) {
    say("eventMsg", "Not deleted: " + error.message);
    return;
  }
  $("eventForm").hidden = true;
  await loadEvents();
}
