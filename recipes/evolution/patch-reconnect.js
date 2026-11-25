// AZ patch (2026-11-25): reconnect with backoff in Evolution's dist/main.js.
// Evolution 2.3.7 reconnects to WhatsApp IMMEDIATELY on every "close" (no wait). With the
// home internet down each attempt fails at once, so it loops ~12 times per second per
// instance; every attempt leaks memory and Node dies with "JavaScript heap out of memory"
// (real case: 6 crashes in one night after the home internet dropped). Now: one reconnect at a time
// per instance, waiting 2 s, 4 s, 8 s ... up to 60 s; the wait resets when the connection opens.
// Usage: node patch-reconnect.js /opt/evo/app/dist/main.js   (idempotent; exit 0 always)
// Runs before every start (20-evolution.conf), because an update brings the original back.
// Tested with Evolution 2.3.7; on another version it only logs "não encaixou" and changes nothing.
const fs = require("fs");
const f = process.argv[2] || "/opt/evo/app/dist/main.js";
const log = (m) => console.log(new Date().toISOString() + " " + m);
let s;
try { s = fs.readFileSync(f, "utf8"); } catch (e) { log("AVISO: patch reconexão: não li " + f); process.exit(0); }
if (s.includes("__azRc")) process.exit(0);
const head = "async connectionUpdate({qr:e,connection:t,lastDisconnect:o}){";
const call = "?await this.connectToWhatsapp(this.phoneNumber):";
const i = s.indexOf(head), j = i < 0 ? -1 : s.indexOf(call, i);
if (i < 0 || j < 0 || j - i > 6000 || s.indexOf(call, j + 1) !== -1 && s.indexOf(call, j + 1) - i < 6000) {
  log("AVISO: patch reconexão não encaixou (versão nova da Evolution?)");
  process.exit(0);
}
const delay = "(0,R.delay)";
if (!s.slice(i, j).includes(delay)) { log("AVISO: patch reconexão: delay não encontrado"); process.exit(0); }
const retry =
  "?await(async()=>{if(this.__azRcBusy)return;this.__azRcBusy=!0;try{" +
  "this.__azRc=(this.__azRc||0)+1;" +
  "let w=Math.min(6e4,2e3*2**Math.min(this.__azRc-1,5));" +
  "this.logger.warn(`AZ: conexão caiu (código ${i}); nova tentativa ${this.__azRc} em ${w/1e3} s`);" +
  "await " + delay + "(w);await this.connectToWhatsapp(this.phoneNumber)" +
  "}finally{this.__azRcBusy=!1}})():";
s = s.slice(0, j) + retry + s.slice(j + call.length);
s = s.replace(head, head + 't==="open"&&(this.__azRc=0);');
fs.writeFileSync(f + ".az-tmp", s);
fs.renameSync(f + ".az-tmp", f);
log("patch reconexão com espera aplicado em " + f);
