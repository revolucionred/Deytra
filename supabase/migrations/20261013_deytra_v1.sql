-- Deytra v1: categorías para particulares, bloqueos y reportes, perfiles públicos
-- mínimos, lista de conexiones y eliminación de cuenta.
-- Solo AGREGA: no modifica ni borra tablas, políticas ni datos existentes.

-- 1) Categorías pensadas para necesidades de particulares
insert into public.categories (slug, name_es, name_en) values
 ('hogar-jardin','Hogar y jardín','Home & garden'),
 ('jardineria','Jardinería y corte de pasto','Gardening'),
 ('paisajismo','Paisajismo','Landscaping'),
 ('viveros-plantas','Plantas y viveros','Plants & nurseries'),
 ('decoracion','Decoración','Decor'),
 ('carpinteria','Carpintería','Carpentry'),
 ('pintura','Pintura','Painting'),
 ('herreria','Herrería','Metalwork'),
 ('reparaciones','Arreglos del hogar','Home repairs'),
 ('mudanzas','Mudanzas y fletes','Moving'),
 ('comida-casera','Comida casera y viandas','Home-cooked meals'),
 ('nutricion','Nutrición y alimentación saludable','Nutrition'),
 ('recetas-contenido','Recetas y contenido de cocina','Recipes & food content'),
 ('reposteria','Pastelería y tortas','Baking'),
 ('deporte-entrenamiento','Deporte y entrenamiento','Fitness & training'),
 ('bienestar','Bienestar','Wellbeing'),
 ('clases-particulares','Clases particulares','Tutoring'),
 ('cuidado-ninos','Cuidado de niños','Childcare'),
 ('cuidado-mayores','Cuidado de personas mayores','Elder care'),
 ('mascotas','Mascotas','Pets'),
 ('autos-mecanica','Autos y mecánica','Cars & mechanics'),
 ('moda-costura','Moda y costura','Fashion & sewing'),
 ('musica','Música','Music'),
 ('arte-manualidades','Arte y manualidades','Arts & crafts'),
 ('creadores-contenido','Creadores de contenido','Content creators'),
 ('comunicacion-negocios','Comunicación para emprendimientos','Business communication'),
 ('agencias','Agencias','Agencies'),
 ('tramites','Trámites y gestiones','Paperwork & errands'),
 ('compra-venta','Compra y venta entre personas','Buy & sell'),
 ('otros','Otros','Other')
on conflict (slug) do nothing;

-- 2) Bloqueos y reportes (requisito de las tiendas para apps con contenido entre usuarios)
create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_entity_id uuid not null references public.entities(id) on delete cascade,
  blocked_entity_id uuid not null references public.entities(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_entity_id, blocked_entity_id),
  check (blocker_entity_id <> blocked_entity_id)
);
alter table public.blocks enable row level security;
create policy blocks_owner_select on public.blocks for select to authenticated
  using ((select private.owns_entity(blocker_entity_id)));
create policy blocks_owner_insert on public.blocks for insert to authenticated
  with check ((select private.owns_entity(blocker_entity_id)));
create policy blocks_owner_delete on public.blocks for delete to authenticated
  using ((select private.owns_entity(blocker_entity_id)));
grant select, insert, delete on public.blocks to authenticated;

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_entity_id uuid not null references public.entities(id) on delete cascade,
  reported_entity_id uuid references public.entities(id) on delete set null,
  reported_capability_id uuid references public.entity_capabilities(id) on delete set null,
  reason text not null check (reason in ('spam','fraude','inapropiado','acoso','otro')),
  details text check (details is null or length(details) <= 1000),
  status text not null default 'open' check (status in ('open','reviewed','closed')),
  created_at timestamptz not null default now()
);
alter table public.reports enable row level security;
create policy reports_owner_insert on public.reports for insert to authenticated
  with check ((select private.owns_entity(reporter_entity_id)) and status = 'open');
create policy reports_owner_select on public.reports for select to authenticated
  using ((select private.owns_entity(reporter_entity_id)));
grant select, insert on public.reports to authenticated;
create index if not exists idx_blocks_blocker on public.blocks(blocker_entity_id);
create index if not exists idx_blocks_blocked on public.blocks(blocked_entity_id);
create index if not exists idx_reports_reporter on public.reports(reporter_entity_id);

-- 3) Perfil público mínimo: solo de quien ofrece algo activo o comparte una conexión conmigo
create or replace function public.get_public_profiles(p_entity_ids uuid[])
returns table (id uuid, name text, avatar_url text, city text, description text,
               instagram_url text, website_url text)
language sql stable security definer set search_path = ''
as $$
  select e.id, e.name, e.avatar_url, e.city, e.description, e.instagram_url, e.website_url
  from public.entities e
  where e.id = any(p_entity_ids)
    and (select auth.uid()) is not null
    and e.is_active is distinct from false
    and cardinality(p_entity_ids) <= 50
    and (
      exists (select 1 from public.entity_capabilities c where c.entity_id = e.id and c.is_active)
      or exists (
        select 1 from public.connections cn
        join public.entities me on me.id in (cn.requester_entity_id, cn.recipient_entity_id)
        where e.id in (cn.requester_entity_id, cn.recipient_entity_id)
          and me.owner_profile_id = (select auth.uid())
      )
    );
$$;
revoke all on function public.get_public_profiles(uuid[]) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;

-- 4) Mis conexiones con los datos de la otra persona
create or replace function public.list_my_connections()
returns table (
  id uuid, status text, intro_message text, created_at timestamptz, responded_at timestamptz,
  i_am_requester boolean, other_entity_id uuid, other_name text, other_avatar_url text,
  other_city text, other_instagram_url text, capability_title text, need_text text
)
language sql stable security definer set search_path = ''
as $$
  select cn.id, cn.status, cn.intro_message, cn.created_at, cn.responded_at,
         req.owner_profile_id = (select auth.uid()),
         other.id, other.name, other.avatar_url, other.city,
         case when cn.status = 'accepted' then other.instagram_url end,
         cap.title, i.raw_text
  from public.connections cn
  join public.entities req on req.id = cn.requester_entity_id
  join public.entities rec on rec.id = cn.recipient_entity_id
  join public.entities other
    on other.id = case when req.owner_profile_id = (select auth.uid()) then rec.id else req.id end
  left join public.matches m on m.id = cn.match_id
  left join public.entity_capabilities cap on cap.id = m.target_capability_id
  left join public.intents i on i.id = m.source_intent_id
  where (select auth.uid()) in (req.owner_profile_id, rec.owner_profile_id)
  order by cn.created_at desc
  limit 200;
$$;
revoke all on function public.list_my_connections() from public, anon;
grant execute on function public.list_my_connections() to authenticated;

-- 5) Eliminar cuenta (exigido por Apple y Google)
create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  delete from public.connections cn
   using public.entities e
   where e.owner_profile_id = v_uid
     and e.id in (cn.requester_entity_id, cn.recipient_entity_id);
  delete from public.connections cn
   using public.matches m, public.entities e
   where cn.match_id = m.id and e.owner_profile_id = v_uid
     and (m.target_entity_id = e.id
          or m.source_intent_id in (select i.id from public.intents i where i.entity_id = e.id));
  delete from auth.users where id = v_uid;
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
