/* Shared: "Delete my account" (Google Play requirement) + footer link on every app page. */
(function () {
  var URL_ = "https://ubkfrpkapqnlaiscrxim.supabase.co";
  var KEY_ = "sb_publishable_5EokG_AyxU4BvcMiq1zyqg_B-NIMoeE";

  function client() {
    if (!window.supabase || !window.supabase.createClient) return null;
    if (!window.__eedbAccountClient)
      window.__eedbAccountClient = window.supabase.createClient(URL_, KEY_);
    return window.__eedbAccountClient;
  }

  window.eedbDeleteAccount = async function () {
    var db = client();
    if (!db) { alert("App is still loading. Try again in a moment."); return; }
    if (!confirm("Delete your account permanently?\n\nYour profile, listings, applications and messages will be removed. This cannot be undone.")) return;
    try {
      var got = await db.auth.getUser();
      var user = got.data && got.data.user;
      if (!user) { alert("Please log in first."); return; }
      var buckets = ["property-images", "marketplace-images", "car-images", "job-cvs"];
      for (var i = 0; i < buckets.length; i++) {
        var l = await db.storage.from(buckets[i]).list(user.id, { limit: 1000 });
        if (l.data && l.data.length)
          await db.storage.from(buckets[i]).remove(l.data.map(function (f) { return user.id + "/" + f.name; }));
      }
      var r = await db.rpc("eedb_delete_my_account");
      if (r.error) throw new Error(r.error.message);
      await db.auth.signOut({ scope: "local" });
      try { Object.keys(localStorage).forEach(function (k) { if (k.indexOf("sb-") === 0) localStorage.removeItem(k); }); } catch (e) {}
      alert("Your account has been deleted.");
      location.replace("index.html");
    } catch (e) {
      alert("Could not delete account: " + (e.message || e));
    }
  };

  function addFooter() {
    var c = client();
    if (!c) return;
    c.auth.getSession().then(function (s) {
      if (!s || !s.data || !s.data.session) return;
      if (document.getElementById("eedbAccountFooter")) return;
      var box = document.createElement("div");
      box.id = "eedbAccountFooter";
      box.style.cssText = "text-align:center;padding:14px;font:13px Arial,sans-serif;background:#fff;border-top:1px solid #e5e7eb";
      box.innerHTML = '<a href="privacy.html" style="color:#0d47a1;margin:0 10px">Privacy</a>' +
        '<a href="terms.html" style="color:#0d47a1;margin:0 10px">Terms</a>' +
        '<button type="button" onclick="eedbDeleteAccount()" style="background:#b42318;color:#fff;border:0;border-radius:8px;padding:6px 12px;margin:0 10px;cursor:pointer">Delete account</button>';
      document.body.appendChild(box);
    });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function () { setTimeout(addFooter, 800); });
  else setTimeout(addFooter, 800);
})();
