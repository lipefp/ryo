-- Caixa: migração 005
-- Contas fixas "só lembrete": contas que você paga, mas com dinheiro de outra conta.
-- Aparecem em "Contas do mês" e no aviso de vencimento, mas não entram na sua sobra.
-- Rode este arquivo uma vez no SQL Editor, depois do 004.

alter table public.recorrentes add column if not exists externa boolean not null default false;
-- último mês marcado como pago (AAAA-MM)
alter table public.recorrentes add column if not exists ultimo_pago text check (ultimo_pago ~ '^[0-9]{4}-[0-9]{2}$');
