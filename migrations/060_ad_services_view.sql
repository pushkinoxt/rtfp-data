-- Migration 060: View -- advertising services, surfaced separately.
--
-- Google files advertising moderation as separate services under the parent
-- provider: YouTube Ads, Google Play Ads, Google Maps Ads. Each is a partial filing
-- covering only own-initiative terms-and-conditions actions, appeals and automated
-- means (no government orders, no Article 16 notices, no illegal-content actions).
-- They are deliberately kept OUT of the headline per-provider figures
-- (primary_current_filings excludes the '%/ads' slugs) so a platform is never blended
-- with its advertising business. This view surfaces them on their own terms.
--
-- One row per advertising service.

DROP VIEW IF EXISTS ad_services CASCADE;

CREATE VIEW ad_services AS
SELECT
    p.slug                          AS provider_slug,     -- youtube, google-play, google-maps
    p.name                          AS provider_name,
    f.service_name                  AS service_name,      -- "YouTube Ads" etc.
    f.slug                          AS filing_slug,
    f.period_label                  AS period_label,
    tc.measures_total               AS own_initiative_tc_measures,
    tc.measures_solely_automated    AS measures_solely_automated,
    CASE WHEN tc.measures_total > 0
         THEN round(100.0 * tc.measures_solely_automated / tc.measures_total, 1)
    END                             AS automation_share_pct
FROM filings f
JOIN providers p ON p.id = f.provider_id
LEFT JOIN own_initiative_tc tc
       ON tc.filing_id = f.id AND tc.category_code = 'TOTAL'
WHERE f.slug LIKE '%/ads'
ORDER BY p.name;

COMMENT ON VIEW ad_services IS
    'Advertising services filed separately by Google (YouTube Ads, Google Play Ads, '
    'Google Maps Ads). Held apart from the headline per-provider figures so a platform '
    'is not blended with its advertising business. own_initiative_tc_measures is the '
    'total own-initiative action count on the advertising surface under the provider '
    'terms and conditions; automation_share_pct is the share of those done solely by '
    'automated means.';

GRANT SELECT ON ad_services TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: should return exactly three rows (the Google ad services).
--   SELECT provider_slug, service_name, own_initiative_tc_measures, automation_share_pct
--   FROM ad_services;
