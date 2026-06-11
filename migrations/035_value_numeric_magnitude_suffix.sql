-- Migration 035: teach value_numeric to parse magnitude suffixes (k / M / B)
--
-- Some providers report figures in shorthand, e.g. Temu's AMAR as "129.7M"
-- rather than "129700000". value_numeric is a generated column and did not
-- recognise the suffix, producing NULL for every such value (Temu's AMAR
-- total and all its per-country rows).
--
-- value_numeric is a generated column, so it cannot be altered in place: it
-- must be dropped and recreated. DROP ... CASCADE also drops the six views
-- that depend on it, so this migration recreates all six afterwards, from
-- their live definitions captured immediately before the drop. None of the
-- six reference each other, so recreation order is immaterial.
--
-- Everything is wrapped in a single transaction: if any step fails, the whole
-- migration rolls back and nothing is left half-applied.

BEGIN;

-- 1. Drop the generated column and (via CASCADE) its six dependent views.
ALTER TABLE indicators DROP COLUMN value_numeric CASCADE;

-- 2. Recreate value_numeric with magnitude-suffix support. All previously
--    handled formats (US commas, European dots, plain numbers) are preserved;
--    the new case sits just before the final ELSE and catches only values
--    that would otherwise fall through to NULL.
ALTER TABLE indicators
  ADD COLUMN value_numeric numeric
  GENERATED ALWAYS AS (
    CASE
      WHEN (value IS NULL) THEN NULL::numeric

      -- US-style thousands separators: "129,700,000"
      WHEN (value ~~ '%,%'::text) THEN
        CASE
          WHEN (regexp_replace(value, '[,\s]'::text, ''::text, 'g'::text) ~ '^-?\d+(\.\d+)?$'::text)
            THEN (regexp_replace(value, '[,\s]'::text, ''::text, 'g'::text))::numeric
          ELSE NULL::numeric
        END

      -- European thousands separators (multiple dots): "129.700.000"
      WHEN (value ~ '\..+\.'::text) THEN
        CASE
          WHEN (regexp_replace(value, '[.\s]'::text, ''::text, 'g'::text) ~ '^-?\d+$'::text)
            THEN (regexp_replace(value, '[.\s]'::text, ''::text, 'g'::text))::numeric
          ELSE NULL::numeric
        END

      -- European thousands separator (single dot, exactly 3 trailing): "129.700"
      WHEN (value ~ '^-?\d+\.\d{3}$'::text)
        THEN (regexp_replace(value, '[.\s]'::text, ''::text, 'g'::text))::numeric

      -- Plain number (optional single decimal): "129700000" or "129.7"
      WHEN (regexp_replace(value, '\s'::text, ''::text, 'g'::text) ~ '^-?\d+(\.\d+)?$'::text)
        THEN (regexp_replace(value, '\s'::text, ''::text, 'g'::text))::numeric

      -- Magnitude suffix: "129.7M", "2.3M", "850k", "1.4B", "1.4bn".
      -- Strip the suffix, cast the numeric part, multiply by the factor.
      WHEN (regexp_replace(value, '\s'::text, ''::text, 'g'::text) ~* '^-?\d+(\.\d+)?(k|m|b|bn)$'::text) THEN
        (regexp_replace(regexp_replace(value, '\s'::text, ''::text, 'g'::text), '(?i)(k|m|b|bn)$'::text, ''::text))::numeric
        *
        CASE
          WHEN (regexp_replace(value, '\s'::text, ''::text, 'g'::text) ~* 'bn$'::text) THEN 1000000000::numeric
          WHEN (regexp_replace(value, '\s'::text, ''::text, 'g'::text) ~* 'b$'::text)  THEN 1000000000::numeric
          WHEN (regexp_replace(value, '\s'::text, ''::text, 'g'::text) ~* 'm$'::text)  THEN 1000000::numeric
          WHEN (regexp_replace(value, '\s'::text, ''::text, 'g'::text) ~* 'k$'::text)  THEN 1000::numeric
          ELSE 1::numeric
        END

      ELSE NULL::numeric
    END
  ) STORED;

-- 3. Recreate the six dependent views, exactly as captured from the live DB.

CREATE OR REPLACE VIEW amar_by_country AS
  SELECT p.slug AS provider_slug,
    p.name AS provider_name,
    f.period_label,
    normalise_scope(i.scope) AS country_code,
    cc.name AS country_name,
    cc.is_eu_member,
    i.value AS amar_raw,
    i.value_numeric AS amar
   FROM (((indicators i
     JOIN filings f ON ((f.id = i.filing_id)))
     JOIN providers p ON ((p.id = f.provider_id)))
     LEFT JOIN country_codes cc ON ((cc.code = normalise_scope(i.scope))))
  WHERE ((i.source_file = '10_A423_AMAR.csv'::text) AND (normalise_scope(i.scope) IS DISTINCT FROM 'total'::text));

