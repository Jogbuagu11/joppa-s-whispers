// Whispers of Joppa admin panel: content releases, notifications, the
// account, and wiring the buttons. Loaded after admin.js.
let latestVersion = 0;
async function loadContent() {
  const { data, error } = await db.from("content_versions").select("version, released_at, notes")
    .order("version", { ascending: false }).limit(5);
  if (error) {
    $("contentNow").textContent = "Could not read releases: " + error.message;
    return;
  }
  latestVersion = data.length ? data[0].version : 0;
  $("contentNow").textContent = data.length
    ? "Latest release: version " + latestVersion + " (" + pretty(data[0].released_at) + ")" +
      (data[0].notes ? " — " + data[0].notes : "")
    : "No content has been released yet; players use what shipped in the app.";
}

async function publishContent() {
  const file = $("bundleFile").files[0];
  if (!file) {
    say("contentMsg", "Choose the content file first.");
    return;
  }
  let bundle;
  try {
    bundle = JSON.parse(await file.text());
  } catch (e) {
    say("contentMsg", "That file is not valid JSON.");
    return;
  }
  if (
    !Number.isInteger(bundle.version) || !Number.isInteger(bundle.format) || !bundle.files ||
    typeof bundle.files !== "object"
  ) {
    say("contentMsg", "That is not a content file made for the game.");
    return;
  }
  if (bundle.version <= latestVersion) {
    say(
      "contentMsg",
      "Not released: this file is version " + bundle.version + ", but version " + latestVersion +
        " is already out. A release must be newer.",
    );
    return;
  }
  if (!confirm("Release content version " + bundle.version + " to all players?")) return;
  $("publishBtn").disabled = true;
  const path = "content_v" + bundle.version + ".json";
  const up = await db.storage.from("content").upload(
    path,
    new Blob([JSON.stringify(bundle)], { type: "application/json" }),
    { upsert: false },
  );
  // "Already exists" with no release recorded means an earlier try stopped
  // half way: the file is there, so carry on and record the release.
  const alreadyThere = up.error && /exist|duplicate/i.test(up.error.message || "");
  if (up.error && !alreadyThere) {
    $("publishBtn").disabled = false;
    say("contentMsg", "Not released: the file could not be uploaded (" + up.error.message + ").");
    return;
  }
  const { error } = await db.from("content_versions").insert({
    version: bundle.version,
    storage_path: path,
    notes: $("bundleNotes").value.trim() || null,
  });
  $("publishBtn").disabled = false;
  if (error) {
    say(
      "contentMsg",
      "Not released: the release could not be recorded (" + error.message +
        "). Try again; if it keeps failing, ask Claude to build the file with the next version number.",
    );
    return;
  }
  say("contentMsg", "Version " + bundle.version + " is released.", true);
  await loadContent();
}

async function loadPushLog() {
  const { data, error } = await db.from("notifications_log").select(
    "sent_at, audience, title, body",
  ).order("sent_at", { ascending: false }).limit(20);
  const body = $("pushRows");
  body.replaceChildren();
  for (const row of (error ? [] : data)) {
    const tr = document.createElement("tr");
    for (const text of [pretty(row.sent_at), row.audience, row.title + "\n" + row.body]) {
      const td = document.createElement("td");
      td.textContent = text;
      td.className = "pre";
      tr.appendChild(td);
    }
    body.appendChild(tr);
  }
  if (!error && data.length === 0) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.textContent = "Nothing sent yet.";
    tr.appendChild(td);
    body.appendChild(tr);
  }
}

async function sendPush() {
  const push = {
    topic: $("pushTopic").value,
    title: $("pushTitle").value.trim(),
    body: $("pushBody").value.trim(),
  };
  if (!push.title || !push.body) {
    say("pushMsg", "Write a title and a message.");
    return;
  }
  if (!confirm("Send this notification to players now?")) return;
  $("pushBtn").disabled = true;
  const { data, error } = await db.functions.invoke("send-push", { body: push });
  $("pushBtn").disabled = false;
  if (error) {
    let why = error.message;
    try {
      const j = await error.context.json();
      if (j && j.error) why = j.error;
    } catch (_) { /* keep the plain message */ }
    say("pushMsg", "Not sent: " + why);
    return;
  }
  say("pushMsg", data && data.success ? "Sent." : "Not sent.", !!(data && data.success));
  await loadPushLog();
}

async function changePassword() {
  const a = $("newPw").value, b = $("newPw2").value;
  if (a.length < 12) {
    say("accountMsg", "Use at least 12 characters.");
    return;
  }
  if (a !== b) {
    say("accountMsg", "The two do not match.");
    return;
  }
  const { error } = await db.auth.updateUser({ password: a });
  if (error) {
    say("accountMsg", "Not changed: " + error.message);
    return;
  }
  $("newPw").value = "";
  $("newPw2").value = "";
  say("accountMsg", "Password changed.", true);
}

async function enter() {
  const { data: { user } } = await db.auth.getUser();
  if (!user) {
    $("signin").hidden = false;
    $("app").hidden = true;
    return;
  }
  const { data, error } = await db.from("admins").select("user_id").eq("user_id", user.id)
    .maybeSingle();
  if (error || !data) {
    await db.auth.signOut();
    say("signinMsg", "That account is not an admin.");
    $("signin").hidden = false;
    $("app").hidden = true;
    return;
  }
  $("signin").hidden = true;
  $("app").hidden = false;
  $("password").value = "";
  await Promise.all([loadEvents(), loadContent(), loadPushLog()]);
}

$("signinBtn").onclick = async () => {
  say("signinMsg", "");
  const { error } = await db.auth.signInWithPassword({
    email: $("email").value.trim(),
    password: $("password").value,
  });
  if (error) {
    say("signinMsg", "Could not sign in: " + error.message);
    return;
  }
  await enter();
};
$("signoutBtn").onclick = async () => {
  await db.auth.signOut();
  await enter();
};
$("newEventBtn").onclick = () => openEvent(null);
$("cancelEventBtn").onclick = () => {
  $("eventForm").hidden = true;
};
$("saveEventBtn").onclick = saveEvent;
$("deleteEventBtn").onclick = deleteEvent;
$("publishBtn").onclick = publishContent;
$("pushBtn").onclick = sendPush;
$("changePwBtn").onclick = changePassword;
for (const b of document.querySelectorAll("nav button[data-tab]")) {
  b.onclick = () => {
    for (const o of document.querySelectorAll("nav button[data-tab]")) {
      o.classList.toggle("on", o === b);
      $("tab-" + o.dataset.tab).hidden = o !== b;
    }
  };
}
enter();
