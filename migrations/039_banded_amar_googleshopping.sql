-- Migration 039: Banded AMAR — surface estimates, flag Booking, backfill Google Shopping.
--
-- (1) amar_by_country gains two columns: `measure` (so a provider that splits AMAR
--     into signed-in accounts vs signed-out sessions, as Google does, is legible)
--     and `is_estimate` (TRUE when the figure is a band/threshold, not exact).
-- (2) Booking's AMAR is reported as ranges in millions ("2.2 - 2.7") and a ">45"
--     total; those rows are flagged as estimates.
-- (3) Google Shopping's CSV only pointed at the MAR report PDF. Its per-country
--     pointer rows are replaced with the real figures from report 24 (H2 2025),
--     both measures, stored exactly as published (bands kept verbatim) and flagged
--     as estimates so value_numeric is never read as precise.
-- Idempotent: re-running replaces the same rows and redefines the same view.

-- (1) View: expose the measure split and the estimate flag (appended columns).
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
    i.value_is_estimate             AS is_estimate
FROM indicators i
JOIN filings   f  ON f.id = i.filing_id
JOIN providers p  ON p.id = f.provider_id
LEFT JOIN country_codes cc ON cc.code = normalise_scope(i.scope)
WHERE i.source_file = '10_A423_AMAR.csv'
  AND normalise_scope(i.scope) IS DISTINCT FROM 'total';

-- (2) Flag Booking's banded AMAR (per-country ranges + the ">45" total) as estimates.
UPDATE indicators SET value_is_estimate = TRUE
WHERE filing_id = (SELECT id FROM filings WHERE slug = 'booking/2025-h2')
  AND source_file = '10_A423_AMAR.csv';

-- (3) Google Shopping: drop the per-country pointer rows (keep the TOTAL pointer),
--     then insert the real banded figures, both measures, flagged as estimates.
DELETE FROM indicators
WHERE filing_id = (SELECT id FROM filings WHERE slug = 'google-shopping/2025-h2')
  AND source_file = '10_A423_AMAR.csv'
  AND normalise_scope(scope) IS DISTINCT FROM 'total';

INSERT INTO indicators (section, indicator, scope, value, context, filing_id, source_file, value_is_estimate)
SELECT
    'AMAR',
    'Number of average monthly active recipients during the reporting period (' || v.measure || ')',
    v.scope,
    v.value,
    'From Google DSA MAR report 24 (H2 2025); figure banded as published.',
    f.id,
    '10_A423_AMAR.csv',
    TRUE
FROM (VALUES
  ('AT','signed-in accounts','100,000'),
  ('AT','signed-out sessions','< 100,000'),
  ('BE','signed-in accounts','100,000'),
  ('BE','signed-out sessions','< 100,000'),
  ('BG','signed-in accounts','< 10,000'),
  ('BG','signed-out sessions','< 10,000'),
  ('HR','signed-in accounts','< 10,000'),
  ('HR','signed-out sessions','< 10,000'),
  ('CY','signed-in accounts','< 10,000'),
  ('CY','signed-out sessions','< 10,000'),
  ('CZ','signed-in accounts','300,000'),
  ('CZ','signed-out sessions','< 100,000'),
  ('DK','signed-in accounts','100,000'),
  ('DK','signed-out sessions','< 100,000'),
  ('EE','signed-in accounts','< 10,000'),
  ('EE','signed-out sessions','< 10,000'),
  ('FI','signed-in accounts','100,000'),
  ('FI','signed-out sessions','< 100,000'),
  ('FR','signed-in accounts','900,000'),
  ('FR','signed-out sessions','300,000'),
  ('DE','signed-in accounts','1,100,000'),
  ('DE','signed-out sessions','500,000'),
  ('EL','signed-in accounts','100,000'),
  ('EL','signed-out sessions','< 100,000'),
  ('HU','signed-in accounts','200,000'),
  ('HU','signed-out sessions','< 100,000'),
  ('IE','signed-in accounts','100,000'),
  ('IE','signed-out sessions','100,000'),
  ('IT','signed-in accounts','900,000'),
  ('IT','signed-out sessions','200,000'),
  ('LV','signed-in accounts','< 10,000'),
  ('LV','signed-out sessions','< 10,000'),
  ('LT','signed-in accounts','< 10,000'),
  ('LT','signed-out sessions','< 10,000'),
  ('LU','signed-in accounts','< 10,000'),
  ('LU','signed-out sessions','< 10,000'),
  ('MT','signed-in accounts','< 10,000'),
  ('MT','signed-out sessions','< 10,000'),
  ('NL','signed-in accounts','300,000'),
  ('NL','signed-out sessions','200,000'),
  ('PL','signed-in accounts','1,000,000'),
  ('PL','signed-out sessions','200,000'),
  ('PT','signed-in accounts','100,000'),
  ('PT','signed-out sessions','< 100,000'),
  ('RO','signed-in accounts','300,000'),
  ('RO','signed-out sessions','< 100,000'),
  ('SK','signed-in accounts','100,000'),
  ('SK','signed-out sessions','< 100,000'),
  ('SI','signed-in accounts','< 10,000'),
  ('SI','signed-out sessions','< 10,000'),
  ('ES','signed-in accounts','700,000'),
  ('ES','signed-out sessions','100,000'),
  ('SE','signed-in accounts','100,000'),
  ('SE','signed-out sessions','200,000')
) AS v(scope, measure, value)
CROSS JOIN (SELECT id FROM filings WHERE slug = 'google-shopping/2025-h2') AS f;

NOTIFY pgrst, 'reload schema';
