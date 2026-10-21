-- Deytra v3: "Avisame cuando aparezca", avisos internos y panel para la dueña.

-- Lugares ya ubicados (los completa el servidor de búsqueda), para medir distancias.
create table if not exists public.geo_places (
  name_norm text primary key,
  name text not null,
  province text,
  latitude double precision not null,
  longitude double precision not null,
  updated_at timestamptz not null default now()
);
alter table public.geo_places enable row level security;
revoke all on public.geo_places from anon, authenticated;

create or replace function private.norm_place(t text)
returns text language sql immutable set search_path to '' as $$
  select btrim(translate(lower(coalesce(t, '')), 'áàäâéèëêíìïîóòöôúùüûñ', 'aaaaeeeeiiiioooouuuun'));
$$;

create or replace function private.km(lat1 double precision, lon1 double precision,
                                      lat2 double precision, lon2 double precision)
returns double precision language sql immutable set search_path to '' as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lon2 - lon1) / 2), 2)));
$$;

-- Alertas de búsqueda.
create table if not exists public.search_alerts (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities(id) on delete cascade,
  intent_id uuid not null references public.intents(id) on delete cascade,
  search_text text not null,
  category_ids uuid[] not null default '{}',
  city text,
  latitude double precision,
  longitude double precision,
  radius_km double precision not null default 30,
  location_required boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '60 days',
  unique (entity_id, intent_id)
);
create index if not exists search_alerts_active_idx on public.search_alerts using gin (category_ids) where active;
alter table public.search_alerts enable row level security;
drop policy if exists search_alerts_owner_read on public.search_alerts;
create policy search_alerts_owner_read on public.search_alerts
  for select to authenticated using ((select private.owns_entity(entity_id)));
drop policy if exists search_alerts_owner_update on public.search_alerts;
create policy search_alerts_owner_update on public.search_alerts
  for update to authenticated
  using ((select private.owns_entity(entity_id)))
  with check ((select private.owns_entity(entity_id)));
revoke insert, delete on public.search_alerts from anon, authenticated;
grant select, update (active) on public.search_alerts to authenticated;

