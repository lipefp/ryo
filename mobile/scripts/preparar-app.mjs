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
html = html.replace(tag, '<script src="supabase.js"></script>');
if (!html.includes('src="capacitor.js"')) html = html.replace('<script src="supabase.js">', '<script src="capacitor.js"></script>\n<script src="supabase.js">');
writeFileSync("www/index.html", html);
// o app abre o site (lipefp.github.io/ryo) e se atualiza sozinho; esta página aparece só sem internet
writeFileSync("www/offline.html", `<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ryo</title>
<style>body{margin:0;min-height:100vh;display:grid;place-content:center;gap:12px;padding:24px;text-align:center;font-family:system-ui,sans-serif;background:#F6F3EE;color:#1B1A1F}
@media (prefers-color-scheme:dark){body{background:#111014;color:#F6F3EE}}
p{margin:0;color:#6C6A70}button{font:inherit;font-weight:600;border:0;border-radius:99px;padding:12px 22px;background:#E4501F;color:#1A0A04}</style></head>
<body><h1 style="margin:0">Sem internet</h1><p>O Ryo precisa de internet pra abrir.</p>
<button onclick="location.href='https://lipefp.github.io/ryo/'">Tentar de novo</button></body></html>
`);
console.log("www/ pronto");
