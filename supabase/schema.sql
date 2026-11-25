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

-- ══ Sicurezza di «Dov'è» come su iPhone ═══════════════════════════════════════════════
-- 1) Comandi in più: «cancella» (inizializza a distanza) e «perso» (modalità smarrito).
alter table public.comandi drop constraint if exists comandi_tipo_check;
alter table public.comandi add constraint comandi_tipo_check
  check (tipo in ('suona', 'ferma', 'blocca', 'perso', 'cancella', 'posizione'));
alter table public.dispositivi add column if not exists perso boolean not null default false;

-- 2) Blocco di attivazione: l'impronta dell'hardware (non cambia con un reset o una nuova
-- installazione). Un telefono collegato a un Solid ID, anche se cancellato, chiede la password
-- di quell'account prima di poter essere usato.
alter table public.dispositivi add column if not exists hardware text
  check (hardware is null or char_length(hardware) between 16 and 128);
create index if not exists dispositivi_hardware on public.dispositivi (hardware);

-- Risponde solo «è bloccato da p•••@gmail.com» (email nascosta), senza mostrare altro.
-- Chi ha già fatto l'accesso con l'account proprietario vede «non bloccato».
create or replace function public.blocco_attivazione(h text) returns text
language sql stable security definer set search_path = public as $$
  select regexp_replace(u.email, '^(.).*(@.*)$', '\1•••\2')
  from public.dispositivi d join auth.users u on u.id = d.proprietario
  where h is not null and char_length(h) between 16 and 128
    and d.hardware = h and d.trova_attivo
    and (auth.uid() is null or d.proprietario <> auth.uid())
  order by d.ultimo_visto desc limit 1
$$;
revoke all on function public.blocco_attivazione(text) from public;
grant execute on function public.blocco_attivazione(text) to anon, authenticated;

-- ══ Videochiamate ═══════════════════════════════════════════════════════════════════
-- Audio e video vanno DIRETTI tra i due dispositivi (WebRTC, cifrati da un capo all'altro):
-- qui passano solo i messaggi per mettersi in contatto (offerta, risposta, indirizzi di rete,
-- fine). Ognuno vede solo i messaggi che ha mandato o che sono per lui; si cancellano da soli
-- dopo un giorno.
create table if not exists public.chiamate_segnali (
  id bigint generated always as identity primary key,
  chiamata uuid not null,
  da uuid not null default auth.uid() references auth.users (id) on delete cascade,
  a uuid not null references auth.users (id) on delete cascade,
  dispositivo text not null default '' check (char_length(dispositivo) <= 80),   -- dispositivo che manda
  tipo text not null check (tipo in ('offerta', 'risposta', 'candidato', 'fine', 'rifiuta', 'occupato', 'presa')),
  dati jsonb not null default '{}'::jsonb check (pg_column_size(dati) <= 16000),
  creato timestamptz not null default now()
);
create index if not exists chiamate_segnali_a on public.chiamate_segnali (a, chiamata);
alter table public.chiamate_segnali enable row level security;
drop policy if exists "segnali miei" on public.chiamate_segnali;
create policy "segnali miei" on public.chiamate_segnali for select to authenticated
  using (a = auth.uid() or da = auth.uid());
drop policy if exists "segnali mandati da me" on public.chiamate_segnali;
create policy "segnali mandati da me" on public.chiamate_segnali for insert to authenticated
  with check (da = auth.uid());
revoke all on public.chiamate_segnali from anon;
grant select, insert on public.chiamate_segnali to authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chiamate_segnali') then
    alter publication supabase_realtime add table public.chiamate_segnali;
  end if;
end $$;

-- Pulizia automatica dei segnali vecchi di chi scrive
create or replace function public.pulisci_segnali() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.chiamate_segnali where creato < now() - interval '1 day' and (da = new.da or a = new.da);
  return new;
end $$;
drop trigger if exists pulisci_segnali on public.chiamate_segnali;
create trigger pulisci_segnali after insert on public.chiamate_segnali
  for each row when (new.tipo = 'offerta') execute function public.pulisci_segnali();

-- Trova una persona da chiamare: solo con l'email esatta, risponde id e nome (niente elenchi).
create or replace function public.persona_da_email(e text) returns table (id uuid, nome text)
language sql stable security definer set search_path = public as $$
  select u.id, coalesce(nullif(p.nome, ''), split_part(u.email, '@', 1))
  from auth.users u left join public.profili p on p.id = u.id
  where auth.uid() is not null and e is not null and char_length(e) <= 254
    and lower(u.email) = lower(trim(e))
  limit 1
$$;
revoke all on function public.persona_da_email(text) from public, anon;
grant execute on function public.persona_da_email(text) to authenticated;

-- ── Sincronia dei dati tra i dispositivi (contatti, calendari, eventi, liste, promemoria, note) ──
-- Una riga per voce, visibile solo al proprietario; «modificato» si aggiorna da solo.
create table if not exists public.sincronia (
  proprietario uuid not null default auth.uid() references auth.users (id) on delete cascade,
  raccolta text not null,
  voce text not null,
  dati jsonb,
  eliminato boolean not null default false,
  dispositivo text,
  modificato timestamptz not null default now(),
  primary key (proprietario, raccolta, voce)
);
create index if not exists sincronia_modificato on public.sincronia (proprietario, modificato);
alter table public.sincronia enable row level security;
drop policy if exists "sincronia propria" on public.sincronia;
create policy "sincronia propria" on public.sincronia
  for all to authenticated using (proprietario = auth.uid()) with check (proprietario = auth.uid());
create or replace function public.sincronia_modificato() returns trigger language plpgsql as $$
begin new.modificato := now(); return new; end $$;
drop trigger if exists sincronia_modificato on public.sincronia;
create trigger sincronia_modificato before insert or update on public.sincronia
  for each row execute function public.sincronia_modificato();
