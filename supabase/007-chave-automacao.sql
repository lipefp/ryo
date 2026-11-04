-- 007: o próprio app cria a chave da automação (sem SQL na mão)
-- Rode depois do 006.
--
-- Cada usuário tem uma chave. Gerar outra invalida a anterior
-- (ex.: a do MacroDroid para de funcionar assim que o app Android é ativado).

create or replace function public.gerar_token_automacao(p_cartao text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_token text;
begin
  if v_uid is null then
    raise exception 'faça login' using errcode = '28000';
  end if;
  if p_cartao is not null and char_length(p_cartao) > 40 then
    raise exception 'cartão inválido' using errcode = '22023';
  end if;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.automacao (user_id, token_hash, cartao)
  values (v_uid, encode(extensions.digest(v_token, 'sha256'), 'hex'), p_cartao)
  on conflict (user_id) do update
    set token_hash = excluded.token_hash,
        cartao     = coalesce(excluded.cartao, public.automacao.cartao),
        criado_em  = now();

  -- a chave só aparece aqui, uma vez; o banco guarda só o hash
  return v_token;
end;
$$;

revoke all on function public.gerar_token_automacao(text) from public, anon;
grant execute on function public.gerar_token_automacao(text) to authenticated;

-- o app mostra se a automação está ligada (sem expor o hash)
create or replace function public.automacao_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select jsonb_build_object('ativa', true, 'cartao', a.cartao, 'desde', a.criado_em)
     from public.automacao a where a.user_id = auth.uid()),
    jsonb_build_object('ativa', false)
  );
$$;

revoke all on function public.automacao_status() from public, anon;
grant execute on function public.automacao_status() to authenticated;
