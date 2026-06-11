-- Migration 044: Seed Google Play (app_store) and Google Maps (other).
--
-- Both are Google Ireland Limited services, designated 25 April 2023, reported in the
-- same combined Google cycle. Their provider_type values became valid in migration 043.
-- Like Shopping and YouTube, each ships an _Ads surface (loaded as a second service)
-- and an AMAR that only points at report 24 (backfilled afterward from the per-country
-- table). File 01's "Name of the service provider" is "Google" for both; the seed name
-- is the service, matching how google-shopping and youtube were seeded. service_category
-- uses the existing allowed labels ('App store'; 'Other' for Maps, which compares to
-- nothing else cleanly).

INSERT INTO providers (
    slug, name, legal_entity, service_type, service_category,
    provider_type, designated_on, country_of_establishment
) VALUES
(
    'google-play', 'Google Play', 'Google Ireland Limited',
    'VLOP', 'App store', 'app_store', '2023-04-25', 'IE'
),
(
    'google-maps', 'Google Maps', 'Google Ireland Limited',
    'VLOP', 'Other', 'other', '2023-04-25', 'IE'
);
