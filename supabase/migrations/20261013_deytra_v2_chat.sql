-- Deytra v2: chat interno, WhatsApp opcional y contadores de avisos.
-- Reglas: solo quienes participan de una conexión aceptada pueden escribirse;
-- el WhatsApp de cada persona solo se ve cuando la conexión está aceptada.

alter table public.entities add column if not exists whatsapp text;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.connections(id) on delete cascade,
  sender_entity_id uuid not null references public.entities(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists messages_connection_idx on public.messages (connection_id, created_at);
alter table public.messages enable row level security;

drop policy if exists messages_participant_read on public.messages;
create policy messages_participant_read on public.messages
  for select to authenticated
  using (exists (
    select 1 from public.connections c
    where c.id = messages.connection_id
      and ((select private.owns_entity(c.requester_entity_id))
        or (select private.owns_entity(c.recipient_entity_id)))
  ));

drop policy if exists messages_participant_insert on public.messages;
create policy messages_participant_insert on public.messages
  for insert to authenticated
  with check (
    read_at is null
    and (select private.owns_entity(sender_entity_id))
    and exists (
      select 1 from public.connections c
      where c.id = messages.connection_id
        and c.status = 'accepted'
        and messages.sender_entity_id in (c.requester_entity_id, c.recipient_entity_id)
        and not exists (
          select 1 from public.blocks b
          where (b.blocker_entity_id = c.requester_entity_id and b.blocked_entity_id = c.recipient_entity_id)
             or (b.blocker_entity_id = c.recipient_entity_id and b.blocked_entity_id = c.requester_entity_id)
        )
    )
  );

revoke update, delete on public.messages from anon, authenticated;
grant select, insert on public.messages to authenticated;

-- Marca como leídos los mensajes que me mandaron en una conversación.
create or replace function public.mark_messages_read(p_connection_id uuid)
returns void
language sql
security definer
set search_path to ''
as $$
  update public.messages m
     set read_at = now()
    from public.connections c
   where m.connection_id = p_connection_id
     and c.id = m.connection_id
     and m.read_at is null
     and (select auth.uid()) in (
       select e.owner_profile_id from public.entities e
        where e.id in (c.requester_entity_id, c.recipient_entity_id))
     and m.sender_entity_id not in (
       select e.id from public.entities e where e.owner_profile_id = (select auth.uid()));
$$;

-- Contadores para los avisos de la pantalla de inicio.
create or replace function public.my_badges()
returns table (pending_requests int, unread_messages int)
language sql
stable
security definer
set search_path to ''
as $$
  with mine as (
    select e.id from public.entities e where e.owner_profile_id = (select auth.uid())
  )
  select
    (select count(*)::int from public.connections c
      where c.status = 'pending' and c.recipient_entity_id in (select id from mine)),
    (select count(*)::int from public.messages m
       join public.connections c on c.id = m.connection_id
      where m.read_at is null
        and m.sender_entity_id not in (select id from mine)
        and (c.requester_entity_id in (select id from mine)
          or c.recipient_entity_id in (select id from mine)));
$$;

-- Lista de conexiones con último mensaje, no leídos y WhatsApp (solo si está aceptada).
drop function if exists public.list_my_connections();
create function public.list_my_connections()
returns table (
  id uuid, status text, intro_message text, created_at timestamptz, responded_at timestamptz,
  i_am_requester boolean, my_entity_id uuid, other_entity_id uuid, other_name text,
  other_avatar_url text, other_city text, other_instagram_url text, other_whatsapp text,
  capability_title text, need_text text, last_message text, last_message_at timestamptz,
  last_from_me boolean, unread int
)
language sql
stable
security definer
set search_path to ''
as $$
  select cn.id, cn.status, cn.intro_message, cn.created_at, cn.responded_at,
         req.owner_profile_id = (select auth.uid()),
         me.id,
         other.id, other.name, other.avatar_url, other.city,
         case when cn.status = 'accepted' then other.instagram_url end,
         case when cn.status = 'accepted' then other.whatsapp end,
         cap.title, i.raw_text,
         lm.body, lm.created_at, lm.sender_entity_id = me.id,
         (select count(*)::int from public.messages u
           where u.connection_id = cn.id and u.read_at is null and u.sender_entity_id <> me.id)
  from public.connections cn
  join public.entities req on req.id = cn.requester_entity_id
  join public.entities rec on rec.id = cn.recipient_entity_id
  join public.entities me
    on me.id = case when req.owner_profile_id = (select auth.uid()) then req.id else rec.id end
  join public.entities other
    on other.id = case when req.owner_profile_id = (select auth.uid()) then rec.id else req.id end
  left join public.matches m on m.id = cn.match_id
  left join public.entity_capabilities cap on cap.id = m.target_capability_id
  left join public.intents i on i.id = m.source_intent_id
  left join lateral (
    select x.body, x.created_at, x.sender_entity_id from public.messages x
     where x.connection_id = cn.id order by x.created_at desc limit 1
  ) lm on true
  where (select auth.uid()) in (req.owner_profile_id, rec.owner_profile_id)
  order by coalesce(lm.created_at, cn.created_at) desc
  limit 200;
$$;

revoke all on function public.list_my_connections() from public, anon;
revoke all on function public.my_badges() from public, anon;
revoke all on function public.mark_messages_read(uuid) from public, anon;
grant execute on function public.list_my_connections() to authenticated;
grant execute on function public.my_badges() to authenticated;
grant execute on function public.mark_messages_read(uuid) to authenticated;

-- Mensajes en tiempo real.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
