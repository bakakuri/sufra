-- Matches that add themselves: the Premier League, the Bundesliga, La Liga and Ligue 1 from football-data.org (its
-- free key lives in private.config as 'football_data_key'). Every minute pg_cron looks: the answer to the last
-- question is taken, and a new question goes out every 30 minutes, every 2 while a match is on. New matches of the
-- next week come in with Georgian team names; their time follows the source while nobody has settled them; the score
-- is written as the match goes. A finished match waits for staff to confirm it (admin_settle_fixture), because the
-- winners are paid in coins and that stays a person's decision. Nothing is cancelled by itself either (a cancel gives
-- stakes back). The Georgian league stays added by hand.

alter table public.fixtures
  add column if not exists ext_id text unique,
  add column if not exists home_en text,
  add column if not exists away_en text,
  add column if not exists live_state text check (live_state in ('scheduled', 'live', 'paused', 'finished', 'postponed', 'suspended', 'cancelled')),
  add column if not exists live_home int check (live_home >= 0),
  add column if not exists live_away int check (live_away >= 0),
  add column if not exists synced_at timestamptz;

create index if not exists fixtures_pending_idx on public.fixtures (starts_at) where status = 'upcoming' and ext_id is not null;

-- a team's name as a key: small letters without accents, without FC/CF/SC… and numbers ("1. FC Köln" → "koln")
create or replace function private.team_key(t text) returns text language sql immutable set search_path = '' as $$
  select btrim(regexp_replace(regexp_replace(
    ' ' || regexp_replace(translate(lower(coalesce(t, '')), 'áàâäãåāéèêëēíìîïóòôöõøúùûüñçćčšžłßı''', 'aaaaaaaeeeeeiiiioooooouuuuncccszlsi '), '[^a-z0-9]+', ' ', 'g') || ' ',
    ' (fc|afc|cf|sc|ac|ssc|cd|ud|ca|rc|rcd|sd|club|de|del|la|[0-9]+)(?= )', ' ', 'g'), ' +', ' ', 'g'))
$$;

-- the Georgian names: the key of the English name → how we write it
create table if not exists private.team_names (key text primary key, ka text not null check (char_length(ka) between 2 and 60));

