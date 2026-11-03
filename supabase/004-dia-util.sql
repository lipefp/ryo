-- 004: vencimento em dia útil (ex.: 5º dia útil). Com dia_util = true, "dia" conta só dias úteis.

alter table public.recorrentes add column if not exists dia_util boolean not null default false;
