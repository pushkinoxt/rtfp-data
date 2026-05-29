-- Migration 015: country_codes reference table, normalise_scope() helper,
-- and the first two views — amar_by_country and provider_overview.
--
-- Scope: Phase C of the DSA diff tool. Surfaces Article 42(3) DSA (per-Member-State
-- AMAR, also required under Article 24(2)) as a clean human- and API-friendly
-- view, and introduces the normalisation contract that every later view will use.

-- ===========================================================================
-- country_codes lookup table
-- ===========================================================================

DROP TABLE IF EXISTS country_codes CASCADE;

CREATE TABLE country_codes (
    code            TEXT PRIMARY KEY,            -- canonical lowercase, e.g. 'el', 'fr'
    name            TEXT NOT NULL,
    is_eu_member    BOOLEAN NOT NULL,
    is_eea_only     BOOLEAN NOT NULL DEFAULT FALSE,
    notes           TEXT
);

COMMENT ON TABLE country_codes IS
    'Country code reference. Uses EU convention (EL for Greece, not ISO-3166 GR). '
    'Covers EU27 plus the three EEA non-EU states (Iceland, Liechtenstein, Norway). '
    'Provider filings use varied codes and casing; normalise_scope() handles the '
    'mapping into this table.';

COMMENT ON COLUMN country_codes.code IS
    'Canonical lowercase code. EL not GR — see Greece row note.';

INSERT INTO country_codes (code, name, is_eu_member, is_eea_only, notes) VALUES
('at', 'Austria',        TRUE, FALSE, NULL),
('be', 'Belgium',        TRUE, FALSE, NULL),
('bg', 'Bulgaria',       TRUE, FALSE, NULL),
('hr', 'Croatia',        TRUE, FALSE, NULL),
('cy', 'Cyprus',         TRUE, FALSE, NULL),
('cz', 'Czechia',        TRUE, FALSE, NULL),
('dk', 'Denmark',        TRUE, FALSE, NULL),
('ee', 'Estonia',        TRUE, FALSE, NULL),
('fi', 'Finland',        TRUE, FALSE, NULL),
('fr', 'France',         TRUE, FALSE, NULL),
('de', 'Germany',        TRUE, FALSE, NULL),
('el', 'Greece',         TRUE, FALSE,
 'EU convention uses EL (from Greek Ελλάς) rather than ISO-3166 GR. '
 'TikTok H2 2025 used GR; Meta and LinkedIn used EL. normalise_scope() '
 'maps both to el.'),
('hu', 'Hungary',        TRUE, FALSE, NULL),
('ie', 'Ireland',        TRUE, FALSE, NULL),
('it', 'Italy',          TRUE, FALSE, NULL),
('lv', 'Latvia',         TRUE, FALSE, NULL),
('lt', 'Lithuania',      TRUE, FALSE, NULL),
('lu', 'Luxembourg',     TRUE, FALSE, NULL),
('mt', 'Malta',          TRUE, FALSE, NULL),
('nl', 'Netherlands',    TRUE, FALSE, NULL),
('pl', 'Poland',         TRUE, FALSE, NULL),
('pt', 'Portugal',       TRUE, FALSE, NULL),
('ro', 'Romania',        TRUE, FALSE, NULL),
('sk', 'Slovakia',       TRUE, FALSE, NULL),
('si', 'Slovenia',       TRUE, FALSE, NULL),
('es', 'Spain',          TRUE, FALSE, NULL),
('se', 'Sweden',         TRUE, FALSE, NULL),
('is', 'Iceland',        FALSE, TRUE,  NULL),
('li', 'Liechtenstein',  FALSE, TRUE,  NULL),
('no', 'Norway',         FALSE, TRUE,  NULL);

ALTER TABLE country_codes ENABLE ROW LEVEL SECURITY;

-- ===========================================================================
-- normalise_scope() helper function
-- ===========================================================================

CREATE OR REPLACE FUNCTION normalise_scope(raw TEXT)
RETURNS TEXT
LANGUAGE SQL IMMUTABLE AS $$
    SELECT CASE
        WHEN raw IS NULL THEN NULL
        WHEN lower(trim(raw)) = 'total' THEN 'total'
        WHEN lower(trim(raw)) = 'eu'    THEN 'total'
        WHEN lower(trim(raw)) = 'gr'    THEN 'el'
        ELSE lower(trim(raw))
    END;
$$;

COMMENT ON FUNCTION normalise_scope(TEXT) IS
    'Normalises raw scope strings as they appear in provider filings to canonical '
    'lowercase codes that join cleanly to country_codes. Three normalisations: '
    'whitespace trimmed, GR (ISO) mapped to EL (EU convention), both "total" and '
    '"EU" mapped to "total". NULL in → NULL out. Used by every view that exposes '
    'a country or total scope.';

-- ===========================================================================
-- View: amar_by_country
-- ===========================================================================

DROP VIEW IF EXISTS amar_by_country CASCADE;

CREATE VIEW amar_by_country AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    f.period_label                  AS period_label,
    normalise_scope(i.scope)        AS country_code,
    cc.name                         AS country_name,
    cc.is_eu_member                 AS is_eu_member,
    i.value                         AS amar_raw,
    i.value_numeric                 AS amar
FROM indicators i
JOIN filings   f  ON f.id = i.filing_id
JOIN providers p  ON p.id = f.provider_id
LEFT JOIN country_codes cc ON cc.code = normalise_scope(i.scope)
WHERE i.source_file = '10_A423_AMAR.csv'
  AND normalise_scope(i.scope) IS DISTINCT FROM 'total';

COMMENT ON VIEW amar_by_country IS
    'Article 42(3) DSA (also Article 24(2)): average monthly active recipients '
    'per Member State, per provider per filing. Source: Annex II file 10. '
    'EU total is excluded here — see provider_overview for that. LEFT JOIN to '
    'country_codes means rows with unrecognised country codes still appear, '
    'with country_name NULL; that''s a data-quality signal not a silent drop.';

-- ===========================================================================
-- View: provider_overview
-- ===========================================================================

DROP VIEW IF EXISTS provider_overview CASCADE;

CREATE VIEW provider_overview AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    p.legal_entity                  AS legal_entity,
    p.service_category              AS service_category,
    p.designated_on                 AS designated_on,
    p.country_of_establishment      AS country_of_establishment,
    f.id                            AS filing_id,
    f.slug                          AS filing_slug,
    f.period_label                  AS period_label,
    f.original_published_on         AS original_published_on,
    f.this_version_published_on     AS this_version_published_on,
    f.version_number                AS version_number,
    amar_total.value                AS amar_eu_total_raw,
    amar_total.value_numeric        AS amar_eu_total
FROM providers p
JOIN filings f ON f.provider_id = p.id
LEFT JOIN indicators amar_total
       ON amar_total.filing_id = f.id
      AND amar_total.source_file = '10_A423_AMAR.csv'
      AND normalise_scope(amar_total.scope) = 'total';

COMMENT ON VIEW provider_overview IS
    'One row per (provider × filing). The API homepage view. Includes provider '
    'metadata, filing provenance (period covered, original publication date, '
    'this-version publication date, version_number — so restatements are '
    'visible as later this_version dates against the same original date), '
    'and the single headline statistic: EU total AMAR per '
    'Article 42(3)/24(2) DSA.';
