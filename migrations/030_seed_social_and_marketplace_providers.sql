-- Migration 030: Seed the eight additional providers for the
-- "Social platforms / Marketplaces" expansion.
--
-- Legal entities and countries taken from the Commission's official
-- designation list. provider_type added in migration 028; service_category
-- constrained per migration 001.

INSERT INTO providers (
    slug, name, legal_entity, service_type, service_category,
    provider_type, designated_on, country_of_establishment
) VALUES
-- ---- Social platforms ----
(
    'facebook', 'Facebook', 'Meta Platforms Ireland Limited (MPIL)',
    'VLOP', 'Social media', 'social_network', '2023-04-25', 'IE'
),
(
    'snapchat', 'Snapchat', 'Snap B.V.',
    'VLOP', 'Social media', 'social_network', '2023-04-25', 'NL'
),
(
    'pinterest', 'Pinterest', 'Pinterest Europe Ltd.',
    'VLOP', 'Social media', 'social_network', '2023-04-25', 'IE'
),
-- ---- Marketplaces ----
(
    'amazon-store', 'Amazon Store', 'Amazon EU S.à r.l.',
    'VLOP', 'Marketplace', 'marketplace', '2023-04-25', 'LU'
),
(
    'shein', 'Shein', 'Infinite Styles Services Co, Ltd',
    'VLOP', 'Marketplace', 'marketplace', '2024-04-26', 'IE'
),
(
    'temu', 'Temu', 'Whaleco Technology Limited',
    'VLOP', 'Marketplace', 'marketplace', '2024-05-31', 'IE'
),
(
    'zalando', 'Zalando', 'Zalando SE',
    'VLOP', 'Marketplace', 'marketplace', '2023-04-25', 'DE'
),
(
    'aliexpress', 'AliExpress', 'AliExpress International (Netherlands) B.V.',
    'VLOP', 'Marketplace', 'marketplace', '2023-04-25', 'NL'
);