insert into private.team_names (key, ka)
select distinct on (private.team_key(en)) private.team_key(en), ka from (values
  -- England
  ('Arsenal', 'არსენალი'), ('Aston Villa', 'ასტონ ვილა'), ('Bournemouth', 'ბორნმუთი'), ('Brentford', 'ბრენტფორდი'),
  ('Brighton & Hove Albion', 'ბრაიტონი'), ('Brighton Hove', 'ბრაიტონი'), ('Brighton', 'ბრაიტონი'), ('Chelsea', 'ჩელსი'),
  ('Crystal Palace', 'კრისტალ პალასი'), ('Everton', 'ევერტონი'), ('Fulham', 'ფულჰემი'), ('Liverpool', 'ლივერპული'),
  ('Manchester City', 'მანჩესტერ სიტი'), ('Man City', 'მანჩესტერ სიტი'), ('Manchester United', 'მანჩესტერ იუნაიტედი'), ('Man United', 'მანჩესტერ იუნაიტედი'),
  ('Newcastle United', 'ნიუკასლი'), ('Newcastle', 'ნიუკასლი'), ('Nottingham Forest', 'ნოტინგემ ფორესტი'), ('Nottingham', 'ნოტინგემ ფორესტი'),
  ('Tottenham Hotspur', 'ტოტენჰემი'), ('Tottenham', 'ტოტენჰემი'), ('West Ham United', 'ვესტ ჰემი'), ('West Ham', 'ვესტ ჰემი'),
  ('Wolverhampton Wanderers', 'ვულვერჰემპტონი'), ('Wolverhampton', 'ვულვერჰემპტონი'), ('Wolves', 'ვულვერჰემპტონი'),
  ('Leeds United', 'ლიდსი'), ('Leeds', 'ლიდსი'), ('Burnley', 'ბერნლი'), ('Sunderland', 'სანდერლენდი'),
  ('Coventry City', 'ქოვენთრი'), ('Coventry', 'ქოვენთრი'), ('Ipswich Town', 'იფსვიჩი'), ('Ipswich', 'იფსვიჩი'),
  ('Leicester City', 'ლესტერი'), ('Leicester', 'ლესტერი'), ('Southampton', 'საუთჰემპტონი'), ('Sheffield United', 'შეფილდ იუნაიტედი'),
  ('Sheffield Utd', 'შეფილდ იუნაიტედი'), ('Sheffield Wednesday', 'შეფილდ უენსდეი'), ('Middlesbrough', 'მიდლსბრო'), ('Norwich City', 'ნორვიჩი'), ('Norwich', 'ნორვიჩი'),
  ('Watford', 'უოტფორდი'), ('West Bromwich Albion', 'ვესტ ბრომვიჩი'), ('West Brom', 'ვესტ ბრომვიჩი'), ('Hull City', 'ჰალ სიტი'), ('Hull', 'ჰალ სიტი'),
  ('Stoke City', 'სტოკ სიტი'), ('Stoke', 'სტოკ სიტი'), ('Swansea City', 'სუონსი'), ('Swansea', 'სუონსი'), ('Birmingham City', 'ბირმინგემი'), ('Birmingham', 'ბირმინგემი'),
  ('Wrexham', 'რექსემი'), ('Preston North End', 'პრესტონი'), ('Preston', 'პრესტონი'), ('Bristol City', 'ბრისტოლ სიტი'), ('Millwall', 'მილუოლი'),
  ('Derby County', 'დერბი'), ('Derby', 'დერბი'), ('Portsmouth', 'პორტსმუთი'), ('Queens Park Rangers', 'ქუინს პარკ რეინჯერსი'), ('QPR', 'ქუინს პარკ რეინჯერსი'),
  ('Charlton Athletic', 'ჩარლტონი'), ('Charlton', 'ჩარლტონი'), ('Blackburn Rovers', 'ბლექბერნი'), ('Blackburn', 'ბლექბერნი'), ('Oxford United', 'ოქსფორდი'), ('Luton Town', 'ლუტონი'), ('Cardiff City', 'კარდიფი'),
  -- Germany
  ('FC Bayern München', 'ბაიერნი'), ('Bayern München', 'ბაიერნი'), ('Bayern', 'ბაიერნი'), ('Borussia Dortmund', 'ბორუსია დორტმუნდი'), ('Dortmund', 'ბორუსია დორტმუნდი'),
  ('Bayer 04 Leverkusen', 'ბაიერ ლევერკუზენი'), ('Bayer Leverkusen', 'ბაიერ ლევერკუზენი'), ('Leverkusen', 'ბაიერ ლევერკუზენი'), ('RB Leipzig', 'ლაიფციგი'), ('Leipzig', 'ლაიფციგი'),
  ('Eintracht Frankfurt', 'აინტრახტ ფრანკფურტი'), ('Frankfurt', 'აინტრახტ ფრანკფურტი'), ('VfB Stuttgart', 'შტუტგარტი'), ('Stuttgart', 'შტუტგარტი'),
  ('SC Freiburg', 'ფრაიბურგი'), ('VfL Wolfsburg', 'ვოლფსბურგი'), ('Wolfsburg', 'ვოლფსბურგი'), ('1. FSV Mainz 05', 'მაინცი'), ('Mainz', 'მაინცი'), ('FSV Mainz', 'მაინცი'),
  ('Borussia Mönchengladbach', 'ბორუსია მიონხენგლადბახი'), ('M''gladbach', 'ბორუსია მიონხენგლადბახი'), ('Mönchengladbach', 'ბორუსია მიონხენგლადბახი'),
  ('TSG 1899 Hoffenheim', 'ჰოფენჰაიმი'), ('Hoffenheim', 'ჰოფენჰაიმი'), ('TSG Hoffenheim', 'ჰოფენჰაიმი'), ('SV Werder Bremen', 'ვერდერ ბრემენი'), ('Werder Bremen', 'ვერდერ ბრემენი'), ('Bremen', 'ვერდერ ბრემენი'),
  ('FC Augsburg', 'აუგსბურგი'), ('1. FC Union Berlin', 'უნიონ ბერლინი'), ('Union Berlin', 'უნიონ ბერლინი'), ('1. FC Heidenheim 1846', 'ჰაიდენჰაიმი'), ('Heidenheim', 'ჰაიდენჰაიმი'),
  ('FC St. Pauli 1910', 'სანკტ პაული'), ('St. Pauli', 'სანკტ პაული'), ('Hamburger SV', 'ჰამბურგი'), ('HSV', 'ჰამბურგი'), ('1. FC Köln', 'კიოლნი'), ('Köln', 'კიოლნი'),
  ('VfL Bochum 1848', 'ბოხუმი'), ('Bochum', 'ბოხუმი'), ('Holstein Kiel', 'ჰოლშტაინ კილი'), ('Kiel', 'ჰოლშტაინ კილი'), ('FC Schalke 04', 'შალკე'), ('Schalke', 'შალკე'),
  ('Hertha BSC', 'ჰერტა'), ('Hertha', 'ჰერტა'), ('Fortuna Düsseldorf', 'ფორტუნა დიუსელდორფი'), ('Düsseldorf', 'ფორტუნა დიუსელდორფი'), ('Hannover 96', 'ჰანოვერი'), ('Hannover', 'ჰანოვერი'),
  ('1. FC Kaiserslautern', 'კაიზერსლაუტერნი'), ('Kaiserslautern', 'კაიზერსლაუტერნი'), ('SC Paderborn 07', 'პადერბორნი'), ('Paderborn', 'პადერბორნი'), ('SV Elversberg', 'ელვერსბერგი'), ('Elversberg', 'ელვერსბერგი'),
  ('SV Darmstadt 98', 'დარმშტადტი'), ('Darmstadt', 'დარმშტადტი'), ('Karlsruher SC', 'კარლსრუე'), ('Karlsruhe', 'კარლსრუე'), ('1. FC Nürnberg', 'ნიურნბერგი'), ('Nürnberg', 'ნიურნბერგი'),
  ('1. FC Magdeburg', 'მაგდებურგი'), ('Magdeburg', 'მაგდებურგი'), ('SpVgg Greuther Fürth', 'გროიტერ ფიურტი'), ('Greuther Fürth', 'გროიტერ ფიურტი'),
  ('Eintracht Braunschweig', 'ბრაუნშვაიგი'), ('Braunschweig', 'ბრაუნშვაიგი'), ('Arminia Bielefeld', 'არმინია ბილეფელდი'), ('Bielefeld', 'არმინია ბილეფელდი'),
  ('Dynamo Dresden', 'დინამო დრეზდენი'), ('SC Preußen Münster', 'პროისენ მიუნსტერი'), ('Preußen Münster', 'პროისენ მიუნსტერი'),
  -- Spain
  ('Real Madrid', 'რეალ მადრიდი'), ('FC Barcelona', 'ბარსელონა'), ('Barcelona', 'ბარსელონა'), ('Barça', 'ბარსელონა'),
  ('Club Atlético de Madrid', 'ატლეტიკო მადრიდი'), ('Atlético Madrid', 'ატლეტიკო მადრიდი'), ('Atleti', 'ატლეტიკო მადრიდი'), ('Athletic Club', 'ათლეტიკ ბილბაო'), ('Athletic', 'ათლეტიკ ბილბაო'),
  ('Real Sociedad de Fútbol', 'რეალ სოსიედადი'), ('Real Sociedad', 'რეალ სოსიედადი'), ('Villarreal', 'ვიარეალი'), ('Real Betis Balompié', 'რეალ ბეტისი'), ('Real Betis', 'რეალ ბეტისი'), ('Betis', 'რეალ ბეტისი'),
  ('Sevilla', 'სევილია'), ('Valencia', 'ვალენსია'), ('Girona', 'ჟირონა'), ('RC Celta de Vigo', 'სელტა'), ('Celta', 'სელტა'), ('Celta Vigo', 'სელტა'),
  ('CA Osasuna', 'ოსასუნა'), ('Osasuna', 'ოსასუნა'), ('RCD Mallorca', 'მალიორკა'), ('Mallorca', 'მალიორკა'), ('Rayo Vallecano de Madrid', 'რაიო ვალეკანო'), ('Rayo Vallecano', 'რაიო ვალეკანო'),
  ('Getafe', 'ხეტაფე'), ('Deportivo Alavés', 'ალავესი'), ('Alavés', 'ალავესი'), ('RCD Espanyol de Barcelona', 'ესპანიოლი'), ('Espanyol', 'ესპანიოლი'),
  ('Levante UD', 'ლევანტე'), ('Levante', 'ლევანტე'), ('Elche', 'ელჩე'), ('Real Oviedo', 'ოვიედო'), ('Oviedo', 'ოვიედო'), ('UD Las Palmas', 'ლას პალმასი'), ('Las Palmas', 'ლას პალმასი'),
  ('CD Leganés', 'ლეგანესი'), ('Leganés', 'ლეგანესი'), ('Real Valladolid', 'ვალიადოლიდი'), ('Valladolid', 'ვალიადოლიდი'), ('Real Racing Club de Santander', 'რასინგ სანტანდერი'),
  ('Racing Santander', 'რასინგ სანტანდერი'), ('Deportivo La Coruña', 'დეპორტივო'), ('Deportivo', 'დეპორტივო'), ('UD Almería', 'ალმერია'), ('Almería', 'ალმერია'),
  ('Granada', 'გრანადა'), ('Cádiz', 'კადისი'), ('Málaga', 'მალაგა'), ('Real Zaragoza', 'სარაგოსა'), ('Zaragoza', 'სარაგოსა'), ('Real Sporting de Gijón', 'სპორტინგ ხიხონი'),
  ('Sporting Gijón', 'სპორტინგ ხიხონი'), ('SD Eibar', 'ეიბარი'), ('Eibar', 'ეიბარი'), ('SD Huesca', 'უესკა'), ('Huesca', 'უესკა'), ('Castellón', 'კასტელიონი'), ('Albacete', 'ალბასეტე'),
  ('Burgos', 'ბურგოსი'), ('Córdoba', 'კორდობა'), ('Mirandés', 'მირანდესი'), ('Tenerife', 'ტენერიფე'),
  -- France
  ('Paris Saint-Germain', 'პარი სენ-ჟერმენი'), ('PSG', 'პარი სენ-ჟერმენი'), ('Olympique de Marseille', 'მარსელი'), ('Marseille', 'მარსელი'), ('AS Monaco', 'მონაკო'), ('Monaco', 'მონაკო'),
  ('Lille OSC', 'ლილი'), ('Lille', 'ლილი'), ('Olympique Lyonnais', 'ლიონი'), ('Lyon', 'ლიონი'), ('OGC Nice', 'ნიცა'), ('Nice', 'ნიცა'), ('Racing Club de Lens', 'ლანსი'), ('RC Lens', 'ლანსი'), ('Lens', 'ლანსი'),
  ('Stade Rennais FC 1901', 'რენი'), ('Stade Rennais', 'რენი'), ('Rennes', 'რენი'), ('Stade Brestois 29', 'ბრესტი'), ('Brest', 'ბრესტი'), ('RC Strasbourg Alsace', 'სტრასბური'), ('Strasbourg', 'სტრასბური'),
  ('Toulouse', 'ტულუზა'), ('AJ Auxerre', 'ოსერი'), ('Auxerre', 'ოსერი'), ('Angers SCO', 'ანჟე'), ('Angers', 'ანჟე'), ('Le Havre AC', 'ჰავრი'), ('Le Havre', 'ჰავრი'),
  ('FC Nantes', 'ნანტი'), ('Nantes', 'ნანტი'), ('FC Lorient', 'ლორიანი'), ('Lorient', 'ლორიანი'), ('Paris FC', 'პარიზი'), ('FC Metz', 'მეცი'), ('Metz', 'მეცი'),
  ('AS Saint-Étienne', 'სენტ-ეტიენი'), ('Saint-Étienne', 'სენტ-ეტიენი'), ('St Etienne', 'სენტ-ეტიენი'), ('Montpellier HSC', 'მონპელიე'), ('Montpellier', 'მონპელიე'),
  ('Stade de Reims', 'რეიმსი'), ('Reims', 'რეიმსი'), ('ES Troyes AC', 'ტრუა'), ('Troyes', 'ტრუა'), ('Le Mans', 'ლე მანი'), ('Red Star', 'რედ სტარი'), ('FC Annecy', 'ანესი'), ('Annecy', 'ანესი'),
  ('EA Guingamp', 'გენგამი'), ('Guingamp', 'გენგამი'), ('SM Caen', 'კანი'), ('Caen', 'კანი'), ('Clermont Foot 63', 'კლერმონი'), ('Clermont', 'კლერმონი'), ('AC Ajaccio', 'აიაჩო'), ('Ajaccio', 'აიაჩო'),
  ('Amiens SC', 'ამიენი'), ('Amiens', 'ამიენი'), ('Grenoble Foot 38', 'გრენობლი'), ('Grenoble', 'გრენობლი'), ('USL Dunkerque', 'დიუნკერკი'), ('Dunkerque', 'დიუნკერკი'),
  ('Pau', 'პო'), ('Rodez AF', 'როდეზი'), ('Rodez', 'როდეზი'), ('SC Bastia', 'ბასტია'), ('Bastia', 'ბასტია'), ('Stade Lavallois', 'ლავალი'), ('Laval', 'ლავალი')
) v(en, ka)
on conflict (key) do update set ka = excluded.ka;

