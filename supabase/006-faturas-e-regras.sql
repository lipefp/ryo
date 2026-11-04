-- 006: faturas importadas do cartão e categorias que o app aprende
-- Rode depois do 005.

-- Fatura de cada cartão por vencimento (valor que o banco cobra)
create table if not exists public.faturas (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  cartao      text not null check (char_length(cartao) between 1 and 40),
  vencimento  date not null,
  fechamento  date,
  total       numeric(12, 2) not null check (total >= 0),
  criado_em   timestamptz not null default now(),
  unique (user_id, cartao, vencimento)
);

-- Regras de categoria: se a descrição tem a chave, usa a categoria
create table if not exists public.regras_categoria (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  chave      text not null check (char_length(chave) between 2 and 60),
  categoria  text not null check (char_length(categoria) between 1 and 60),
  criado_em  timestamptz not null default now(),
  unique (user_id, chave)
);

alter table public.faturas enable row level security;
alter table public.regras_categoria enable row level security;

drop policy if exists "faturas: dono" on public.faturas;
create policy "faturas: dono" on public.faturas for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "regras: dono" on public.regras_categoria;
create policy "regras: dono" on public.regras_categoria for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Lançamentos vindos das notificações também usam as regras do usuário
create or replace function public.aplica_regra_categoria()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_desc text;
  v_cat  text;
begin
  if new.tipo <> 'gasto' or coalesce(new.import_ref, '') not like 'notif:%' then
    return new;
  end if;
  v_desc := ' ' || regexp_replace(upper(coalesce(new.descricao, '')), '[^A-Z0-9À-Ý]+', ' ', 'g') || ' ';
  select r.categoria into v_cat
  from public.regras_categoria r
  where r.user_id = new.user_id and position(' ' || r.chave || ' ' in v_desc) > 0
  order by char_length(r.chave) desc
  limit 1;
  if v_cat is not null then
    new.categoria := v_cat;
  end if;
  return new;
end;
$$;

drop trigger if exists lancamentos_regra_categoria on public.lancamentos;
create trigger lancamentos_regra_categoria
  before insert on public.lancamentos
  for each row execute function public.aplica_regra_categoria();
