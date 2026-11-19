-- Solid ID e «Dov'è»: tabelle e regole di sicurezza su Supabase.
-- Da eseguire una volta nel progetto: Supabase › SQL Editor › New query › incolla tutto › Run.
-- Si può rieseguire senza danni (crea solo ciò che manca e aggiorna le regole).
--
-- Regola di fondo (Row Level Security): ogni persona vede e modifica SOLO i propri dispositivi.

-- ── Profilo (nome mostrato) ──────────────────────────────────────────────────
create table if not exists public.profili (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null default '' check (char_length(nome) <= 80),
  creato timestamptz not null default now()
);

-- ── Dispositivi dell'account ──────────────────────────────────────────────────
create table if not exists public.dispositivi (
  id uuid primary key default gen_random_uuid(),
  proprietario uuid not null default auth.uid() references auth.users (id) on delete cascade,
  codice text not null check (char_length(codice) between 16 and 128),   -- impronta del dispositivo (non la machine-id)
  nome text not null default '' check (char_length(nome) <= 80),
  tipo text not null default 'computer' check (tipo in ('computer', 'portatile', 'telefono', 'tablet')),
  modello text not null default '' check (char_length(modello) <= 120),
  sistema text not null default '' check (char_length(sistema) <= 80),
  batteria smallint check (batteria between 0 and 100),
  in_carica boolean,
  trova_attivo boolean not null default true,
  lat double precision check (lat between -90 and 90),
  lon double precision check (lon between -180 and 180),
  precisione real,
  fonte_posizione text check (fonte_posizione in ('gps', 'wifi', 'ip')),
  posizione_quando timestamptz,
  ultimo_visto timestamptz not null default now(),
  bloccato boolean not null default false,
  messaggio_blocco text check (char_length(messaggio_blocco) <= 200),
  creato timestamptz not null default now(),
  unique (proprietario, codice)
);
create index if not exists dispositivi_proprietario on public.dispositivi (proprietario);

-- ── Comandi a distanza (fai suonare, blocca…) ────────────────────────────────
create table if not exists public.comandi (
  id bigint generated always as identity primary key,
  dispositivo uuid not null references public.dispositivi (id) on delete cascade,
  proprietario uuid not null default auth.uid() references auth.users (id) on delete cascade,
  tipo text not null check (tipo in ('suona', 'ferma', 'blocca', 'posizione')),
  messaggio text check (char_length(messaggio) <= 200),
  stato text not null default 'inviato' check (stato in ('inviato', 'ricevuto', 'eseguito', 'errore')),
  creato timestamptz not null default now(),
  eseguito timestamptz
);
create index if not exists comandi_dispositivo on public.comandi (dispositivo, stato);

-- ── Regole di sicurezza ───────────────────────────────────────────────────────
alter table public.profili enable row level security;
alter table public.dispositivi enable row level security;
alter table public.comandi enable row level security;

drop policy if exists "profilo proprio" on public.profili;
create policy "profilo proprio" on public.profili
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "dispositivi propri" on public.dispositivi;
create policy "dispositivi propri" on public.dispositivi
  for all to authenticated using (proprietario = auth.uid()) with check (proprietario = auth.uid());

drop policy if exists "comandi propri" on public.comandi;
create policy "comandi propri" on public.comandi
  for all to authenticated
  using (proprietario = auth.uid())
  with check (proprietario = auth.uid()
              and exists (select 1 from public.dispositivi d where d.id = dispositivo and d.proprietario = auth.uid()));

-- Nessun accesso per chi non ha fatto l'accesso
revoke all on public.profili, public.dispositivi, public.comandi from anon;
grant select, insert, update, delete on public.profili, public.dispositivi, public.comandi to authenticated;

-- Profilo creato in automatico alla registrazione (nome dai dati della registrazione)
create or replace function public.nuovo_profilo() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profili (id, nome)
  values (new.id, coalesce(left(new.raw_user_meta_data ->> 'nome', 80), ''))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists nuovo_profilo on auth.users;
create trigger nuovo_profilo after insert on auth.users
  for each row execute function public.nuovo_profilo();

-- Comandi in tempo reale: il dispositivo riceve «fai suonare» subito
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'comandi') then
    alter publication supabase_realtime add table public.comandi;
  end if;
end $$;

-- Pulizia: i comandi più vecchi di 30 giorni non servono più
create or replace function public.pulisci_comandi() returns void
language sql security definer set search_path = public as $$
  delete from public.comandi where creato < now() - interval '30 days' and proprietario = auth.uid();
$$;
grant execute on function public.pulisci_comandi() to authenticated;

