-- Migration 069: Surface percentage-formatted detection accuracy figures.
--
-- File 8 records automated-detection accuracy, precision and recall. The view
-- previously required value_numeric IS NOT NULL, which the generated column
-- cannot produce for percentage text ("86%", because of the % sign). So the
-- providers that filed these as percentages (Booking, AliExpress, Temu) had
-- their per-country figures dropped from the view and never shown.
--
-- This re-parses the figure to a 0-1 fraction handling both notations, and
-- filters on the parsed value rather than value_numeric. Backward-compatible:
-- decimal figures (dot or comma) parse exactly as before, so providers without
-- percentages are unaffected. A bare "1" still parses to 1.0; the only such
-- value, Snapchat's placeholder aggregate, was already nulled in migration 067.

CREATE OR REPLACE VIEW automated_means_accuracy AS
SELECT * FROM (
  SELECT
      p.slug          AS provider_slug,
      p.name          AS provider_name,
      f.period_label  AS period_label,
      CASE
          WHEN i.indicator ILIKE '%precision%' THEN 'Precision'
          WHEN i.indicator ILIKE '%recall%'    THEN 'Recall'
          WHEN i.indicator ILIKE '%accuracy%'  THEN 'Accuracy'
          ELSE i.indicator
      END             AS metric,
      i.scope         AS scope,
      -- Parse to a 0-1 fraction. Two notations appear in the filings:
      --   percentage text ("86%")        -> strip to digits, divide by 100
      --   decimal, dot or comma ("0,86") -> comma to dot, take as-is
      CASE
          WHEN i.value ~ '%'
               AND regexp_replace(i.value, '[^0-9.]', '', 'g') ~ '^[0-9]*\.?[0-9]+$'
          THEN regexp_replace(i.value, '[^0-9.]', '', 'g')::numeric / 100.0
          WHEN regexp_replace(replace(i.value, ',', '.'), '[^0-9.]', '', 'g') ~ '^[0-9]*\.?[0-9]+$'
          THEN regexp_replace(replace(i.value, ',', '.'), '[^0-9.]', '', 'g')::numeric
      END             AS value,
      i.context       AS context
  FROM indicators i
  JOIN primary_current_filings f ON f.id = i.filing_id
  JOIN providers p               ON p.id = f.provider_id
  WHERE i.source_file = '08_A151BCE_422C_Auto.csv'
    AND (i.indicator ILIKE '%accuracy%'
      OR i.indicator ILIKE '%precision%'
      OR i.indicator ILIKE '%recall%')
) t
WHERE t.value IS NOT NULL;

GRANT SELECT ON automated_means_accuracy TO anon, authenticated;
