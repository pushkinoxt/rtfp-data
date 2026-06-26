-- Migration 067: Correct Snapchat's automated-detection accuracy figures (file 08).
--
-- Two faults in the restated filing's accuracy block, both fixed here:
--
--   1. The aggregate "Own-initiative" and "Total number" rows for Accuracy,
--      Precision and Recall hold a placeholder "1", not a figure. It cannot be a
--      real aggregate: the per-country figures range 69%-92%, so an overall 100%
--      is impossible. As filed it renders as 100% on the platform page. We null
--      these six cells; the filing provides no meaningful aggregate here.
--
--   2. The real per-country figures are stored as percentage text ("86%"). The
--      generated value_numeric column cannot parse the % sign, so the
--      automated_means_accuracy view (which requires value_numeric IS NOT NULL)
--      drops every per-country row and they never appear. We normalise them to
--      the 0-1 fraction the view and page expect ("86%" -> "0.86"), matching the
--      convention every other provider uses.
--
-- Scoped to snapchat, file 08, the three accuracy indicators only. value_numeric
-- is a generated column, so it recomputes from the new value; re-runnable.

-- 1. Null the placeholder aggregate cells.
UPDATE indicators i
SET value = NULL
FROM filings f, providers p
WHERE i.filing_id = f.id
  AND p.id = f.provider_id
  AND p.slug = 'snapchat'
  AND i.source_file = '08_A151BCE_422C_Auto.csv'
  AND i.indicator ILIKE 'Accuracy of the automated means%'
  AND i.scope IN ('Own-initiative', 'Total number')
  AND trim(i.value) = '1';

-- 2. Normalise per-country percentage figures to 0-1 fractions.
--    Display is driven by value_numeric via the view, so the exact stored text
--    is immaterial; trim_scale keeps it tidy ("0.86", "1", not "0.8600").
UPDATE indicators i
SET value = trim_scale(
              regexp_replace(i.value, '[^0-9.]', '', 'g')::numeric / 100.0
            )::text
FROM filings f, providers p
WHERE i.filing_id = f.id
  AND p.id = f.provider_id
  AND p.slug = 'snapchat'
  AND i.source_file = '08_A151BCE_422C_Auto.csv'
  AND i.indicator ILIKE 'Accuracy of the automated means%'
  AND i.value ~ '%';

-- Verify: aggregate rows gone, per-country rows now 0-1 fractions.
--   SELECT scope, indicator, value, value_numeric
--   FROM indicators i JOIN filings f ON f.id = i.filing_id
--   JOIN providers p ON p.id = f.provider_id
--   WHERE p.slug = 'snapchat' AND i.source_file = '08_A151BCE_422C_Auto.csv'
--     AND i.indicator ILIKE 'Accuracy of the automated means%'
--   ORDER BY indicator, scope;
