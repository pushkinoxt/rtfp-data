-- Migration 042: YouTube banded AMAR backfill from report 24.
--
-- Like Google Shopping, YouTube's AMAR CSV only pointed at Google's separate MAR
-- report (report 24). This replaces the per-country pointer rows on the MAIN YouTube
-- filing with the real figures, both measures (signed-in accounts, signed-out
-- sessions). Unlike Google Shopping, YouTube's are single numbers with no "< X"
-- qualifiers, but they come from the same report-24 rounded-to-100,000 methodology,
-- so they're flagged value_is_estimate = TRUE for consistency. value_numeric parses
-- them and amar_by_country (041) formats them as counts. The TOTAL pointer row is
-- left as-is (Google publishes no single EU total). Targets the main filing
-- (slug 'youtube/2025-h2'), never the ads filing. Idempotent.

DELETE FROM indicators
WHERE filing_id = (SELECT id FROM filings WHERE slug = 'youtube/2025-h2')
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
  ('AT','signed-in accounts','10,200,000'),
  ('AT','signed-out sessions','27,300,000'),
  ('BE','signed-in accounts','11,900,000'),
  ('BE','signed-out sessions','29,300,000'),
  ('BG','signed-in accounts','9,500,000'),
  ('BG','signed-out sessions','14,400,000'),
  ('HR','signed-in accounts','4,900,000'),
  ('HR','signed-out sessions','11,400,000'),
  ('CY','signed-in accounts','2,200,000'),
  ('CY','signed-out sessions','4,300,000'),
  ('CZ','signed-in accounts','18,400,000'),
  ('CZ','signed-out sessions','29,800,000'),
  ('DK','signed-in accounts','8,000,000'),
  ('DK','signed-out sessions','17,400,000'),
  ('EE','signed-in accounts','1,700,000'),
  ('EE','signed-out sessions','3,600,000'),
  ('FI','signed-in accounts','6,500,000'),
  ('FI','signed-out sessions','17,100,000'),
  ('FR','signed-in accounts','84,100,000'),
  ('FR','signed-out sessions','190,700,000'),
  ('DE','signed-in accounts','103,700,000'),
  ('DE','signed-out sessions','258,700,000'),
  ('EL','signed-in accounts','10,800,000'),
  ('EL','signed-out sessions','26,000,000'),
  ('HU','signed-in accounts','8,500,000'),
  ('HU','signed-out sessions','23,000,000'),
  ('IE','signed-in accounts','6,100,000'),
  ('IE','signed-out sessions','18,900,000'),
  ('IT','signed-in accounts','55,600,000'),
  ('IT','signed-out sessions','135,500,000'),
  ('LV','signed-in accounts','2,700,000'),
  ('LV','signed-out sessions','6,000,000'),
  ('LT','signed-in accounts','3,400,000'),
  ('LT','signed-out sessions','6,400,000'),
  ('LU','signed-in accounts','1,100,000'),
  ('LU','signed-out sessions','2,400,000'),
  ('MT','signed-in accounts','800,000'),
  ('MT','signed-out sessions','1,600,000'),
  ('NL','signed-in accounts','47,000,000'),
  ('NL','signed-out sessions','76,700,000'),
  ('PL','signed-in accounts','40,300,000'),
  ('PL','signed-out sessions','88,900,000'),
  ('PT','signed-in accounts','11,300,000'),
  ('PT','signed-out sessions','24,900,000'),
  ('RO','signed-in accounts','17,500,000'),
  ('RO','signed-out sessions','37,600,000'),
  ('SK','signed-in accounts','4,500,000'),
  ('SK','signed-out sessions','11,300,000'),
  ('SI','signed-in accounts','2,000,000'),
  ('SI','signed-out sessions','4,700,000'),
  ('ES','signed-in accounts','54,300,000'),
  ('ES','signed-out sessions','148,100,000'),
  ('SE','signed-in accounts','11,800,000'),
  ('SE','signed-out sessions','30,100,000')
) AS v(scope, measure, value)
CROSS JOIN (SELECT id FROM filings WHERE slug = 'youtube/2025-h2') AS f;

NOTIFY pgrst, 'reload schema';
