<img src="brand/ryo-symbol-light.svg" alt="" width="56">

# Ryo

**Personal Finance.** Controle financeiro pessoal que eu fiz pra usar no celular. Mostra quanto sobrou na conta no mês, pra onde foi o dinheiro e quanto falta pras metas.

<p>
  <img src="docs/tela-principal.png" alt="Tela principal" width="300">
  <img src="docs/tela-extrato.png" alt="Extrato do mês" width="300">
</p>

## O nome

Ryo (両) foi a moeda de ouro do Japão no período Edo. O ideograma também quer dizer "os dois lados": o app mostra o que entra e o que sai, e o que sobra no meio.

## Funcionalidades

- Lançamento de entradas, gastos, valores guardados e pagamento de fatura
- Compras no cartão contam como gasto no dia da compra, mas só saem da conta quando a fatura é paga
- Parcelamentos: as parcelas seguintes aparecem sozinhas nos próximos meses
- Metas com valor, prazo e quanto guardar por mês
- Extrato do mês separado por categoria
- Importação de extrato em PDF (testado com Santander), OFX e CSV
- Contas do mês com vencimento, inclusive em dia útil, e aviso quando algo vence em até 3 dias
- Contas só de lembrete, pra contas que eu pago mas com dinheiro de outra conta
- Teto de gastos semanal
- Lançamento automático pelas notificações do banco (via MacroDroid)
- Backup em JSON

## Stack

- HTML, CSS e JavaScript puro, sem build
- Supabase (PostgreSQL + Auth) com Row Level Security
- GitHub Pages
- App Android com Capacitor, gerado pelo GitHub Actions

## Segurança

Cada tabela tem RLS: o usuário logado só acessa as próprias linhas. A chave que fica no `config.js` é a publishable, que é pública e não acessa nada sem login. Chave secret ou service_role não entra no repositório.

Pra uso pessoal, vale desativar novos cadastros no Supabase (Authentication > Sign In / Providers > Allow new users to sign up).

## Como rodar

1. Crie um projeto no Supabase e rode os arquivos da pasta `supabase/` no SQL Editor, em ordem: `schema.sql`, depois `002` a `005`.
2. Crie o usuário em Authentication > Users > Add user.
3. Coloque a Project URL e a chave publishable no `config.js`. No mesmo arquivo dá pra ajustar cartões, categorias e atalhos.
4. Publique no GitHub Pages (Settings > Pages > branch `main`) ou rode local:

```bash
python3 -m http.server 8000
```

## App Android

O workflow `.github/workflows/apk.yml` gera o APK a cada mudança no app e publica em Releases. Pra uma versão instalar por cima da outra, a chave de assinatura fica no secret `ANDROID_DEBUG_KEYSTORE` (keystore em base64).

Pra gerar na mão: `npm install`, `npm run app:preparar`, `npx cap add android` e abrir a pasta `android/` no Android Studio.

## Ideias

- [ ] Importar fatura do cartão em PDF
- [ ] Backend próprio em Django REST
- [ ] Gráfico da sobra mês a mês

## Licença

MIT