-- ══ Recensioni delle app dello Store (SolidOS App sul PC e Store sul telefono) ═══════════
-- Le leggono tutti (anche senza accesso); le scrive solo chi ha un Solid ID, UNA per app,
-- e ognuno può modificare o togliere solo la propria. Il nome mostrato lo mette il database
-- dal profilo (nessuno può firmarsi con il nome di un altro).
create table if not exists public.recensioni (
  id uuid primary key default gen_random_uuid(),
  app text not null check (app ~ '^[A-Za-z0-9._-]{3,200}$'),
  autore uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome text not null default '',
  voto smallint not null check (voto between 1 and 5),
  titolo text not null default '' check (char_length(titolo) <= 80),
  testo text not null default '' check (char_length(testo) <= 2000),
  creata timestamptz not null default now(),
  modificata timestamptz not null default now(),
  unique (app, autore)
);
create index if not exists recensioni_app on public.recensioni (app, modificata desc);

-- «Utile»: un voto per persona per recensione
create table if not exists public.recensioni_utili (
  recensione uuid not null references public.recensioni (id) on delete cascade,
  persona uuid not null default auth.uid() references auth.users (id) on delete cascade,
  primary key (recensione, persona)
);

create or replace function public.recensione_firmata() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.autore := auth.uid();
  new.nome := coalesce(nullif((select nome from public.profili where id = auth.uid()), ''), 'Utente SolidOS');
  new.modificata := now();
  return new;
end $$;
drop trigger if exists recensione_firmata on public.recensioni;
create trigger recensione_firmata before insert or update on public.recensioni
  for each row execute function public.recensione_firmata();

alter table public.recensioni enable row level security;
alter table public.recensioni_utili enable row level security;

drop policy if exists "recensioni leggibili" on public.recensioni;
create policy "recensioni leggibili" on public.recensioni for select to anon, authenticated using (true);
drop policy if exists "recensione propria" on public.recensioni;
create policy "recensione propria" on public.recensioni for insert to authenticated with check (autore = auth.uid());
drop policy if exists "recensione propria modifica" on public.recensioni;
create policy "recensione propria modifica" on public.recensioni for update to authenticated
  using (autore = auth.uid()) with check (autore = auth.uid());
drop policy if exists "recensione propria cancella" on public.recensioni;
create policy "recensione propria cancella" on public.recensioni for delete to authenticated using (autore = auth.uid());

drop policy if exists "utili leggibili" on public.recensioni_utili;
create policy "utili leggibili" on public.recensioni_utili for select to anon, authenticated using (true);
drop policy if exists "utile proprio" on public.recensioni_utili;
create policy "utile proprio" on public.recensioni_utili for insert to authenticated with check (persona = auth.uid());
drop policy if exists "utile proprio cancella" on public.recensioni_utili;
create policy "utile proprio cancella" on public.recensioni_utili for delete to authenticated using (persona = auth.uid());

grant select on public.recensioni, public.recensioni_utili to anon, authenticated;
grant insert, update, delete on public.recensioni to authenticated;
grant insert, delete on public.recensioni_utili to authenticated;

-- Voto medio e distribuzione per app; elenco con il numero di «Utile»
create or replace view public.voti_app with (security_invoker = true) as
  select app, count(*)::int as totale, round(avg(voto)::numeric, 1)::float as media,
         count(*) filter (where voto = 5)::int as v5, count(*) filter (where voto = 4)::int as v4,
         count(*) filter (where voto = 3)::int as v3, count(*) filter (where voto = 2)::int as v2,
         count(*) filter (where voto = 1)::int as v1
  from public.recensioni group by app;
create or replace view public.recensioni_complete with (security_invoker = true) as
  select r.id, r.app, r.nome, r.voto, r.titolo, r.testo, r.modificata,
         (select count(*) from public.recensioni_utili u where u.recensione = r.id)::int as utili,
         (r.autore = auth.uid()) as mia
  from public.recensioni r;
grant select on public.voti_app, public.recensioni_complete to anon, authenticated;

-- ══ Le mie app (come «Acquistati» sull'App Store) ══════════════════════════════════════
-- Ogni app presa dallo Store (sul PC o sul telefono) entra nell'elenco del proprio Solid ID:
-- gli altri dispositivi la mostrano in «Le mie app» e, se si vuole, la scaricano da soli.
-- Ognuno vede e cambia solo il proprio elenco.
create table if not exists public.app_mie (
  utente uuid not null default auth.uid() references auth.users (id) on delete cascade,
  app text not null check (app ~ '^[A-Za-z0-9._-]{3,200}$'),
  nome text not null default '' check (char_length(nome) <= 120),
  icona text not null default '' check (char_length(icona) <= 400),
  dispositivo text not null default '' check (char_length(dispositivo) <= 60),
  aggiunta timestamptz not null default now(),
  primary key (utente, app)
);
alter table public.app_mie enable row level security;
drop policy if exists "app mie proprie" on public.app_mie;
create policy "app mie proprie" on public.app_mie for all to authenticated
  using (utente = auth.uid()) with check (utente = auth.uid());
grant select, insert, update, delete on public.app_mie to authenticated;
