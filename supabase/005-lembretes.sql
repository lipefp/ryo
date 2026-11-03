-- 005: contas só de lembrete (pagas com dinheiro de outra conta, não entram na sobra)

alter table public.recorrentes add column if not exists externa boolean not null default false;
alter table public.recorrentes add column if not exists ultimo_pago text check (ultimo_pago ~ '^[0-9]{4}-[0-9]{2}$');
