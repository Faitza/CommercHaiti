-- ════════════════════════════════════════════════════════════════
-- Migration — frais de livraison par zone (feature/frais-livraison)
--
-- Chaque boutique fixe le prix de livraison de chacune de ses zones
-- (écran « Modifier la boutique »). Le prix est rangé dans le tableau
-- JSON existant shops.zones_livraison, clé "frais" (en HTG) :
--   [{"zone": "Torbeck", "delai_min": 20, "delai_max": 45, "frais": 150}]
-- Aucune colonne n'est ajoutée à shops.
--
-- À la création d'une commande, le serveur lit le prix de la zone
-- choisie, l'enregistre dans orders.frais_livraison et l'ajoute à
-- orders.total : le client ne peut pas envoyer lui-même un autre prix.
-- Zone sans prix = 0 HTG.
--
-- Zone absente de la liste de la boutique : la commande est refusée
-- (« Cette boutique ne livre pas dans cette zone »), sauf retrait en
-- boutique ('Retrait en boutique') ou boutique sans aucune zone déclarée
-- (anciennes boutiques : commande acceptée, 0 HTG).
--
-- À exécuter UNE fois dans Supabase → SQL Editor (peut être relancé).
-- ════════════════════════════════════════════════════════════════

alter table public.orders
  add column if not exists frais_livraison numeric(10,2) not null default 0;

create or replace function public.appliquer_frais_livraison()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_frais numeric(10,2);
  v_zones jsonb;
begin
  select coalesce(s.zones_livraison, '[]'::jsonb) into v_zones
  from public.shops s where s.id = new.shop_id;

  if coalesce(new.zone, '') <> 'Retrait en boutique'
     and jsonb_array_length(coalesce(v_zones, '[]'::jsonb)) > 0
     and not exists (
       select 1 from jsonb_array_elements(v_zones) z
       where lower(trim(z->>'zone')) = lower(trim(coalesce(new.zone, '')))
     ) then
    raise exception 'Cette boutique ne livre pas dans cette zone'
      using errcode = 'P0001';
  end if;

  select coalesce(max(nullif(z->>'frais', '')::numeric), 0)
  into v_frais
  from public.shops s,
       jsonb_array_elements(s.zones_livraison) z
  where s.id = new.shop_id
    and lower(trim(z->>'zone')) = lower(trim(new.zone));

  new.frais_livraison := greatest(coalesce(v_frais, 0), 0);
  new.total := new.total + new.frais_livraison;
  return new;
end;
$$;

drop trigger if exists trg_appliquer_frais_livraison on public.orders;
create trigger trg_appliquer_frais_livraison
before insert on public.orders
for each row execute function public.appliquer_frais_livraison();