-- the name we show for a team: ours, else the source's short name, else its full one
create or replace function private.team_ka(t jsonb) returns text language sql stable set search_path = '' as $$
  select left(coalesce(
    (select n.ka from private.team_names n where n.key = private.team_key(t->>'name')),
    (select n.ka from private.team_names n where n.key = private.team_key(t->>'shortName')),
    nullif(btrim(t->>'shortName'), ''), nullif(btrim(t->>'name'), ''), '—'), 60)
$$;

-- what the last look found (one row)
create table if not exists private.fixture_sync (
  id int primary key default 1 check (id = 1),
  req bigint, asked_at timestamptz, took_at timestamptz, last_error text, added int not null default 0
);
insert into private.fixture_sync (id) values (1) on conflict do nothing;

-- one answer of football-data.org (/v4/matches) taken in; how many matches are new
create or replace function private.fixtures_take(j jsonb) returns int language plpgsql security definer set search_path = '' as $$
declare m jsonb; st text; lg text; ext text; kick timestamptz; hs int; aws int; hn text; an text; n int := 0;
begin
  for m in select * from jsonb_array_elements(coalesce(j->'matches', '[]')) loop
    lg := case m->'competition'->>'code' when 'PL' then 'პრემიერ ლიგა' when 'BL1' then 'ბუნდესლიგა' when 'PD' then 'ლა ლიგა' when 'FL1' then 'ლიგა 1' end;
    if lg is null or m->>'id' is null or m->>'utcDate' is null then continue; end if;
    ext := 'fd:' || (m->>'id');
    kick := (m->>'utcDate')::timestamptz;
    st := case m->>'status'
      when 'SCHEDULED' then 'scheduled' when 'TIMED' then 'scheduled' when 'IN_PLAY' then 'live' when 'PAUSED' then 'paused'
      when 'FINISHED' then 'finished' when 'AWARDED' then 'finished' when 'POSTPONED' then 'postponed'
      when 'SUSPENDED' then 'suspended' when 'CANCELLED' then 'cancelled' else null end;
    hs := nullif(m->'score'->'fullTime'->>'home', '')::int;
    aws := nullif(m->'score'->'fullTime'->>'away', '')::int;
    if st in ('scheduled', 'postponed') then hs := null; aws := null; end if;
    update public.fixtures f set
      starts_at = case when f.status = 'upcoming' and st in ('scheduled', 'postponed') then kick else f.starts_at end,
      live_state = st, live_home = hs, live_away = aws, synced_at = now()
    where f.ext_id = ext;
    if not found and st = 'scheduled' and kick > now() then
      hn := private.team_ka(m->'homeTeam'); an := private.team_ka(m->'awayTeam');
      -- a team the source has not named yet (a cup draw still to come): later
      if char_length(hn) < 2 or char_length(an) < 2 then continue; end if;
      insert into public.fixtures (league, home, away, starts_at, ext_id, home_en, away_en, live_state, synced_at)
      values (lg, hn, an, kick, ext,
              left(coalesce(m->'homeTeam'->>'name', m->'homeTeam'->>'shortName'), 80), left(coalesce(m->'awayTeam'->>'name', m->'awayTeam'->>'shortName'), 80), st, now())
      on conflict (ext_id) do nothing;
      if found then n := n + 1; end if;
    end if;
  end loop;
  return n;