CREATE OR REPLACE VIEW human_moderators_by_language AS
  SELECT p.slug AS provider_slug,
    p.name AS provider_name,
    f.period_label,
    normalise_language(i.scope) AS language_code,
    lc.name AS language_name,
    lc.is_eu_official,
    i.value_numeric AS moderators
   FROM (((indicators i
     JOIN filings f ON ((f.id = i.filing_id)))
     JOIN providers p ON ((p.id = f.provider_id)))
     LEFT JOIN language_codes lc ON ((lc.code = normalise_language(i.scope))))
  WHERE ((i.source_file = '09_A422AB_Human.csv'::text) AND (i.indicator = 'Number of total moderators with sufficient linguistic expertise'::text));

CREATE OR REPLACE VIEW internal_complaints_summary AS
  SELECT p.slug AS provider_slug,
    p.name AS provider_name,
    f.period_label,
    i.indicator AS complaint_subject,
    max(CASE WHEN (i.scope = 'Total number'::text) THEN i.value_numeric ELSE NULL::numeric END) AS total_complaints,
    max(CASE WHEN (i.scope = 'Decisions upheld'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_upheld,
    max(CASE WHEN (i.scope = 'Decisions reversed'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_reversed,
    max(CASE WHEN (i.scope = 'Decisions partially reversed'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_partially_reversed,
    max(CASE WHEN (i.scope = 'Decision omitted'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_omitted,
    max(CASE WHEN (i.scope = 'Median time'::text) THEN i.value_numeric ELSE NULL::numeric END) AS median_time
   FROM ((indicators i
     JOIN filings f ON ((f.id = i.filing_id)))
     JOIN providers p ON ((p.id = f.provider_id)))
  WHERE ((i.source_file = '07_Appeals.csv'::text) AND (i.section = 'Internal complaints mechanism'::text))
  GROUP BY p.slug, p.name, f.period_label, i.indicator;

CREATE OR REPLACE VIEW misuse_suspensions AS
  SELECT p.slug AS provider_slug,
    p.name AS provider_name,
    f.period_label,
    max(CASE WHEN (i.indicator = 'Number of suspensions enacted for the provision of manifestly illegal content'::text) THEN i.value_numeric ELSE NULL::numeric END) AS suspensions_for_illegal_content,
    max(CASE WHEN (i.indicator = 'Number of suspensions enacted for the provision of manifestly unfounded notices'::text) THEN i.value_numeric ELSE NULL::numeric END) AS suspensions_for_unfounded_notices,
    max(CASE WHEN (i.indicator = 'Number of suspensions enacted for the provision of manifestly unfounded complaints'::text) THEN i.value_numeric ELSE NULL::numeric END) AS suspensions_for_unfounded_complaints
   FROM ((indicators i
     JOIN filings f ON ((f.id = i.filing_id)))
     JOIN providers p ON ((p.id = f.provider_id)))
  WHERE ((i.source_file = '07_Appeals.csv'::text) AND (i.section = 'Suspensions imposed on repeated offenders'::text))
  GROUP BY p.slug, p.name, f.period_label;

CREATE OR REPLACE VIEW out_of_court_disputes AS
  SELECT p.slug AS provider_slug,
    p.name AS provider_name,
    f.period_label,
    max(CASE WHEN (i.scope = 'Total number'::text) THEN i.value_numeric ELSE NULL::numeric END) AS disputes_submitted,
    max(CASE WHEN (i.scope = 'Decisions upheld'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_upheld,
    max(CASE WHEN (i.scope = 'Decisions reversed'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_reversed,
    max(CASE WHEN (i.scope = 'Decisions partially reversed'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_partially_reversed,
    max(CASE WHEN (i.scope = 'Decision omitted'::text) THEN i.value_numeric ELSE NULL::numeric END) AS decisions_omitted,
    max(CASE WHEN (i.scope = 'Median time'::text) THEN i.value_numeric ELSE NULL::numeric END) AS median_completion_time,
    max(CASE WHEN (i.scope = 'Percentage of outcomes implemented'::text) THEN i.value_numeric ELSE NULL::numeric END) AS share_provider_implemented_pct
   FROM ((indicators i
     JOIN filings f ON ((f.id = i.filing_id)))
     JOIN providers p ON ((p.id = f.provider_id)))
  WHERE ((i.source_file = '07_Appeals.csv'::text) AND (i.section = 'Out-of-court dispute settlement bodies'::text))
  GROUP BY p.slug, p.name, f.period_label;

CREATE OR REPLACE VIEW provider_overview AS
  SELECT p.slug AS provider_slug,
    p.name AS provider_name,
    p.legal_entity,
    p.service_category,
    p.designated_on,
    p.country_of_establishment,
    f.id AS filing_id,
    f.slug AS filing_slug,
    f.period_label,
    f.original_published_on,
    f.this_version_published_on,
    f.version_number,
    amar_total.value AS amar_eu_total_raw,
    amar_total.value_numeric AS amar_eu_total
   FROM ((providers p
     JOIN filings f ON ((f.provider_id = p.id)))
     LEFT JOIN indicators amar_total ON (((amar_total.filing_id = f.id) AND (amar_total.source_file = '10_A423_AMAR.csv'::text) AND (normalise_scope(amar_total.scope) = 'total'::text))));

COMMIT;
