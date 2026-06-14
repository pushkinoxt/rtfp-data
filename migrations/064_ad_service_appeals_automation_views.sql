-- Migration 064: Surface advertising-service file 7 (appeals) and file 8 (automated
-- means) data. Companions to ad_services (060), which covers file 6. The data was
-- already loaded into the /ads filings; these views make it queryable. The main
-- analytical views deliberately exclude /ads filings, so without these the ads
-- appeals and ads automation data are invisible except via the raw API.
--
-- ad_service_appeals is also the ONLY place Google Shopping's ad data appears: its
-- sole ad sidecar is file 7 (no file 6), so it never shows in ad_services.

-- ---------------------------------------------------------------------------------
-- File 7: appeals / recidivism for advertising services.
-- File 7 holds only counts, so value_numeric (comma = thousands) is correct here.
-- ---------------------------------------------------------------------------------
DROP VIEW IF EXISTS ad_service_appeals CASCADE;

CREATE VIEW ad_service_appeals AS
SELECT
    p.slug          AS provider_slug,
    p.name          AS provider_name,
    f.service_name  AS service_name,
    f.slug          AS filing_slug,
    f.period_label  AS period_label,
    i.section       AS section,
    i.indicator     AS indicator,
    i.scope         AS scope,
    i.value_numeric AS value,
    i.context       AS context
FROM indicators i
JOIN filings f   ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE f.slug LIKE '%/ads'
  AND i.source_file = '07_Appeals.csv'
  AND i.value_numeric IS NOT NULL;

COMMENT ON VIEW ad_service_appeals IS
    'Appeals and recidivism data (internal complaints, out-of-court disputes, '
    'repeat-infringer suspensions) for advertising services, one row per reported '
    'figure. Companion to ad_services (file 6). This is the only place Google '
    'Shopping''s ad data appears, since its sole ad sidecar is file 7.';

GRANT SELECT ON ad_service_appeals TO anon, authenticated;

-- ---------------------------------------------------------------------------------
-- File 8: automated means for advertising services.
-- Mixed rows: volume counts (value_numeric correct) and accuracy/precision/recall
-- fractions (decimal-comma reporting, re-parsed exactly as in migration 063).
-- ---------------------------------------------------------------------------------
DROP VIEW IF EXISTS ad_service_automation CASCADE;

CREATE VIEW ad_service_automation AS
SELECT
    p.slug          AS provider_slug,
    p.name          AS provider_name,
    f.service_name  AS service_name,
    f.slug          AS filing_slug,
    f.period_label  AS period_label,
    i.section       AS section,
    i.indicator     AS indicator,
    i.scope         AS scope,
    CASE
        WHEN i.indicator ILIKE '%accuracy%'
          OR i.indicator ILIKE '%precision%'
          OR i.indicator ILIKE '%recall%'
        THEN CASE
                WHEN regexp_replace(replace(i.value, ',', '.'), '[^0-9.]', '', 'g') ~ '^[0-9]*\.?[0-9]+$'
                THEN regexp_replace(replace(i.value, ',', '.'), '[^0-9.]', '', 'g')::numeric
             END
        ELSE i.value_numeric
    END             AS value,
    i.context       AS context
FROM indicators i
JOIN filings f   ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE f.slug LIKE '%/ads'
  AND i.source_file = '08_A151BCE_422C_Auto.csv'
  AND i.value_numeric IS NOT NULL;

COMMENT ON VIEW ad_service_automation IS
    'Automated-means data (volume counts and per-tool/per-language accuracy, '
    'precision and recall) for advertising services. Accuracy fractions are '
    're-parsed to handle decimal-comma reporting (see migration 063); count rows use '
    'value_numeric. Kept separate from the main automation and accuracy views, which '
    'exclude /ads filings. Accuracy figures are NOT comparable across providers.';

GRANT SELECT ON ad_service_automation TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify:
-- 1) appeals -- should include google-shopping now, plus youtube/maps/play:
--    SELECT provider_slug, service_name, count(*) AS figures
--    FROM ad_service_appeals GROUP BY 1,2 ORDER BY 1;
-- 2) automation -- youtube/maps/play (shopping has no file 8 ads); values sane:
--    SELECT provider_slug, count(*) AS rows,
--           round(min(value)::numeric,2) AS min_v, round(max(value)::numeric,2) AS max_v
--    FROM ad_service_automation GROUP BY 1 ORDER BY 1;
