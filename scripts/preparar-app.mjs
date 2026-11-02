// Monta a pasta www/ que vai dentro do app Android.
// Copia o site e troca os scripts de CDN por cópias locais,
// pra o app abrir mesmo com internet ruim.
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";

const SUPABASE_CDN = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.2/dist/umd/supabase.js";

rmSync("www", { recursive: true, force: true });
mkdirSync("www");
for (const f of ["config.js", "icon.svg", "manifest.webmanifest"]) cpSync(f, "www/" + f);
cpSync("node_modules/@supabase/supabase-js/dist/umd/supabase.js", "www/supabase.js");
cpSync("node_modules/@capacitor/core/dist/capacitor.js", "www/capacitor.js");

let html = readFileSync("index.html", "utf8");
if (!html.includes(SUPABASE_CDN)) throw new Error("Não achei o script do Supabase no index.html. Atualize SUPABASE_CDN em scripts/preparar-app.mjs.");
html = html.replace(`<script src="${SUPABASE_CDN}"></script>`, '<script src="capacitor.js"></script>\n<script src="supabase.js"></script>');
writeFileSync("www/index.html", html);
console.log("www/ pronto");
