-- How people predicted, for many matches at once (the match list shows each one's 1 / X / 2 split as green bars):
-- only the counts, as fixture_pool gives them for one match; who picked what stays private.
create or replace function public.fixture_pools(p_ids bigint[]) returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(x.fixture_id::text, jsonb_build_object('n', x.n, 'c1', x.c1, 'cX', x.cx, 'c2', x.c2)), '{}')
  from (
    select p.fixture_id, count(*) as n,
      count(*) filter (where p.pick = '1') as c1, count(*) filter (where p.pick = 'X') as cx, count(*) filter (where p.pick = '2') as c2
    from public.predictions p
    where p.fixture_id = any ((coalesce(p_ids, '{}'))[1:200])
    group by p.fixture_id
  ) x
$$;
revoke execute on function public.fixture_pools(bigint[]) from public, anon;
grant execute on function public.fixture_pools(bigint[]) to authenticated;
