-- Migration 059: View -- per-tool automated detection accuracy (file 08).
--
-- The adult-content providers XVideos and XNXX report the accuracy, precision and
-- recall of each automated detection tool they run (GoogleSafety, Hive, and others),
-- split by images vs videos, broken down per EU language plus two aggregate scopes
-- ("Total number" and "Own-initiative"). These rows live in file 08 with the tool
-- named in the Contextual Information (context) column and the value a fraction
-- between 0 and 1. Migration 054 widened the indicators key so the per-tool rows
-- coexist; this view surfaces the data that was recovered. No mainstream provider
-- files this per-tool structure, so the view returns nothing for them.
--
-- One row per (provider, detection tool, metric, scope). Long format so the API and
-- the site can pivot as needed. value is the reported fraction (0-1).

DROP VIEW IF EXISTS automated_detection_accuracy CASCADE;

CREATE VIEW automated_detection_accuracy AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    f.period_label                  AS period_label,
    i.context                       AS detection_tool,   -- e.g. "Hive (videos)"
    CASE
        WHEN i.indicator ILIKE '%precision%' THEN 'Precision'
        WHEN i.indicator ILIKE '%recall%'    THEN 'Recall'
        WHEN i.indicator ILIKE '%accuracy%'  THEN 'Accuracy'
        ELSE i.indicator
    END                             AS metric,
    i.scope                         AS scope,            -- language code, "Total number", "Own-initiative"
    i.value_numeric                 AS value             -- reported fraction, 0-1
FROM indicators i
JOIN primary_current_filings f ON f.id = i.filing_id
JOIN providers p               ON p.id = f.provider_id
WHERE i.source_file = '08_A151BCE_422C_Auto.csv'
  AND i.context IS NOT NULL
  AND (i.indicator ILIKE '%accuracy%'
    OR i.indicator ILIKE '%precision%'
    OR i.indicator ILIKE '%recall%');

COMMENT ON VIEW automated_detection_accuracy IS
    'Article 15(1)(e)/42(2)(c): per-tool accuracy, precision and recall of each '
    'automated detection tool, for providers that report it (currently XVideos and '
    'XNXX). One row per (provider, tool, metric, scope); value is the reported '
    'fraction 0-1. detection_tool carries the tool name and media type verbatim.';

GRANT SELECT ON automated_detection_accuracy TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: should return rows for xvideos and xnxx only, three metrics per tool.
--   SELECT provider_slug, detection_tool, metric, count(*)
--   FROM automated_detection_accuracy
--   GROUP BY 1,2,3 ORDER BY 1,2,3;
