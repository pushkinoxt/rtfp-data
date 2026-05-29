-- Migration 002: Seed Instagram, LinkedIn, and X as additional VLOPs
-- whose H2 2025 filings will be loaded as part of the MVP.
-- (TikTok included with ON CONFLICT so the migration is safe to re-run.)
-- Reference: https://digital-strategy.ec.europa.eu/en/policies/list-designated-vlops-and-vloses

INSERT INTO providers (
    slug, name, legal_entity, service_type, service_category,
    designated_on, designation_decision_url, country_of_establishment, notes
) VALUES
(
    'instagram',
    'Instagram',
    'Meta Platforms Ireland Limited',
    'VLOP',
    'Social media',
    '2023-04-25',
    'https://digital-strategy.ec.europa.eu/en/library/commission-designates-first-set-very-large-online-platforms-and-search-engines',
    'IE',
    'Operated by Meta Platforms Ireland Limited; Coimisiún na Meán is the DSC. Facebook is a separately designated VLOP under the same legal entity.'
),
(
    'linkedin',
    'LinkedIn',
    'LinkedIn Ireland Unlimited Company',
    'VLOP',
    'Professional network',
    '2023-04-25',
    'https://digital-strategy.ec.europa.eu/en/library/commission-designates-first-set-very-large-online-platforms-and-search-engines',
    'IE',
    'Established in Ireland; Coimisiún na Meán is the DSC.'
),
(
    'x',
    'X',
    'X Internet Unlimited Company',
    'VLOP',
    'Social media',
    '2023-04-25',
    'https://digital-strategy.ec.europa.eu/en/library/commission-designates-first-set-very-large-online-platforms-and-search-engines',
    'IE',
    'Formerly Twitter; rebranded to X in July 2023. Established in Ireland; Coimisiún na Meán is the DSC. Subject to multiple formal Commission proceedings under the DSA since December 2023.'
),
(
    'tiktok',
    'TikTok',
    'TikTok Technology Limited',
    'VLOP',
    'Video sharing',
    '2023-04-25',
    'https://digital-strategy.ec.europa.eu/en/library/commission-designates-first-set-very-large-online-platforms-and-search-engines',
    'IE',
    'Established in Ireland; Coimisiún na Meán is the Digital Services Coordinator with primary supervisory jurisdiction over non-systemic obligations.'
)
ON CONFLICT (slug) DO NOTHING;
