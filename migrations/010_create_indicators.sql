-- Migration 010: Create the unified indicators table
-- Holds the long-format indicators from files 07, 08, 09, 10:
--   - Article 20/21 appeals and out-of-court disputes
--   - Article 15(1)(b)(c)(e) + 42(2)(c) automated moderation indicators
--   - Article 42(2)(a)(b) human moderator indicators
--   - Article 42(3) AMAR (Average Monthly Active Recipients)
-- All four files share the same five-column shape, so we use one table.

DROP TABLE IF EXISTS indicators CASCADE;

CREATE TABLE indicators (
    id                      BIGSERIAL PRIMARY KEY,
    filing_id               BIGINT NOT NULL REFERENCES filings(id) ON DELETE CASCADE,

    source_file             TEXT NOT NULL,        -- e.g. '07_Appeals.csv'
    section                 TEXT NOT NULL,        -- e.g. 'Internal complaints mechanism'
    indicator               TEXT NOT NULL,        -- e.g. 'Number of complaints submitted...'
    scope                   TEXT NOT NULL,        -- 'total', country code, 'EU', etc.
    value                   TEXT,                 -- exactly as published
    value_numeric           NUMERIC GENERATED ALWAYS AS (
                                CASE
                                    WHEN value IS NULL THEN NULL
                                    WHEN regexp_replace(value, '[,\s]', '', 'g') ~ '^-?\d+(\.\d+)?$'
                                        THEN regexp_replace(value, '[,\s]', '', 'g')::NUMERIC
                                    ELSE NULL
                                END
                            ) STORED,
    context                 TEXT,

    UNIQUE (filing_id, source_file, section, indicator, scope)
);

COMMENT ON TABLE indicators IS
    'Long-format indicators from Annex II files 07-10: appeals, automated '
    'moderation, human resources, and AMAR. One row per (filing, indicator, scope).';

COMMENT ON COLUMN indicators.value IS
    'Raw value as published by the provider, preserved verbatim including '
    'commas in thousands separators. Use value_numeric for arithmetic.';
COMMENT ON COLUMN indicators.value_numeric IS
    'Computed numeric form of value with commas stripped. NULL if value '
    'is non-numeric or unparseable.';
COMMENT ON COLUMN indicators.scope IS
    'Geographic or aggregation scope: "total", an ISO-3166 country code, or other.';

CREATE INDEX idx_ind_filing ON indicators (filing_id);
CREATE INDEX idx_ind_source ON indicators (source_file);
CREATE INDEX idx_ind_section ON indicators (section);

ALTER TABLE indicators ENABLE ROW LEVEL SECURITY;
