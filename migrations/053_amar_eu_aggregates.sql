-- Migration 053: Add EU AMAR aggregate columns to provider_overview.
--
-- Why: four providers (the Google services) report average monthly active
-- recipients only per Member State, split into signed-in accounts and signed-out
-- sessions, and leave the EU total as a pointer to a PDF. So amar_eu_total is
-- NULL for them and the site showed a blank. Booking, separately, reports the
-- designation floor "> 45" (million) rather than a precise count, which is also
-- non-numeric.
--
-- This adds, per provider, the sum of the per-country signed-in and signed-out
-- figures and the count of Member States behind them. These are RTFP aggregates
-- of figures the provider published per country -- not an official EU total the
-- provider stated -- and the site labels them as such. The two measures are not
-- additive to each other (accounts vs sessions), so they are summed separately
-- and never combined. Providers that report a proper EU total are unaffected:
-- their amar_eu_total stays the headline and these columns are just extra context
-- (NULL where they reported no per-country signed-in/out split).
--
-- This is the live provider_overview (migration 051, on primary_current_filings)
-- with three columns appended, so it is a column-add: every dependent view stays
-- valid. Idempotent.

CREATE OR REPLACE VIEW provider_overview AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    p.legal_entity                  AS legal_entity,
    p.service_category              AS service_category,
    p.designated_on                 AS designated_on,
    p.country_of_establishment      AS country_of_establishment,
    f.id                            AS filing_id,
    f.slug                          AS filing_slug,
    f.period_label                  AS period_label,
    f.original_published_on         AS original_published_on,
    f.this_version_published_on     AS this_version_published_on,
    f.version_number                AS version_number,
    amar_total.value                AS amar_eu_total_raw,
    amar_total.value_numeric        AS amar_eu_total,
    (SELECT sum(i.value_numeric)
       FROM indicators i
      WHERE i.filing_id = f.id
        AND i.source_file = '10_A423_AMAR.csv'
        AND normalise_scope(i.scope) IS DISTINCT FROM 'total'
        AND i.indicator ILIKE '%signed-in%')          AS amar_signed_in_eu_sum,
    (SELECT sum(i.value_numeric)
       FROM indicators i
      WHERE i.filing_id = f.id
        AND i.source_file = '10_A423_AMAR.csv'
        AND normalise_scope(i.scope) IS DISTINCT FROM 'total'
        AND i.indicator ILIKE '%signed-out%')         AS amar_signed_out_eu_sum,
    (SELECT count(DISTINCT normalise_scope(i.scope))
       FROM indicators i
      WHERE i.filing_id = f.id
        AND i.source_file = '10_A423_AMAR.csv'
        AND normalise_scope(i.scope) IS DISTINCT FROM 'total'
        AND i.value_numeric IS NOT NULL)              AS amar_country_count
FROM providers p
JOIN primary_current_filings f ON f.provider_id = p.id
LEFT JOIN indicators amar_total
       ON amar_total.filing_id = f.id
      AND amar_total.source_file = '10_A423_AMAR.csv'
      AND normalise_scope(amar_total.scope) = 'total';

GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: the four Google services should now show non-null sums; Booking stays
-- NULL on the sums (its floor is read from amar_eu_total_raw by the site).
--   SELECT provider_slug, amar_eu_total, amar_signed_in_eu_sum,
--          amar_signed_out_eu_sum, amar_country_count
--   FROM provider_overview
--   WHERE provider_slug IN ('youtube','google-play','google-maps','google-shopping','booking','apple-app-store');
