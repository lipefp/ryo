-- Caixa: migração 004
-- Contas fixas que vencem em dia útil (ex.: "5º dia útil do mês").
-- Com dia_util = true, a coluna "dia" passa a contar só segunda a sexta, sem feriados nacionais.
-- Rode este arquivo uma vez no SQL Editor, depois do 002.

alter table public.recorrentes add column if not exists dia_util boolean not null default false;
