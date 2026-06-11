-- Migration 046: Google Maps banded AMAR backfill from report 24.
--
-- Same pattern as Google Shopping (039) and YouTube (042): Google Maps's AMAR CSV
-- only pointed at Google's MAR report (report 24). This replaces the per-country pointer
-- rows on the MAIN Google Maps filing with the real figures, both measures
-- (signed-in accounts, signed-out sessions), flagged value_is_estimate = TRUE (report-24
-- rounded-to-100,000 methodology). Clean numbers parse via value_numeric and display as
-- counts through amar_by_country (041); any "< X" qualifier is kept verbatim. The TOTAL
-- pointer row is left as-is. Targets the main filing (slug 'google-maps/2025-h2'), never the
-- ads filing. Idempotent.

DELETE FROM indicators
WHERE filing_id = (SELECT id FROM filings WHERE slug = 'google-maps/2025-h2')
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
  ('AT','signed-in accounts','8,400,000'),
  ('AT','signed-out sessions','6,200,000'),
  ('BE','signed-in accounts','9,800,000'),
  ('BE','signed-out sessions','6,200,000'),
  ('BG','signed-in accounts','4,200,000'),
  ('BG','signed-out sessions','1,800,000'),
  ('HR','signed-in accounts','3,900,000'),
  ('HR','signed-out sessions','1,700,000'),
  ('CY','signed-in accounts','1,300,000'),
  ('CY','signed-out sessions','600,000'),
  ('CZ','signed-in accounts','6,900,000'),
  ('CZ','signed-out sessions','3,600,000'),
  ('DK','signed-in accounts','4,800,000'),
  ('DK','signed-out sessions','3,600,000'),
  ('EE','signed-in accounts','1,000,000'),
  ('EE','signed-out sessions','600,000'),
  ('FI','signed-in accounts','3,900,000'),
  ('FI','signed-out sessions','2,800,000'),
  ('FR','signed-in accounts','50,600,000'),
  ('FR','signed-out sessions','33,700,000'),
  ('DE','signed-in accounts','60,300,000'),
  ('DE','signed-out sessions','58,500,000'),
  ('EL','signed-in accounts','8,100,000'),
  ('EL','signed-out sessions','3,900,000'),
  ('HU','signed-in accounts','6,300,000'),
  ('HU','signed-out sessions','3,100,000'),
  ('IE','signed-in accounts','4,300,000'),
  ('IE','signed-out sessions','2,800,000'),
  ('IT','signed-in accounts','42,200,000'),
  ('IT','signed-out sessions','22,000,000'),
  ('LV','signed-in accounts','1,200,000'),
  ('LV','signed-out sessions','600,000'),
  ('LT','signed-in accounts','2,000,000'),
  ('LT','signed-out sessions','1,000,000'),
  ('LU','signed-in accounts','900,000'),
  ('LU','signed-out sessions','600,000'),
  ('MT','signed-in accounts','700,000'),
  ('MT','signed-out sessions','300,000'),
  ('NL','signed-in accounts','18,900,000'),
  ('NL','signed-out sessions','13,800,000'),
  ('PL','signed-in accounts','25,700,000'),
  ('PL','signed-out sessions','15,600,000'),
  ('PT','signed-in accounts','8,400,000'),
  ('PT','signed-out sessions','3,800,000'),
  ('RO','signed-in accounts','8,700,000'),
  ('RO','signed-out sessions','3,100,000'),
  ('SK','signed-in accounts','3,200,000'),
  ('SK','signed-out sessions','1,700,000'),
  ('SI','signed-in accounts','2,000,000'),
  ('SI','signed-out sessions','900,000'),
  ('ES','signed-in accounts','39,000,000'),
  ('ES','signed-out sessions','20,200,000'),
  ('SE','signed-in accounts','7,100,000'),
  ('SE','signed-out sessions','5,400,000')
) AS v(scope, measure, value)
CROSS JOIN (SELECT id FROM filings WHERE slug = 'google-maps/2025-h2') AS f;

NOTIFY pgrst, 'reload schema';
