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
