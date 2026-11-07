-- DEADLORD OS 16.0 · Supabase schema
-- Ejecutar una sola vez en Supabase > SQL Editor.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 32),
  normalized_key text not null unique,
  status text not null default 'none' check (status in ('yes','no','maybe','none')),
  created_at timestamptz not null default now()
);

-- Los tokens privados nunca se exponen en la tabla pública.
create table if not exists public.participant_secrets (
  participant_id uuid primary key references public.participants(id) on delete cascade,
  token_hash text not null
);
alter table public.participant_secrets enable row level security;

create table if not exists public.event_config (
  id integer primary key check (id = 1),
  event_at timestamptz,
  message text not null default ''
);
insert into public.event_config(id, event_at, message)
values (1, null, '') on conflict (id) do nothing;

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  text text not null check (char_length(text) between 1 and 2000),
  created_at timestamptz not null default now()
);

alter table public.participants enable row level security;
alter table public.event_config enable row level security;
alter table public.announcements enable row level security;

-- Cualquier visitante puede ver la lista pública y los anuncios/configuración.
drop policy if exists "Public can read participants" on public.participants;
create policy "Public can read participants" on public.participants for select to anon, authenticated using (true);
drop policy if exists "Public can read event config" on public.event_config;
create policy "Public can read event config" on public.event_config for select to anon, authenticated using (true);
drop policy if exists "Public can read announcements" on public.announcements;
create policy "Public can read announcements" on public.announcements for select to anon, authenticated using (true);

-- Solo cuentas con app_metadata.role = admin pueden gestionar datos desde el panel.
drop policy if exists "Admins manage participants" on public.participants;
create policy "Admins manage participants" on public.participants for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists "Admins manage event config" on public.event_config;
create policy "Admins manage event config" on public.event_config for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists "Admins manage announcements" on public.announcements;
create policy "Admins manage announcements" on public.announcements for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Registro atómico: el índice UNIQUE evita duplicados incluso con dos registros simultáneos.
create or replace function public.register_wbc(p_name text, p_token text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id uuid;
  v_name text;
  v_key text;
begin
  v_name := regexp_replace(trim(p_name), '\s+', ' ', 'g');
  if char_length(v_name) < 2 or char_length(v_name) > 32 then
    raise exception 'Nombre inválido';
  end if;
  if p_token is null or char_length(p_token) < 32 then
    raise exception 'Token inválido';
  end if;
  v_key := lower(v_name);
  insert into public.participants(name, normalized_key, status)
  values (v_name, v_key, 'none') returning id into v_id;
  insert into public.participant_secrets(participant_id, token_hash)
  values (v_id, encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex'));
  return v_id;
exception when unique_violation then
  raise exception 'Ese nombre de WBC ya está registrado';
end;
$$;

create or replace function public.get_my_participant(p_id uuid, p_token text)
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  select jsonb_build_object('id', p.id, 'name', p.name, 'status', p.status)
  from public.participants p
  join public.participant_secrets s on s.participant_id = p.id
  where p.id = p_id
    and s.token_hash = encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex')
  limit 1;
$$;

create or replace function public.update_attendance(p_id uuid, p_token text, p_status text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_count integer;
begin
  if p_status not in ('yes','no','maybe') then raise exception 'Estado inválido'; end if;
  update public.participants p set status = p_status
  where p.id = p_id and exists (
    select 1 from public.participant_secrets s
    where s.participant_id = p.id
      and s.token_hash = encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex')
  );
  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke all on function public.register_wbc(text,text) from public;
revoke all on function public.get_my_participant(uuid,text) from public;
revoke all on function public.update_attendance(uuid,text,text) from public;
grant execute on function public.register_wbc(text,text) to anon, authenticated;
grant execute on function public.get_my_participant(uuid,text) to anon, authenticated;
grant execute on function public.update_attendance(uuid,text,text) to anon, authenticated;
grant select on public.participants, public.event_config, public.announcements to anon, authenticated;
grant insert, update, delete on public.participants, public.event_config, public.announcements to authenticated;

-- Activar cambios en tiempo real para las tres tablas públicas.
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='participants') then
    alter publication supabase_realtime add table public.participants;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='event_config') then
    alter publication supabase_realtime add table public.event_config;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='announcements') then
    alter publication supabase_realtime add table public.announcements;
  end if;
end $$;
