-- Migration 062: Correct the automated-means accuracy view (supersedes 059).
--
-- Migration 059 assumed file 08's Contextual Information column always names a
-- detection tool, so it could serve as a per-tool dimension. Verification showed the
-- assumption is false: providers use that column two completely different ways. A few
-- name a tool (XVideos/XNXX "GoogleSafety (videos)"; Pornhub "Thorn's Safer ..."; Google
-- Shopping "...Automated Classification System"), but most use it for a free-text
-- methodology note ("Accuracy reflects the percentage ...", "Because all moderation is
-- done by humans ..."). Keying on "context is not null" therefore captured every
-- note-bearing row across nearly all providers and conflated real breakdowns with prose.
--
-- This replaces that view with an honest one: every REPORTED accuracy / precision /
-- recall figure (a real numeric value), one row per (provider, metric, scope), with
-- whatever the provider wrote in the context column shown verbatim -- tool name,
-- methodology note, or nothing. These figures are NOT comparable across providers
-- (different denominators, methods and scopes); the view exposes them, it does not rank.

DROP VIEW IF EXISTS automated_detection_accuracy CASCADE;  -- remove the 059 view
DROP VIEW IF EXISTS automated_means_accuracy CASCADE;

CREATE VIEW automated_means_accuracy AS
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
    i.scope         AS scope,      -- language code, "Total number", "Own-initiative", "NAM total"
    i.value_numeric AS value,      -- reported fraction, 0-1
    i.context       AS context     -- verbatim: tool name, methodology note, or null
FROM indicators i
JOIN primary_current_filings f ON f.id = i.filing_id
JOIN providers p               ON p.id = f.provider_id
WHERE i.source_file = '08_A151BCE_422C_Auto.csv'
  AND i.value_numeric IS NOT NULL
  AND (i.indicator ILIKE '%accuracy%'
    OR i.indicator ILIKE '%precision%'
    OR i.indicator ILIKE '%recall%');

COMMENT ON VIEW automated_means_accuracy IS
    'Article 15(1)(e)/42(2)(c): every reported accuracy, precision and recall figure '
    'for automated content moderation, one row per (provider, metric, scope). value is '
    'the reported fraction 0-1. context is verbatim and heterogeneous: some providers '
    'name a detection tool, others a methodology note. NOT comparable across providers; '
    'must not be ranked.';

GRANT SELECT ON automated_means_accuracy TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: per-provider figure counts and that values are real 0-1 fractions.
--   SELECT provider_slug,
--          count(*) AS figures,
--          round(min(value)::numeric, 3) AS min_v,
--          round(max(value)::numeric, 3) AS max_v
--   FROM automated_means_accuracy
--   GROUP BY 1 ORDER BY 1;
