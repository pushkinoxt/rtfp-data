-- Migration 026: headline_metrics_normalised view.
--
-- Joins each provider's EU total AMAR against the three absolute-volume
-- metrics that need normalisation for cross-platform comparison:
--   1. Account actions (from account_actions_summary)
--   2. Government orders (from government_orders_summary)
--   3. Article 16 notices (from article16_notices, TOTAL row)
--
-- For each (provider × metric × dimension) row, exposes both the absolute
-- value and the per-million-AMAR rate. The frontend defaults to displaying
-- the rate and toggles to absolute on user action.
--
-- "Per million AMAR" is the unit because most absolute volumes are in the
-- millions; dividing by AMAR-in-millions produces readable single-to-double
-- digit numbers that fit on a chart axis without scientific notation.

DROP VIEW IF EXISTS headline_metrics_normalised CASCADE;

CREATE VIEW headline_metrics_normalised AS

-- ===========================================================================
-- Account actions (4 rows per provider: suspensions, terminations, total, and
-- the two combined per basis — we expose only the TOTAL across both bases
-- here, with action_type as the dimension to allow toggling)
-- ===========================================================================
WITH amar AS (
    SELECT
        provider_slug,
        provider_name,
        period_label,
        amar_eu_total
    FROM provider_overview
)
SELECT
    a.provider_slug,
    a.provider_name,
    a.period_label,
    a.amar_eu_total,
    'account_actions'                                           AS metric_key,
    'Account actions'                                           AS metric_label,
    'all'                                                       AS dimension_key,
    'All bases combined'                                        AS dimension_label,
    SUM(COALESCE(aas.total_account_actions, 0))::numeric        AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            SUM(COALESCE(aas.total_account_actions, 0))::numeric * 1000000
              / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN account_actions_summary aas
       ON aas.provider_slug = a.provider_slug
      AND aas.period_label  = a.period_label
GROUP BY a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total

UNION ALL

-- Suspensions only
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'account_actions'                                           AS metric_key,
    'Account actions'                                           AS metric_label,
    'suspensions'                                               AS dimension_key,
    'Suspensions'                                               AS dimension_label,
    SUM(COALESCE(aas.account_suspensions, 0))::numeric          AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            SUM(COALESCE(aas.account_suspensions, 0))::numeric * 1000000
              / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN account_actions_summary aas
       ON aas.provider_slug = a.provider_slug
      AND aas.period_label  = a.period_label
GROUP BY a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total

UNION ALL

-- Terminations only
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'account_actions'                                           AS metric_key,
    'Account actions'                                           AS metric_label,
    'terminations'                                              AS dimension_key,
    'Terminations'                                              AS dimension_label,
    SUM(COALESCE(aas.account_terminations, 0))::numeric         AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            SUM(COALESCE(aas.account_terminations, 0))::numeric * 1000000
              / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN account_actions_summary aas
       ON aas.provider_slug = a.provider_slug
      AND aas.period_label  = a.period_label
GROUP BY a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total

-- ===========================================================================
-- Government orders (3 dimensions: act-against-illegal, info, combined)
-- ===========================================================================
UNION ALL

-- Article 9 orders (act against illegal content)
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'government_orders'                                         AS metric_key,
    'Government orders'                                         AS metric_label,
    'act'                                                       AS dimension_key,
    'Article 9 (act against illegal content)'                   AS dimension_label,
    COALESCE(gos.total_orders_act, 0)::numeric                  AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            COALESCE(gos.total_orders_act, 0)::numeric * 1000000
              / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN government_orders_summary gos
       ON gos.provider_slug = a.provider_slug
      AND gos.period_label  = a.period_label

UNION ALL

-- Article 10 orders (information)
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'government_orders'                                         AS metric_key,
    'Government orders'                                         AS metric_label,
    'info'                                                      AS dimension_key,
    'Article 10 (information requests)'                         AS dimension_label,
    COALESCE(gos.total_orders_info, 0)::numeric                 AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            COALESCE(gos.total_orders_info, 0)::numeric * 1000000
              / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN government_orders_summary gos
       ON gos.provider_slug = a.provider_slug
      AND gos.period_label  = a.period_label

