# Ryo · Personal Finance — identidade (v1, shu)

Pronuncia: "Rio". Nome vem de 両 (ryo): moeda de ouro do Japao Edo; "os dois lados". Assinatura: **Ryo** com "PERSONAL FINANCE" embaixo (Public Sans 600, caixa alta, tracking .24em).

## Simbolo "Portal"
Barra no topo + dois pilares (entrou / saiu) + pilar central curto = o que sobrou.
SVG viewBox 100x100, tracos arredondados:
- pilares e barra: `M12 16 H88 M24 16 V86 M76 16 V86`, stroke-width 11
- pilar central (cor de destaque): `M50 38 V76`, stroke-width 13
Versoes: claro (sumi + shu), escuro (nevoa + shu claro), sobre shu (marfim + sumi), mono preta/branca. Arquivos: `ryo-symbol-*.svg`.

## Icone e favicon
Fundo shu cheio, simbolo marfim + pilar central sumi, ocupando 64% do lado. Android adaptive: `ryo-app-icon-adaptive-foreground.svg` (simbolo dentro da safe zone de 66/108 dp) + `...-background.svg` (shu solido). Tamanho minimo 16 px. `favicon.svg`.

## Cor
Tokens em `ryo-tokens.css` (claro + escuro automatico). Valores em oklch sao a fonte; hex sao aproximacoes.
Regra semantica: **shu = marca, acao e sobrou**; **ink = entrou e texto**; **cinza = saiu**; **ambar = alertas** (vermelhao nunca vira "erro").
Texto pequeno sobre shu: use --on-shu (contraste). Branco sobre shu so em titulos grandes.

## Tipografia
- Titulos e marca: Archivo 800, tracking -0.03 a -0.04em (ex.: "Novembro" 38px)
- Texto/UI: Public Sans 400/500/600
- Valores: IBM Plex Mono 500, tracking -0.04 a -0.06em; centavos em --mut

## Componentes
- Cartoes: raio 22-24px, fundo --card, sem sombra
- Botao primario: pill, altura min 44px, fundo --shu, texto --on-shu, 600
- Barra do mes: segmento "entrou" em --ink (62%) + "sobrou" em --shu (38%), 10px, cantos 6px nas pontas
- Meta: anel 56px, traco 7px, progresso em --shu, trilho --line
- Alvos de toque >= 44px

## Tom de voz
Direto e calmo. Numero primeiro, frase curta, diz sempre o que mexe ou nao na sobra. Ex.: "Sobraram R$ 1.284.", "Vence em 2 dias.", "Lembrete: nao entra na sobra." Tagline: "Entrou. Saiu. Sobrou." / "Os dois lados do dinheiro."