end $$;
revoke execute on function private.fixtures_take(jsonb) from public;

-- the look, every minute (pg_cron): the last answer taken; a new question when it is time
create or replace function private.fixtures_sync() returns void language plpgsql security definer set search_path = '' as $$
declare k text; s record; r record; busy boolean; rid bigint; d date := (now() at time zone 'utc')::date;
begin
  select value into k from private.config where key = 'football_data_key';
  if coalesce(k, '') = '' then return; end if;
  select * into s from private.fixture_sync where id = 1 for update skip locked;
  if not found then return; end if;
  if s.req is not null then
    select status_code, content, error_msg, timed_out into r from net._http_response where id = s.req;
    if found then
      if r.status_code = 200 then
        begin
          update private.fixture_sync set req = null, took_at = now(), last_error = null, added = added + private.fixtures_take(r.content::jsonb) where id = 1;
        exception when others then
          update private.fixture_sync set req = null, last_error = left('bad answer: ' || sqlerrm, 300) where id = 1;
        end;
      else
        update private.fixture_sync set req = null,
          last_error = left(coalesce(nullif(r.error_msg, ''), 'http ' || coalesce(r.status_code::text, '?') || ': ' || coalesce(r.content, '')), 300) where id = 1;
      end if;
    elsif s.asked_at < now() - interval '3 minutes' then
      update private.fixture_sync set req = null, last_error = 'no answer' where id = 1;
    else
      return;
    end if;
  end if;
  -- every 2 minutes from five minutes before a kick-off until the match is over, every 30 otherwise
  busy := exists (select 1 from public.fixtures f where f.ext_id is not null and f.status = 'upcoming'
    and f.starts_at between now() - interval '3 hours' and now() + interval '5 minutes'
    and coalesce(f.live_state, 'scheduled') not in ('finished', 'postponed', 'cancelled'));
  if s.asked_at is not null and s.asked_at > now() - (case when busy then interval '110 seconds' else interval '29 minutes' end) then return; end if;
  rid := net.http_get(
    url := 'https://api.football-data.org/v4/matches',
    params := jsonb_build_object('competitions', 'PL,BL1,PD,FL1', 'dateFrom', to_char(d - 1, 'YYYY-MM-DD'), 'dateTo', to_char(d + 7, 'YYYY-MM-DD')),
    headers := jsonb_build_object('X-Auth-Token', k),
    timeout_milliseconds := 20000);
  update private.fixture_sync set req = rid, asked_at = now() where id = 1;
