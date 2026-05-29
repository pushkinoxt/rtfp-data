-- Migration 020: Article 42(2)(a) DSA human resources view, plus language lookup.
--
-- File 09's `scope` column mixes ISO-639-1 language codes (de, el, cs) with
-- ISO-3166 country codes used as language shorthands (DE, GR, CZ). The
-- normalise_language() function below collapses both conventions to canonical
-- lowercase ISO-639-1. Seven cases need explicit mapping because the country
-- and language codes differ; the rest just lowercase.

-- ===========================================================================
-- language_codes lookup table
-- ===========================================================================

DROP TABLE IF EXISTS language_codes CASCADE;

CREATE TABLE language_codes (
    code            TEXT PRIMARY KEY,    -- canonical ISO-639-1 lowercase
    name            TEXT NOT NULL,
    is_eu_official  BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE language_codes IS
    '24 official languages of the European Union per Article 55 TFEU, as the '
    'set Article 42(2)(a) DSA expects providers to disclose moderator language '
    'expertise against. Joined by canonical ISO-639-1 code; provider filings '
    'use a mix of ISO-639 and ISO-3166 conventions, normalise_language() '
    'collapses both.';

INSERT INTO language_codes (code, name) VALUES
('bg', 'Bulgarian'),
('hr', 'Croatian'),
('cs', 'Czech'),
('da', 'Danish'),
('nl', 'Dutch'),
('en', 'English'),
('et', 'Estonian'),
('fi', 'Finnish'),
('fr', 'French'),
('de', 'German'),
('el', 'Greek'),
('hu', 'Hungarian'),
('ga', 'Irish'),
('it', 'Italian'),
('lv', 'Latvian'),
('lt', 'Lithuanian'),
('mt', 'Maltese'),
('pl', 'Polish'),
('pt', 'Portuguese'),
('ro', 'Romanian'),
('sk', 'Slovak'),
('sl', 'Slovenian'),
('es', 'Spanish'),
('sv', 'Swedish');

ALTER TABLE language_codes ENABLE ROW LEVEL SECURITY;

-- ===========================================================================
-- normalise_language() helper function
-- ===========================================================================

CREATE OR REPLACE FUNCTION normalise_language(raw TEXT)
RETURNS TEXT
LANGUAGE SQL IMMUTABLE AS $$
    SELECT CASE
        WHEN raw IS NULL                              THEN NULL
        WHEN lower(trim(raw)) IN ('total','total number') THEN 'total'
        -- Seven cases where ISO-3166 country code differs from ISO-639-1 language code
        WHEN upper(trim(raw)) = 'GR' THEN 'el'  -- Greek (country GR, language EL)
        WHEN upper(trim(raw)) = 'DK' THEN 'da'  -- Danish (country DK, language DA)
        WHEN upper(trim(raw)) = 'SE' THEN 'sv'  -- Swedish (country SE, language SV)
        WHEN upper(trim(raw)) = 'CZ' THEN 'cs'  -- Czech (country CZ, language CS)
        WHEN upper(trim(raw)) = 'EE' THEN 'et'  -- Estonian (country EE, language ET)
        WHEN upper(trim(raw)) = 'SI' THEN 'sl'  -- Slovenian (country SI, language SL)
        WHEN upper(trim(raw)) = 'IE' THEN 'ga'  -- Irish (country IE, language GA — Ireland also has English EN but that has its own code)
        ELSE lower(trim(raw))
    END;
$$;

COMMENT ON FUNCTION normalise_language(TEXT) IS
    'Maps raw language/country strings in file 09 scope column to canonical '
    'ISO-639-1 lowercase. Two normalisations: case folding, and seven explicit '
    'country-to-language remappings where ISO-3166 differs from ISO-639-1. '
    'IE→ga assumes provider meant Irish (the country-name shortcut for the '
    'minority official language) rather than English (which has its own '
    'unambiguous code EN); a provider intending English would normally write EN.';

-- ===========================================================================
-- View: human_moderators_by_language
-- One row per (provider × language) plus an EU total per provider.
-- ===========================================================================

DROP VIEW IF EXISTS human_moderators_by_language CASCADE;

CREATE VIEW human_moderators_by_language AS
SELECT
    p.slug                                                AS provider_slug,
    p.name                                                AS provider_name,
    f.period_label                                        AS period_label,
    normalise_language(i.scope)                           AS language_code,
    lc.name                                               AS language_name,
    lc.is_eu_official                                     AS is_eu_official,
    i.value_numeric                                       AS moderators
FROM indicators i
JOIN filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
LEFT JOIN language_codes lc ON lc.code = normalise_language(i.scope)
WHERE i.source_file = '09_A422AB_Human.csv'
  AND i.indicator   = 'Number of total moderators with sufficient linguistic expertise';

COMMENT ON VIEW human_moderators_by_language IS
    'Article 42(2)(a) DSA: human resources dedicated to content moderation, '
    'broken down by each applicable official language of the Member States. '
    'One row per (provider × language), plus a language_code="total" row per '
    'provider giving the headcount across all languages. LEFT JOIN to '
    'language_codes means unrecognised codes still appear (with language_name '
    'NULL) — a data-quality signal rather than a silent drop.';
