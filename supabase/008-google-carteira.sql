-- 008: notificações da Google Carteira (pagamento por aproximação)
-- Rode depois do 007.
-- - entende valor em formato inglês ("R$7.20"), que aparece com o celular em inglês
-- - compra na Carteira com cartão benefício (VR/VA, Flash, Caju...) entra como "beneficio": conta no gasto, não mexe na sobra
-- - a mesma compra avisada pela Carteira e pelo app do banco entra uma vez só

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
  v_wallet   boolean := coalesce(p_app, '') ~* '(wallet|carteira)';
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

  v_valor_tx := substring(v_full from 'R\$\s*([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})(?![0-9])');
  if v_valor_tx is not null then
    v_valor := replace(replace(v_valor_tx, '.', ''), ',', '.')::numeric;
  else
    -- celular em inglês (Google Carteira): "R$7.20", "R$1,234.56"
    v_valor_tx := substring(v_full from 'R\$\s*([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2})(?![0-9])');
    if v_valor_tx is not null then
      v_valor := replace(v_valor_tx, ',', '')::numeric;
    else
      v_valor_tx := substring(v_full from '([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})(?![0-9])');
      if v_valor_tx is not null then
        v_valor := replace(replace(v_valor_tx, '.', ''), ',', '.')::numeric;
      end if;
    end if;
  end if;

  -- o que não é movimentação: códigos, senhas, limite, fatura fechada, ofertas
  if v_valor is null or v_valor <= 0 then
    v_status := 'sem_valor';
  elsif v_low ~ '(c[oó]digo|senha|token|acesso|login|limite dispon|fatura (fechou|fechada|dispon|est[aá] dispon)|vence (hoje|amanh)|oferta|empr[eé]stimo|pr[eé]-aprovad|negad|recusad|n[aã]o autorizad|estorn|cancelad)' then
    v_status := 'ignorado';
  else
    if v_wallet then
      -- pagamento por aproximação na Google Carteira: sempre é compra
      v_tipo := 'gasto';
      v_forma := case
        when v_low ~ '(benef|flash|caju|alelo|pluxee|sodexo|ticket|\mvr\M|\mva\M|swile|refei[cç]|alimenta[cç])' then 'beneficio'
        when v_low ~ 'nubank|\mnu\M' then 'nubank'
        when v_low ~ 'santander' then 'santander'
        when v_low ~ 'd[eé]bito|debit' then 'conta'
        else coalesce(v_auto.cartao, 'conta')
      end;
    elsif v_low ~ '(pagamento (da|de) fatura|fatura (foi )?paga|pagamento do cart[aã]o)' then
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
      where char_length(m[1]) >= 3 and m[1] !~* '^(pix|pix enviado|pix recebido|cpf|cnpj|santander|nubank|ted|doc|google|google wallet|compra|compra aprovada|aprovad[ao]|realizad[ao]|cart[aã]o|d[eé]bito|cr[eé]dito|[0-9 ./-]+)$'
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

    -- a mesma compra avisada por dois apps (ex.: Google Carteira e o app do banco) em até 10 minutos
    if exists (select 1 from public.notificacoes n join public.lancamentos l on l.id = n.lancamento_id
               where n.user_id = v_auto.user_id and n.recebido_em > now() - interval '10 minutes'
                 and coalesce(n.app, '') <> coalesce(p_app, '') and l.tipo = v_tipo and l.valor = v_valor) then
      v_status := 'duplicado';
    else
      insert into public.lancamentos (user_id, tipo, valor, data, descricao, categoria, forma, cartao, import_ref)
      values (v_auto.user_id, v_tipo, v_valor, v_data, v_desc, v_cat, v_forma, v_cartao, v_ref)
      returning id into v_lanc;
      v_status := 'lancado';
    end if;
  end if;

  insert into public.notificacoes (user_id, app, titulo, texto, status, lancamento_id)
  values (v_auto.user_id, left(p_app, 120), left(p_titulo, 300), left(p_texto, 2000), v_status, v_lanc);

  return jsonb_build_object('ok', true, 'status', v_status, 'tipo', v_tipo, 'valor', v_valor, 'descricao', v_desc, 'categoria', v_cat);
end;
$$;
