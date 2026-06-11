-- Migration 045: Google Play banded AMAR backfill from report 24.
--
-- Same pattern as Google Shopping (039) and YouTube (042): Google Play's AMAR CSV
-- only pointed at Google's MAR report (report 24). This replaces the per-country pointer
-- rows on the MAIN Google Play filing with the real figures, both measures
-- (signed-in accounts, signed-out sessions), flagged value_is_estimate = TRUE (report-24
-- rounded-to-100,000 methodology). Clean numbers parse via value_numeric and display as
-- counts through amar_by_country (041); any "< X" qualifier is kept verbatim. The TOTAL
-- pointer row is left as-is. Targets the main filing (slug 'google-play/2025-h2'), never the
-- ads filing. Idempotent.

DELETE FROM indicators
WHERE filing_id = (SELECT id FROM filings WHERE slug = 'google-play/2025-h2')
  AND source_file = '10_A423_AMAR.csv'
  AND normalise_scope(scope) IS DISTINCT FROM 'total';

INSERT INTO indicators (section, indicator, scope, value, context, filing_id, source_file, value_is_estimate)
SELECT
    'AMAR',
    'Number of average monthly active recipients during the reporting period (' || v.measure || ')',
    v.scope,
    v.value,
    'From Google DSA MAR report 24 (H2 2025); figures rounded to the nearest 100,000.',
    f.id,
    '10_A423_AMAR.csv',
    TRUE
FROM (VALUES
  ('AT','signed-in accounts','5,100,000'),
  ('AT','signed-out sessions','700,000'),
  ('BE','signed-in accounts','6,600,000'),
  ('BE','signed-out sessions','900,000'),
  ('BG','signed-in accounts','5,300,000'),
  ('BG','signed-out sessions','600,000'),
  ('HR','signed-in accounts','2,800,000'),
  ('HR','signed-out sessions','300,000'),
  ('CY','signed-in accounts','1,000,000'),
  ('CY','signed-out sessions','200,000'),
  ('CZ','signed-in accounts','7,600,000'),
  ('CZ','signed-out sessions','700,000'),
  ('DK','signed-in accounts','2,400,000'),
  ('DK','signed-out sessions','400,000'),
  ('EE','signed-in accounts','800,000'),
  ('EE','signed-out sessions','200,000'),
  ('FI','signed-in accounts','3,900,000'),
  ('FI','signed-out sessions','500,000'),
  ('FR','signed-in accounts','46,500,000'),
  ('FR','signed-out sessions','6,400,000'),
  ('DE','signed-in accounts','55,400,000'),
  ('DE','signed-out sessions','9,100,000'),
  ('EL','signed-in accounts','6,600,000'),
  ('EL','signed-out sessions','700,000'),
  ('HU','signed-in accounts','5,600,000'),
  ('HU','signed-out sessions','600,000'),
  ('IE','signed-in accounts','3,000,000'),
  ('IE','signed-out sessions','4,100,000'),
  ('IT','signed-in accounts','38,500,000'),
  ('IT','signed-out sessions','4,100,000'),
  ('LV','signed-in accounts','1,200,000'),
  ('LV','signed-out sessions','200,000'),
  ('LT','signed-in accounts','1,900,000'),
  ('LT','signed-out sessions','300,000'),
  ('LU','signed-in accounts','300,000'),
  ('LU','signed-out sessions','100,000'),
  ('MT','signed-in accounts','400,000'),
  ('MT','signed-out sessions','< 100,000'),
  ('NL','signed-in accounts','14,100,000'),
  ('NL','signed-out sessions','3,800,000'),
  ('PL','signed-in accounts','25,300,000'),
  ('PL','signed-out sessions','2,400,000'),
  ('PT','signed-in accounts','7,300,000'),
  ('PT','signed-out sessions','1,200,000'),
  ('RO','signed-in accounts','11,400,000'),
  ('RO','signed-out sessions','1,700,000'),
  ('SK','signed-in accounts','3,100,000'),
  ('SK','signed-out sessions','300,000'),
  ('SI','signed-in accounts','1,300,000'),
  ('SI','signed-out sessions','200,000'),
  ('ES','signed-in accounts','35,300,000'),
  ('ES','signed-out sessions','5,800,000'),
  ('SE','signed-in accounts','5,000,000'),
  ('SE','signed-out sessions','2,900,000')
) AS v(scope, measure, value)
CROSS JOIN (SELECT id FROM filings WHERE slug = 'google-play/2025-h2') AS f;

NOTIFY pgrst, 'reload schema';
