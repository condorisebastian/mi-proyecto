-- Solo catálogo público de la web. No modifica cuentas, saldos ni pagos de la app.
begin;

create table public.web_catalog_meta (
  id boolean primary key default true check (id),
  version text not null,
  origin text not null,
  currency text not null default 'BOB' check (currency = 'BOB'),
  notice text not null
);
create table public.web_routes (
  id text primary key check (id ~ '^[a-z0-9_]+$'),
  destination text not null,
  province text not null,
  fare_cents integer check (fare_cents > 0 and fare_cents <= 10000000),
  status text not null default 'pendiente' check (status in ('pendiente','piloto','verificada')),
  sort_order integer not null,
  published boolean not null default false,
  check ((fare_cents is null) = (status = 'pendiente'))
);
create index web_routes_public_order on public.web_routes (sort_order, id) where published;

alter table public.web_catalog_meta enable row level security;
alter table public.web_routes enable row level security;
revoke all on table public.web_catalog_meta, public.web_routes from public, anon, authenticated;
grant select on table public.web_catalog_meta to anon, authenticated;
grant select (id, destination, province, fare_cents, status, sort_order) on public.web_routes to anon, authenticated;
create policy web_meta_read on public.web_catalog_meta for select to anon, authenticated using (true);
create policy web_routes_published_read on public.web_routes for select to anon, authenticated using (published = true);

create function public.web_route_catalog() returns jsonb
language sql stable security invoker
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'version', meta.version, 'origin', meta.origin, 'currency', meta.currency, 'notice', meta.notice,
    'routes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'destination', r.destination, 'province', r.province,
        'fare_cents', r.fare_cents, 'status', r.status
      ) order by r.sort_order, r.id) from public.web_routes r
    ), '[]'::jsonb)
  ) from public.web_catalog_meta meta where meta.id = true;
$$;
revoke all on function public.web_route_catalog() from public;
grant execute on function public.web_route_catalog() to anon, authenticated;

commit;
