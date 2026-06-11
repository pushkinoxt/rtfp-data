-- Migration 037: Seed three more VLOP providers — completing the commerce
-- category (Booking.com, Google Shopping) and the social category (YouTube).
--
-- All three use provider_type values that already exist ('marketplace',
-- 'social_network'), so no taxonomy-widening migration is needed yet. The
-- app stores, adult-content trio and Maps/Wikipedia will need that widening.
--
-- Legal entities, countries and designation dates are from the Commission's
-- official register; verify the provider name against each bundle's 01_ID.csv
-- when you load (the loader records file 01's name separately, so a wording
-- mismatch is logged, not fatal). report_url is set per-filing afterwards,
-- the way migration 034 did, once load_filing.py has created the filing rows.

INSERT INTO providers (
    slug, name, legal_entity, service_type, service_category,
    provider_type, designated_on, country_of_establishment
) VALUES
-- ---- Commerce ----
(
    'booking', 'Booking.com', 'Booking.com B.V.',
    'VLOP', 'Travel', 'marketplace', '2023-12-20', 'NL'
),
(
    'google-shopping', 'Google Shopping', 'Google Ireland Limited',
    'VLOP', 'Marketplace', 'marketplace', '2023-04-25', 'IE'
),
-- ---- Social ----
(
    'youtube', 'YouTube', 'Google Ireland Limited',
    'VLOP', 'Video sharing', 'social_network', '2023-04-25', 'IE'
);
