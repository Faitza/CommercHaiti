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
-- Zone absente de la liste de la boutique (ou sans prix) = 0 HTG.
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
begin
  select coalesce(max(nullif(z->>'frais', '')::numeric), 0)
  into v_frais
  from public.shops s,
       jsonb_array_elements(s.zones_livraison) z
  where s.id = new.shop_id
    and z->>'zone' = new.zone;

  new.frais_livraison := greatest(coalesce(v_frais, 0), 0);
  new.total := new.total + new.frais_livraison;
  return new;
end;
$$;

drop trigger if exists trg_appliquer_frais_livraison on public.orders;
create trigger trg_appliquer_frais_livraison
before insert on public.orders
for each row execute function public.appliquer_frais_livraison();
