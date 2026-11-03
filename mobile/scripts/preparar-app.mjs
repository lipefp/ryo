// Monta a pasta www/ do app Android a partir de ../app, com o supabase-js local em vez do CDN.
// Rode dentro da pasta mobile/.
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";

const SUPABASE_CDN = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.2/dist/umd/supabase.js";

rmSync("www", { recursive: true, force: true });
mkdirSync("www");
for (const f of ["config.js", "icon.svg", "icon-maskable.svg", "manifest.webmanifest"]) cpSync("../app/" + f, "www/" + f);
cpSync("node_modules/@supabase/supabase-js/dist/umd/supabase.js", "www/supabase.js");
cpSync("node_modules/@capacitor/core/dist/capacitor.js", "www/capacitor.js");

let html = readFileSync("../app/index.html", "utf8");
const tag = new RegExp(`<script src="${SUPABASE_CDN.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"[^>]*></script>`);
if (!tag.test(html)) throw new Error("Não achei o script do Supabase no index.html. Atualize SUPABASE_CDN em mobile/scripts/preparar-app.mjs.");
html = html.replace(tag, '<script src="capacitor.js"></script>\n<script src="supabase.js"></script>');
writeFileSync("www/index.html", html);
console.log("www/ pronto");
