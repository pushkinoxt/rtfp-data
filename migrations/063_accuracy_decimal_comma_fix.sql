-- Migration 063: Fix decimal-comma parsing in automated_means_accuracy.
--
-- The verify on 062 surfaced impossible values (max accuracy of 996, 999, 963, ...).
-- Cause: several providers report these fractions the European way, with a decimal
-- comma ("0,996"). The indicators.value_numeric generated column treats a comma as a
-- thousands separator -- correct for count fields, where "1,234,567" means 1234567 --
-- so it strips the comma and reads "0,996" as 996. The dot-convention providers
-- (Amazon, Facebook, Instagram, X) parsed correctly; the comma ones were inflated
-- ~1000x.
--
-- value_numeric is right to leave untouched (it is correct for counts). The fix is
-- local to this view: re-derive value from the raw text, treating a comma as a decimal
-- point, which is always correct for an accuracy figure (these never carry a thousands
-- separator). Same columns as 062, so CREATE OR REPLACE is sufficient.

CREATE OR REPLACE VIEW automated_means_accuracy AS
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
    -- Re-parse from raw text: comma -> dot, strip anything that is not a digit or dot,
    -- and only cast when the result is a single clean number (guards against errors).
    CASE
        WHEN regexp_replace(replace(i.value, ',', '.'), '[^0-9.]', '', 'g') ~ '^[0-9]*\.?[0-9]+$'
        THEN regexp_replace(replace(i.value, ',', '.'), '[^0-9.]', '', 'g')::numeric
    END             AS value,
    i.context       AS context
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
    'the reported fraction 0-1, re-parsed from raw text to handle decimal-comma '
    'reporting. context is verbatim (tool name, methodology note, or null). NOT '
    'comparable across providers; must not be ranked.';

NOTIFY pgrst, 'reload schema';

-- Verify: every min/max should now sit within [0, 1].
--   SELECT provider_slug,
--          count(*) AS figures,
--          round(min(value)::numeric, 3) AS min_v,
--          round(max(value)::numeric, 3) AS max_v
--   FROM automated_means_accuracy
--   GROUP BY 1 ORDER BY 1;
