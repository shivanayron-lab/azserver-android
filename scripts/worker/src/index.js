// Fixed public address for a server on an Android phone (Cloudflare Worker, free plan).
// The phone's quick tunnel gets a new random address on every restart. The phone's
// supervisor tells this Worker the new address (POST /__set, header x-push-key), which is
// stored in KV; every other request is forwarded there.
//
// Bindings (wrangler.toml): KV namespace AZS. Secret: PUSH_KEY (wrangler secret put PUSH_KEY).
const TUNNEL = /^https:\/\/[a-z0-9-]+\.trycloudflare\.com$/;
const TTL = 20_000;
let cached = { base: "", at: 0 };

const clean = (b) => (b || "").replace(/\/+$/, "");

async function currentBase(env, force) {
  if (!force && cached.base && Date.now() - cached.at < TTL) return cached.base;
  try {
    const b = clean(await env.AZS.get("base", { cacheTtl: 30 }));
    if (TUNNEL.test(b)) cached = { base: b, at: Date.now() };
  } catch {}
  return cached.base;
}

// Tunnel gone: Cloudflare answers 530/52x/502, or the host no longer resolves.
const dead = (r) => !r || r.status === 530 || r.status === 502 || (r.status >= 520 && r.status <= 527);

async function setBase(req, env) {
  const key = req.headers.get("x-push-key") || "";
  if (!env.PUSH_KEY || key !== env.PUSH_KEY) return new Response("forbidden", { status: 403 });
  const f = await req.formData().catch(() => null);
  const base = clean(f && f.get("base"));
  if (!TUNNEL.test(base)) return new Response("bad base", { status: 400 });
  cached = { base, at: Date.now() };
  // Free KV = 1,000 writes per day for the WHOLE account (all Workers together). When
  // another Worker uses it up, put() throws; answer 503 (the phone retries every 15 s)
  // instead of crashing with Cloudflare error 1101.
  try { await env.AZS.put("base", base); } catch (e) {
    return new Response("kv: " + String((e && e.message) || e), { status: 503 });
  }
  return new Response("ok");
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/__set" && req.method === "POST") return setBase(req, env);

    // Buffer the body so the request can be retried after re-reading the address.
    const body = ["GET", "HEAD"].includes(req.method) ? null : await req.arrayBuffer();
    const send = async (base) => {
      const h = new Headers(req.headers);
      h.delete("host");
      try {
        return await fetch(base + url.pathname + url.search, { method: req.method, headers: h, body, redirect: "manual" });
      } catch { return null; }
    };

    let base = await currentBase(env, false);
    let res = base ? await send(base) : null;
    if (dead(res)) {
      const nb = await currentBase(env, true);
      if (nb && nb !== base) { base = nb; res = await send(nb); }
    }
    if (dead(res)) {
      return new Response("servidor fora do ar (o aparelho pode estar reiniciando: tente em 2 minutos)", { status: 503 });
    }

    // Keep redirects on the fixed address instead of the tunnel's.
    const loc = res.headers.get("location");
    if (loc && loc.startsWith(base)) {
      const h = new Headers(res.headers);
      h.set("location", url.origin + loc.slice(base.length));
      return new Response(res.body, { status: res.status, headers: h });
    }
    return res;
  },
};