-- Avisos internos.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities(id) on delete cascade,
  kind text not null check (kind in ('alert_match', 'connection_request', 'connection_accepted')),
  title text not null,
  body text,
  search_text text,
  alert_id uuid references public.search_alerts(id) on delete cascade,
  capability_id uuid references public.entity_capabilities(id) on delete cascade,
  connection_id uuid references public.connections(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create unique index if not exists notifications_alert_once
  on public.notifications (alert_id, capability_id) where kind = 'alert_match';
create index if not exists notifications_entity_idx on public.notifications (entity_id, created_at desc);
alter table public.notifications enable row level security;
drop policy if exists notifications_owner_read on public.notifications;
create policy notifications_owner_read on public.notifications
  for select to authenticated using ((select private.owns_entity(entity_id)));
revoke insert, update, delete on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;

-- Crear una alerta a partir de una búsqueda propia.
create or replace function public.create_search_alert(p_intent_id uuid)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_id uuid;
  i public.intents%rowtype;
  v_cats uuid[];
begin
  select * into i from public.intents where id = p_intent_id;
  if i.id is null or not private.owns_entity(i.entity_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select coalesce(array_agg(x::uuid), '{}') into v_cats
    from jsonb_array_elements_text(coalesce(i.metadata -> 'category_ids', '[]'::jsonb)) x;
  if cardinality(v_cats) = 0 and i.category_id is not null then
    v_cats := array[i.category_id];
  end if;
  insert into public.search_alerts (entity_id, intent_id, search_text, category_ids, city,
                                    latitude, longitude, radius_km, location_required)
  values (i.entity_id, i.id, i.raw_text, v_cats, i.city, i.latitude, i.longitude,
          greatest(coalesce(i.radius_km, 30), 30), coalesce(i.location_importance, '') = 'required')
  on conflict (entity_id, intent_id) do update
    set active = true, expires_at = now() + interval '60 days'
  returning id into v_id;
  return v_id;
end;
$$;

-- Cuando alguien publica algo, avisa a quienes lo estaban buscando.
create or replace function private.on_capability_published()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_lat double precision := new.latitude;
  v_lon double precision := new.longitude;
begin
  if new.is_active is not true or new.category_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.is_active is true
     and old.category_id is not distinct from new.category_id
     and old.city is not distinct from new.city then
    return new;
  end if;
  if v_lat is null and new.city is not null then
    select g.latitude, g.longitude into v_lat, v_lon
      from public.geo_places g where g.name_norm = private.norm_place(new.city);
  end if;
  insert into public.notifications (entity_id, kind, title, body, search_text, alert_id, capability_id)
  select a.entity_id, 'alert_match', 'Apareció alguien para lo que buscabas',
         new.title || coalesce(' · ' || new.city, ''), a.search_text, a.id, new.id
    from public.search_alerts a
   where a.active and a.expires_at > now()
     and a.entity_id <> new.entity_id
     and new.category_id = any (a.category_ids)
     and (
       not a.location_required
       or new.modality in ('remoto', 'hibrido')
       or (a.latitude is not null and v_lat is not null
           and private.km(a.latitude, a.longitude, v_lat, v_lon) <= greatest(a.radius_km, 30))
       or (v_lat is null and private.norm_place(a.city) = private.norm_place(new.city))
     )
     and not exists (
       select 1 from public.blocks b
        where (b.blocker_entity_id = a.entity_id and b.blocked_entity_id = new.entity_id)
           or (b.blocker_entity_id = new.entity_id and b.blocked_entity_id = a.entity_id))
  on conflict do nothing;
  return new;
end;
$$;
drop trigger if exists capability_published_alerts on public.entity_capabilities;
create trigger capability_published_alerts
  after insert or update of is_active, category_id, city on public.entity_capabilities
  for each row execute function private.on_capability_published();

-- Avisos de solicitudes de contacto.
create or replace function private.on_connection_change()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_name text;
begin
  if tg_op = 'INSERT' then
    select name into v_name from public.entities where id = new.requester_entity_id;
    insert into public.notifications (entity_id, kind, title, body, connection_id)
    values (new.recipient_entity_id, 'connection_request',
            coalesce(v_name, 'Alguien') || ' quiere contactarte',
            'Mirá la solicitud y decidí si la aceptás.', new.id);
  elsif new.status = 'accepted' and old.status is distinct from 'accepted' then
    select name into v_name from public.entities where id = new.recipient_entity_id;
    insert into public.notifications (entity_id, kind, title, body, connection_id)
    values (new.requester_entity_id, 'connection_accepted',
            coalesce(v_name, 'La otra persona') || ' aceptó tu solicitud',
            'Ya pueden hablar por el chat.', new.id);
  end if;
  return new;
end;
$$;
drop trigger if exists connection_notifications on public.connections;
create trigger connection_notifications
  after insert or update of status on public.connections
  for each row execute function private.on_connection_change();

create or replace function public.mark_notifications_read()
returns void language sql security definer set search_path to '' as $$
  update public.notifications n set read_at = now()
   where n.read_at is null
     and n.entity_id in (select e.id from public.entities e where e.owner_profile_id = (select auth.uid()));
$$;

-- Contadores del inicio, ahora con avisos sin leer.
drop function if exists public.my_badges();
create function public.my_badges()
returns table (pending_requests int, unread_messages int, unread_notifications int)
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
          or c.recipient_entity_id in (select id from mine))),
    (select count(*)::int from public.notifications n
      where n.read_at is null and n.entity_id in (select id from mine));
$$;

-- Panel de la dueña.
create table if not exists private.admins (user_id uuid primary key);
insert into private.admins (user_id)
select id from auth.users where lower(email) = 'revolucionredmkt@gmail.com'
on conflict do nothing;

create or replace function public.is_deytra_admin()
returns boolean language sql stable security definer set search_path to '' as $$
  select exists (select 1 from private.admins a where a.user_id = (select auth.uid()));
$$;

create or replace function public.admin_overview(p_days int default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 365)));
  v_out jsonb;
