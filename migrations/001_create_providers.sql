-- Migration 001: Create the providers table
-- Stores VLOPs and VLOSEs designated by the European Commission under Article 33 DSA
-- Reference: https://digital-strategy.ec.europa.eu/en/policies/list-designated-vlops-and-vloses

CREATE TABLE providers (
    id                          BIGSERIAL PRIMARY KEY,
    slug                        TEXT NOT NULL UNIQUE
                                CHECK (slug ~ '^[a-z0-9][a-z0-9-]*$'),
    name                        TEXT NOT NULL,
    legal_entity                TEXT,
    service_type                TEXT NOT NULL
                                CHECK (service_type IN ('VLOP', 'VLOSE', 'Both')),
    service_category            TEXT
                                CHECK (service_category IN (
                                    'Social media', 'Video sharing', 'Marketplace',
                                    'App store', 'Search engine', 'Adult content',
                                    'Travel', 'Knowledge', 'Professional network',
                                    'Other'
                                )),
    designated_on               DATE,
    designation_decision_url    TEXT,
    commission_id               TEXT,
    country_of_establishment    CHAR(2),
    notes                       TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE providers IS
    'VLOPs and VLOSEs designated by the European Commission under Article 33 DSA.';

COMMENT ON COLUMN providers.slug IS
    'URL-safe identifier used in the public API.';
COMMENT ON COLUMN providers.legal_entity IS
    'Legal person designated by the Commission, may differ from operating brand name.';
COMMENT ON COLUMN providers.commission_id IS
    'Platform identifier in the DSA Transparency Database, if known.';

-- Seed: TikTok (first VLOP we'll be loading data for)
INSERT INTO providers (
    slug, name, legal_entity, service_type, service_category,
    designated_on, designation_decision_url, country_of_establishment, notes
) VALUES (
    'tiktok',
    'TikTok',
    'TikTok Technology Limited',
    'VLOP',
    'Video sharing',
    '2023-04-25',
    'https://digital-strategy.ec.europa.eu/en/library/commission-designates-first-set-very-large-online-platforms-and-search-engines',
    'IE',
    'Established in Ireland; Coimisiún na Meán is the Digital Services Coordinator with primary supervisory jurisdiction over non-systemic obligations.'
);
