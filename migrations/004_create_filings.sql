-- Migration 004: Create the filings table
-- The provenance backbone: every quantitative data row will FK to here.
-- Models the three time axes (period covered, original publication,
-- this-version publication) and supports restatements via self-reference.

DROP TABLE IF EXISTS filings CASCADE;

CREATE TABLE filings (
    id                          BIGSERIAL PRIMARY KEY,

    -- Identity
    provider_id                 BIGINT NOT NULL REFERENCES providers(id),
    slug                        TEXT NOT NULL UNIQUE
                                CHECK (slug ~ '^[a-z0-9][a-z0-9/-]*$'),
    service_name                TEXT,

    -- The three time axes
    period_start                DATE NOT NULL,
    period_end                  DATE NOT NULL,
    period_label                TEXT NOT NULL
                                CHECK (period_label ~ '^[0-9]{4}-(h1|h2|annual)$'),
    original_published_on       DATE NOT NULL,
    this_version_published_on   DATE NOT NULL,

    -- Restatement support
    restates_filing_id          BIGINT REFERENCES filings(id),
    version_number              INTEGER NOT NULL DEFAULT 1
                                CHECK (version_number >= 1),
    restatement_reason          TEXT,

    -- Provenance
    report_url                  TEXT,
    source_files_hash           TEXT,
    name_of_service_provider    TEXT,

    -- Housekeeping
    imported_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes                       TEXT,

    UNIQUE (provider_id, service_name, period_label, version_number),

    CHECK (period_end >= period_start),
    CHECK (this_version_published_on >= original_published_on),
    CHECK (
        (restates_filing_id IS NULL AND version_number = 1)
        OR
        (restates_filing_id IS NOT NULL AND version_number > 1)
    )
);

COMMENT ON TABLE filings IS
    'One row per published filing event. Original publications and any '
    'subsequent restatements (per Article 5 of Implementing Regulation '
    '2024/2835) are each rows. Restatements self-reference the original '
    'via restates_filing_id.';

COMMENT ON COLUMN filings.slug IS
    'URL-friendly identifier composed as {provider_slug}/{period_label}'
    ' and optionally /v{n} for restatements.';
COMMENT ON COLUMN filings.period_label IS
    'Short label, e.g. 2025-h2 or 2025-annual. Used for human display and slugs.';
COMMENT ON COLUMN filings.original_published_on IS
    'Date the original (v1) of this filing was published.';
COMMENT ON COLUMN filings.this_version_published_on IS
    'Publication date of THIS specific version. For v1, equals original_published_on.';
COMMENT ON COLUMN filings.source_files_hash IS
    'SHA-256 of the source CSV bundle, for cryptographic provenance.';

ALTER TABLE filings ENABLE ROW LEVEL SECURITY;
