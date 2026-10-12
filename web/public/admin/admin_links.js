// Free Manna codes: the list, and making or ending one. Loaded after
// admin_more.js; uses its helpers ($, say, pretty, db).
"use strict";

async function loadLinks() {
  const { data, error } = await db.from("manna_links").select(
    "code, manna, starts_at, ends_at",
  ).order("ends_at", { ascending: false }).limit(50);
  const body = $("linkRows");
  body.replaceChildren();
  if (error) {
    say("linksMsg", "Could not load the codes: " + error.message);
    return;
  }
  for (const row of data) {
    const tr = document.createElement("tr");
    const over = new Date(row.ends_at) <= new Date();
    for (const text of [row.code, row.manna + " Manna", over ? "Ended" : "Until " + pretty(row.ends_at)]) {
      const td = document.createElement("td");
      td.textContent = text;
      tr.appendChild(td);
    }
    const td = document.createElement("td");
    const remove = document.createElement("button");
    remove.textContent = "End now";
    remove.className = "danger";
    remove.hidden = over;
    // Ended, never deleted: its claims are kept, so the same code can
    // never be made again and claimed twice.
    remove.onclick = async () => {
      if (!confirm("End the code " + row.code + " now? Players can no longer claim it.")) return;
      const { error: gone } = await db.from("manna_links").update({
        ends_at: new Date().toISOString(),
      }).eq("code", row.code);
      say("linksMsg", gone ? "Could not end it: " + gone.message : "Ended.", !gone);
      await loadLinks();
    };
    td.appendChild(remove);
    tr.appendChild(td);
    body.appendChild(tr);
  }
  if (data.length === 0) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.textContent = "No codes yet.";
    tr.appendChild(td);
    body.appendChild(tr);
  }
}

async function addLink() {
  const problems = mannaLinkProblems($("linkCode").value, $("linkManna").value, $("linkDays").value);
  if (problems.length > 0) {
    say("linksMsg", problems.join(" "));
    return;
  }
  const code = $("linkCode").value.trim().toUpperCase();
  const ends = new Date(Date.now() + Number($("linkDays").value) * 24 * 60 * 60 * 1000);
  const { error } = await db.from("manna_links").insert({
    code,
    manna: Number($("linkManna").value),
    ends_at: ends.toISOString(),
  });
  if (error) {
    say("linksMsg", error.code === "23505" ? "That code has been used before. Pick a new one." : "Could not save it: " + error.message);
    return;
  }
  say("linksMsg", "Saved. Tell players to tap the gift button in the game and type " + code + ".", true);
  $("linkCode").value = "";
  await loadLinks();
}

$("addLinkBtn").onclick = addLink;
document.querySelector('nav button[data-tab="links"]').addEventListener("click", loadLinks);
