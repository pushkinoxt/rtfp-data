-- Migration 040: Booking AMAR units/methodology, and surface AMAR notes.
--
-- Booking publishes AMAR as ranges, stating they are estimates "rounded to the
-- nearest one hundred thousand". Booking does not label the unit, but the figures
-- are in MILLIONS: the ">45" total is exactly the DSA's 45-million VLOP threshold,
-- and the per-country values only sum past 45 million if read as millions (in any
-- smaller unit the total could not exceed 45M). One decimal place of a million is
-- 100,000, which is also why "rounded to the nearest 100,000" is consistent. Beside
-- Google's absolute counts (e.g. "1,100,000") this is easy to misread, so this
-- migration (1) records Booking's own methodology plus this unit reading on its AMAR
-- rows' context, and (2) adds a `note` column to amar_by_country surfacing it (and
-- Google's MAR-report provenance from 039). Values are left verbatim. Idempotent.

UPDATE indicators
SET context = 'Booking reports these as estimates: a range based on a margin applied to '
              || 'the best available data, rounded to the nearest 100,000, subject to '
              || 'statistical uncertainty and possible later revision, and counting users '
              || 'to whom information was displayed even without a transaction. Figures '
              || 'appear to be in millions: the ">45" total matches the 45,000,000 VLOP '
              || 'threshold, so e.g. "16.4 - 20" reads as 16,400,000 to 20,000,000.'
WHERE filing_id = (SELECT id FROM filings WHERE slug = 'booking/2025-h2')
  AND source_file = '10_A423_AMAR.csv';

CREATE OR REPLACE VIEW amar_by_country AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    f.period_label                  AS period_label,
    normalise_scope(i.scope)        AS country_code,
    cc.name                         AS country_name,
    cc.is_eu_member                 AS is_eu_member,
    i.value                         AS amar_raw,
    i.value_numeric                 AS amar,
    CASE
        WHEN i.indicator ILIKE '%signed-in%'  THEN 'signed-in accounts'
        WHEN i.indicator ILIKE '%signed-out%' THEN 'signed-out sessions'
        ELSE 'all recipients'
    END                             AS measure,
    i.value_is_estimate             AS is_estimate,
    i.context                       AS note
FROM indicators i
JOIN filings   f  ON f.id = i.filing_id
JOIN providers p  ON p.id = f.provider_id
LEFT JOIN country_codes cc ON cc.code = normalise_scope(i.scope)
WHERE i.source_file = '10_A423_AMAR.csv'
  AND normalise_scope(i.scope) IS DISTINCT FROM 'total';

NOTIFY pgrst, 'reload schema';