begin
  if not exists (select 1 from private.admins a where a.user_id = (select auth.uid())) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  with s as (
    select i.*,
           exists (select 1 from public.matches m where m.source_intent_id = i.id) as answered
      from public.intents i
     where i.created_at >= since and coalesce(i.direction, 'seek') = 'seek'
  )
  select jsonb_build_object(
    'days', greatest(1, least(coalesce(p_days, 30), 365)),
    'totals', jsonb_build_object(
      'people', (select count(*) from public.users),
      'new_people', (select count(*) from public.users u where u.created_at >= since),
      'offers_active', (select count(*) from public.entity_capabilities c where c.is_active),
      'offers_new', (select count(*) from public.entity_capabilities c where c.created_at >= since),
      'searches', (select count(*) from s),
      'searches_answered', (select count(*) from s where s.answered),
      'connections', (select count(*) from public.connections c where c.created_at >= since),
      'accepted', (select count(*) from public.connections c where c.created_at >= since and c.status = 'accepted'),
      'messages', (select count(*) from public.messages m where m.created_at >= since),
      'alerts_active', (select count(*) from public.search_alerts a where a.active and a.expires_at > now()),
      'reports_open', (select count(*) from public.reports r where coalesce(r.status, 'open') = 'open')
    ),
    'ai', jsonb_build_object(
      'understood_by_ai', (select count(*) from s where s.metadata ->> 'understood_by' = 'ai'),
      'web_searches', (select count(*) from s where s.metadata ->> 'web_used' = 'true'),
      'web_reused', (select count(*) from s where s.metadata ->> 'web_cached' = 'true'),
      'cost_usd', round(((select count(*) from s where s.metadata ->> 'web_used' = 'true') * 0.012
                 + (select count(*) from s where s.metadata ->> 'understood_by' = 'ai') * 0.0004)::numeric, 2)
    ),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', d::date, 'searches', coalesce(x.n, 0)) order by d)
        from generate_series(date_trunc('day', now()) - interval '13 days', date_trunc('day', now()), interval '1 day') d
        left join (select date_trunc('day', created_at) as d0, count(*) as n from public.intents
                    where created_at >= now() - interval '14 days' group by 1) x on x.d0 = d), '[]'::jsonb),
    'unanswered', coalesce((
      select jsonb_agg(t) from (
        select coalesce(c.name_es, s.category_raw, 'Sin rubro') as topic,
               coalesce(s.city, 'Sin ciudad') as city, count(*) as n,
               (array_agg(s.raw_text order by s.created_at desc))[1] as example
          from s left join public.categories c on c.id = coalesce(s.category_id,
                 nullif(s.metadata -> 'category_ids' ->> 0, '')::uuid)
         where not s.answered
         group by 1, 2 order by 3 desc limit 15) t), '[]'::jsonb),
    'top_topics', coalesce((
      select jsonb_agg(t) from (
        select coalesce(c.name_es, s.category_raw, 'Sin rubro') as topic, count(*) as n
          from s left join public.categories c on c.id = coalesce(s.category_id,
                 nullif(s.metadata -> 'category_ids' ->> 0, '')::uuid)
         group by 1 order by 2 desc limit 10) t), '[]'::jsonb),
    'top_cities', coalesce((
      select jsonb_agg(t) from (
        select coalesce(s.city, 'Sin ciudad') as city, count(*) as n
          from s group by 1 order by 2 desc limit 10) t), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(t) from (
        select r.created_at, r.reason, r.details, coalesce(r.status, 'open') as status,
               e.name as reported_name
          from public.reports r left join public.entities e on e.id = r.reported_entity_id
         order by r.created_at desc limit 10) t), '[]'::jsonb)
  ) into v_out;
  return v_out;
end;
$$;

revoke all on function public.create_search_alert(uuid) from public, anon;
revoke all on function public.mark_notifications_read() from public, anon;
revoke all on function public.my_badges() from public, anon;
revoke all on function public.is_deytra_admin() from public, anon;
revoke all on function public.admin_overview(int) from public, anon;
grant execute on function public.create_search_alert(uuid) to authenticated;
grant execute on function public.mark_notifications_read() to authenticated;
grant execute on function public.my_badges() to authenticated;
grant execute on function public.is_deytra_admin() to authenticated;
grant execute on function public.admin_overview(int) to authenticated;
