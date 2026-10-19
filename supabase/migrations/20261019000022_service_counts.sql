-- live numbers for the services strip on the home screen (what the person can see, counted in one request)
create or replace function public.service_counts()
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
  select jsonb_build_object(
    'rooms', (select count(*) from public.rooms r where r.live and r.created_at > now() - interval '12 hours'),
    'events', (select count(*) from public.events e where e.starts_at between now() and now() + interval '7 days'),
    'sport', (select count(*) from public.fixtures f where f.status = 'upcoming' and f.starts_at between now() - interval '3 hours' and now() + interval '7 days'),
    'help', (select count(*) from public.help_requests h where h.status = 'open' and (h.expires_at is null or h.expires_at > now())),
    'rides', (select count(*) from public.rides d where d.status = 'open' and d.depart_at > now()),
    'jobs', (select count(*) from public.jobs j where j.status = 'open'),
    'market', (select count(*) from public.listings l where l.status = 'active'),
    'places', (select count(*) from public.places),
    'groups', (select count(*) from public.groups),
    'pages', (select count(*) from public.pages),
    'albums', (select count(*) from public.albums),
    'toasts', (select count(*) from public.toasts)
  );
$function$;
revoke execute on function public.service_counts() from public, anon;
grant execute on function public.service_counts() to authenticated;