end $$;
revoke execute on function private.fixtures_sync() from public;

select cron.schedule('peera-fixtures', '* * * * *', 'select private.fixtures_sync()');

-- staff: how the looking goes (for the match room)
create or replace function public.fixture_sync_state() returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  return (select jsonb_build_object('on', exists (select 1 from private.config where key = 'football_data_key' and value <> ''),
    'asked_at', s.asked_at, 'took_at', s.took_at, 'error', s.last_error, 'added', s.added) from private.fixture_sync s where s.id = 1);
end $$;
revoke execute on function public.fixture_sync_state() from public, anon;
grant execute on function public.fixture_sync_state() to authenticated;

-- staff: the teams' names of a match set right; for a match that came by itself the name stays for that team's
-- coming matches too
create or replace function public.admin_team_names(p_fixture bigint, p_home text, p_away text) returns void
language plpgsql security definer set search_path = '' as $$
declare f record; h text := btrim(coalesce(p_home, '')); a text := btrim(coalesce(p_away, ''));
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if char_length(h) not between 2 and 60 or char_length(a) not between 2 and 60 then raise exception 'bad_request'; end if;
  select * into f from public.fixtures where id = p_fixture for update;
  if f.id is null then raise exception 'not_found'; end if;
  update public.fixtures set home = h, away = a where id = p_fixture;
  if f.home_en is not null and h <> f.home then
    insert into private.team_names (key, ka) values (private.team_key(f.home_en), h) on conflict (key) do update set ka = excluded.ka;
    update public.fixtures set home = h where status = 'upcoming' and home_en = f.home_en;
    update public.fixtures set away = h where status = 'upcoming' and away_en = f.home_en;
  end if;
  if f.away_en is not null and a <> f.away then
    insert into private.team_names (key, ka) values (private.team_key(f.away_en), a) on conflict (key) do update set ka = excluded.ka;
    update public.fixtures set home = a where status = 'upcoming' and home_en = f.away_en;
    update public.fixtures set away = a where status = 'upcoming' and away_en = f.away_en;
  end if;
end $$;
revoke execute on function public.admin_team_names(bigint, text, text) from public, anon;
grant execute on function public.admin_team_names(bigint, text, text) to authenticated;