UNION ALL

-- Both Article 9 and Article 10 combined
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'government_orders'                                         AS metric_key,
    'Government orders'                                         AS metric_label,
    'all'                                                       AS dimension_key,
    'All orders (Article 9 + Article 10)'                       AS dimension_label,
    (COALESCE(gos.total_orders_act, 0) + COALESCE(gos.total_orders_info, 0))::numeric
                                                                AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(gos.total_orders_act, 0) + COALESCE(gos.total_orders_info, 0))::numeric
              * 1000000 / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN government_orders_summary gos
       ON gos.provider_slug = a.provider_slug
      AND gos.period_label  = a.period_label

-- ===========================================================================
-- Article 16 notices (3 dimensions: all notices, regular only, Trusted Flagger only)
-- ===========================================================================
UNION ALL

-- All notices (including TF)
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'article16_notices'                                         AS metric_key,
    'Article 16 notices'                                        AS metric_label,
    'all'                                                       AS dimension_key,
    'All notices (incl. Trusted Flagger)'                       AS dimension_label,
    COALESCE(a16.notices_received, 0)::numeric                  AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            COALESCE(a16.notices_received, 0)::numeric * 1000000
              / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN article16_notices a16
       ON a16.filing_id = (SELECT id FROM filings f
                             WHERE f.provider_id = (SELECT id FROM providers
                                                      WHERE slug = a.provider_slug)
                               AND f.period_label = a.period_label)
      AND a16.category_code = 'TOTAL'

UNION ALL

-- Trusted Flagger notices only
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'article16_notices'                                         AS metric_key,
    'Article 16 notices'                                        AS metric_label,
    'trusted_flagger'                                           AS dimension_key,
    'Trusted Flagger notices'                                   AS dimension_label,
    COALESCE(a16.notices_received_tf, 0)::numeric               AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            COALESCE(a16.notices_received_tf, 0)::numeric * 1000000
              / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN article16_notices a16
       ON a16.filing_id = (SELECT id FROM filings f
                             WHERE f.provider_id = (SELECT id FROM providers
                                                      WHERE slug = a.provider_slug)
                               AND f.period_label = a.period_label)
      AND a16.category_code = 'TOTAL'

UNION ALL

-- Regular (non-TF) notices = all minus TF
SELECT
    a.provider_slug, a.provider_name, a.period_label, a.amar_eu_total,
    'article16_notices'                                         AS metric_key,
    'Article 16 notices'                                        AS metric_label,
    'regular'                                                   AS dimension_key,
    'Regular notices (excl. Trusted Flagger)'                   AS dimension_label,
    (COALESCE(a16.notices_received, 0) - COALESCE(a16.notices_received_tf, 0))::numeric
                                                                AS absolute_value,
    CASE
        WHEN a.amar_eu_total IS NULL OR a.amar_eu_total = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(a16.notices_received, 0) - COALESCE(a16.notices_received_tf, 0))::numeric
              * 1000000 / a.amar_eu_total::numeric,
            2
        )
    END                                                         AS per_million_amar
FROM amar a
LEFT JOIN article16_notices a16
       ON a16.filing_id = (SELECT id FROM filings f
                             WHERE f.provider_id = (SELECT id FROM providers
                                                      WHERE slug = a.provider_slug)
                               AND f.period_label = a.period_label)
      AND a16.category_code = 'TOTAL';

COMMENT ON VIEW headline_metrics_normalised IS
    'Long-format view exposing three headline absolute-volume metrics with '
    'their per-million-AMAR normalisation alongside. Each row is one '
    '(provider × metric_key × dimension_key) combination. metric_key is one '
    'of: account_actions, government_orders, article16_notices. dimension_key '
    'is metric-specific (e.g. "suspensions" / "terminations" / "all" for '
    'account_actions). The frontend defaults to displaying per_million_amar '
    'and toggles to absolute_value on user action.';
