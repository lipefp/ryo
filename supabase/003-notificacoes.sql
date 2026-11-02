-- Caixa: migração 003
-- Lançamento automático a partir das notificações do banco no celular.
-- Um app de automação (ex.: MacroDroid) chama a função registrar_notificacao
-- com o texto da notificação e um token secreto. A função guarda a notificação,
-- tenta entender valor, tipo e estabelecimento e cria o lançamento.
-- Rode este arquivo inteiro uma vez no SQL Editor, depois do 002.

-- ---------------------------------------------------------------
-- Tokens de automação (um por usuário). Só o hash do token fica salvo.
-- ---------------------------------------------------------------
create table if not exists public.automacao (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  token_hash  text not null unique,
  cartao      text check (char_length(cartao) <= 40),       -- id do cartão usado nas compras (o mesmo do config.js)
  criado_em   timestamptz not null default now()
);
alter table public.automacao enable row level security;
-- Sem políticas: ninguém lê nem grava esta tabela pela API. Só o SQL Editor e a função abaixo.

-- ---------------------------------------------------------------
-- Notificações recebidas (todas, mesmo as não entendidas)
-- ---------------------------------------------------------------
create table if not exists public.notificacoes (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  app            text check (char_length(app) <= 120),
  titulo         text check (char_length(titulo) <= 300),
  texto          text check (char_length(texto) <= 2000),
  status         text not null check (status in ('lancado', 'ignorado', 'duplicado', 'sem_valor')),
  lancamento_id  uuid references public.lancamentos (id) on delete set null,
  recebido_em    timestamptz not null default now()
);
create index if not exists notificacoes_user_idx on public.notificacoes (user_id, recebido_em desc);
alter table public.notificacoes enable row level security;
drop policy if exists "notificacoes: dono le" on public.notificacoes;
drop policy if exists "notificacoes: dono apaga" on public.notificacoes;
create policy "notificacoes: dono le"    on public.notificacoes for select to authenticated using ((select auth.uid()) = user_id);
create policy "notificacoes: dono apaga" on public.notificacoes for delete to authenticated using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------
-- Categoria a partir do texto
-- ---------------------------------------------------------------
create or replace function public.caixa_categoria(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p ~* '(ifood|hortifruti|hortfrut|supermerc|obah|assa[ií]|guanabara|padaria|a[çc]ougue|zamp|burger|mc ?donald|bob.?s|subway|restaurante|lanchonete|\mmercado\M)' and p !~* 'mercado ?(livre|pago)' then 'Alimentação'
    when p ~* '(uber|\m99\M|rio ?card|\mjae\M|\mmetr[oô]\M|\mbrt\M|posto|shell|ipiranga|petrobras)' then 'Transporte'
    when p ~* '(netflix|spotify|youtube|prime video|disney|\mhbo\M|apple\.com|google ?play|steam)' then 'Assinaturas'
    when p ~* '(bytedance|tiktok|americanas|shopee|mercado ?livre|mercado ?pago|marketplace|pagar ?me|pagbrasil|amazon|magalu|aliexpress|shein)' then 'Compras'
    when p ~* '(cesgranrio|faculdade|universidade|udemy|alura)' then 'Estudos'
    when p ~* '(farm[aá]cia|drogaria|raia|pacheco|drogasil|venancio)' then 'Saúde'
    when p ~* '(\menel\M|\mlight\M|cedae|[aá]guas|\mclaro\M|\mvivo\M|\mtim\M|naturgy|condom[ií]nio|aluguel)' then 'Contas da casa'
    else 'Outros'
  end;
$$;

-- ---------------------------------------------------------------
-- Função chamada pelo celular
-- ---------------------------------------------------------------
create or replace function public.registrar_notificacao(p_token text, p_app text default null, p_titulo text default null, p_texto text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auto     public.automacao%rowtype;
  v_full     text;
  v_low      text;
  v_valor_tx text;
  v_valor    numeric(12, 2);
  v_tipo     text;
  v_forma    text;
  v_cartao   text;
  v_desc     text;
  v_clean    text;
  v_cartao_app text;
  v_cat      text;
  v_data     date := (now() at time zone 'America/Sao_Paulo')::date;
  v_ref      text;
  v_lanc     uuid;
  v_status   text;
begin
  if p_token is null or char_length(p_token) < 24 then
    raise exception 'token inválido' using errcode = '28000';
  end if;
  select * into v_auto from public.automacao where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if not found then
    raise exception 'token inválido' using errcode = '28000';
  end if;

  -- Cartão de acordo com o app que mandou a notificação (padrão: o cartão do token)
  v_cartao_app := case when coalesce(p_app, '') ~* '(nubank|^nu$)' then 'nubank' else v_auto.cartao end;
  v_full := left(trim(coalesce(p_titulo, '') || ' ' || coalesce(p_texto, '')), 2000);
  v_low  := lower(v_full);
  v_ref  := 'notif:' || md5(v_full || to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM-DD HH24:MI'));

  -- mesma notificação repetida no mesmo minuto
  if exists (select 1 from public.lancamentos where user_id = v_auto.user_id and import_ref = v_ref) then
    insert into public.notificacoes (user_id, app, titulo, texto, status) values (v_auto.user_id, left(p_app, 120), left(p_titulo, 300), left(p_texto, 2000), 'duplicado');
    return jsonb_build_object('ok', true, 'status', 'duplicado');
  end if;

  v_valor_tx := substring(v_full from 'R\$\s*([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})');
  if v_valor_tx is null then
    v_valor_tx := substring(v_full from '([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})');
  end if;
  if v_valor_tx is not null then
    v_valor := replace(replace(v_valor_tx, '.', ''), ',', '.')::numeric;
  end if;

  -- o que não é movimentação: códigos, senhas, limite, fatura fechada, ofertas
  if v_valor is null or v_valor <= 0 then
    v_status := 'sem_valor';
  elsif v_low ~ '(c[oó]digo|senha|token|acesso|login|limite dispon|fatura (fechou|fechada|dispon|est[aá] dispon)|vence (hoje|amanh)|oferta|empr[eé]stimo|pr[eé]-aprovad|negad|recusad|n[aã]o autorizad|estorn|cancelad)' then
    v_status := 'ignorado';
  else
    if v_low ~ '(pagamento (da|de) fatura|fatura (foi )?paga|pagamento do cart[aã]o)' then
      v_tipo := 'fatura'; v_cartao := v_cartao_app;
    elsif v_low ~ '(recebe|recebid|caiu|cr[eé]dito de sal|dep[oó]sito|voc[eê] recebeu|transfer[eê]ncia recebida)' and v_low !~ '(compra|enviad)' then
      v_tipo := 'entrada';
    elsif v_low ~ '(compra|cart[aã]o|d[eé]bito autom)' and v_low !~ '(pix enviado|transfer[eê]ncia enviada)' then
      v_tipo := 'gasto';
      v_forma := case when v_low ~ 'd[eé]bito' then 'conta' else coalesce(v_cartao_app, 'conta') end;
    else
      v_tipo := 'gasto'; v_forma := 'conta';
    end if;

    -- estabelecimento ou pessoa: tira valores, datas e final do cartão,
    -- e pega o trecho mais longo em MAIÚSCULAS (como os bancos escrevem o estabelecimento)
    v_clean := regexp_replace(v_full, 'R\$\s*[0-9.,]+', ' ', 'g');
    v_clean := regexp_replace(v_clean, '[0-9]{2}/[0-9]{2}(/[0-9]{2,4})?|[0-9]{1,2}(:|h)[0-9]{2}|final\s*[0-9]{4}', ' ', 'gi');
    if v_low ~ 'sal[aá]rio' then
      v_desc := 'Salário';
    else
      select m[1] into v_desc
      from regexp_matches(v_clean, '([A-ZÀ-Ý0-9][A-ZÀ-Ý0-9*&./ -]*[A-ZÀ-Ý0-9*])', 'g') as m
      where char_length(m[1]) >= 3 and m[1] !~* '^(pix|pix enviado|pix recebido|cpf|cnpj|santander|nubank|ted|doc|compra|compra aprovada|aprovad[ao]|realizad[ao]|cart[aã]o|d[eé]bito|cr[eé]dito|[0-9 ./-]+)$'
      order by char_length(m[1]) desc
      limit 1;
      v_desc := coalesce(
        v_desc,
        substring(v_clean from '(?i)\m(?:estabelecimento|em|no|na)\s+([A-Za-zÀ-ú][^,.\n]{2,60}?)\s*(?:[,.\n]|$)'),
        substring(v_clean from '(?i)\mpara\s+([A-Za-zÀ-ú][^,.\n]{2,60}?)\s*(?:[,.\n]|$)'),
        substring(v_clean from '(?i)\mde\s+([A-Za-zÀ-ú][^,.\n]{2,60}?)\s*(?:[,.\n]|$)'),
        nullif(trim(p_titulo), '')
      );
    end if;
    v_desc := regexp_replace(v_desc, '\s+(aprovad[ao]|realizad[ao]|efetuad[ao]|enviad[ao]|recebid[ao]|com sucesso)\M.*$', '', 'i');
    v_desc := regexp_replace(v_desc, '(\s+-\s*\S{0,2}|\s+\S)$', '');
    -- sem nome de estabelecimento ou pessoa na notificação (ex.: "PIX enviado em ... no valor de R$ 1,00")
    if v_desc is null or char_length(trim(v_desc)) < 3 or v_desc ~* '(valor|^\s*(as|às|em|no|na|de|do|da)\s*$|^\s*(as|às)\s)' then
      v_desc := case
        when v_low ~ 'pix' and v_tipo = 'entrada' then 'Pix recebido'
        when v_low ~ 'pix' then 'Pix enviado'
        when v_low ~ 'compra' then 'Compra no cartão'
        when v_low ~ 'transfer' then 'Transferência'
        else coalesce(nullif(trim(p_titulo), ''), 'Notificação do banco')
      end;
    end if;
    v_desc := left(trim(regexp_replace(coalesce(v_desc, 'Notificação do banco'), '\s+', ' ', 'g')), 190);
    if v_tipo = 'entrada' and v_desc !~* '^pix recebido' then v_desc := 'Recebido: ' || v_desc;
    elsif v_tipo = 'fatura' then v_desc := 'Pagamento de fatura';
    end if;
    v_cat := case when v_tipo = 'gasto' then public.caixa_categoria(v_full) else null end;

    insert into public.lancamentos (user_id, tipo, valor, data, descricao, categoria, forma, cartao, import_ref)
    values (v_auto.user_id, v_tipo, v_valor, v_data, v_desc, v_cat, v_forma, v_cartao, v_ref)
    returning id into v_lanc;
    v_status := 'lancado';
  end if;

  insert into public.notificacoes (user_id, app, titulo, texto, status, lancamento_id)
  values (v_auto.user_id, left(p_app, 120), left(p_titulo, 300), left(p_texto, 2000), v_status, v_lanc);

  return jsonb_build_object('ok', true, 'status', v_status, 'tipo', v_tipo, 'valor', v_valor, 'descricao', v_desc, 'categoria', v_cat);
end;
$$;

revoke all on function public.registrar_notificacao(text, text, text, text) from public;
grant execute on function public.registrar_notificacao(text, text, text, text) to anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'notificacoes') then
    alter publication supabase_realtime add table public.notificacoes;
  end if;
end $$;
