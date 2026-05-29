-- Migration 022: Three views surfacing data quality and disclosure coverage.
-- This is the final Phase C migration. The disclosure_coverage view is the
-- distinctive analytical contribution: it makes selective disclosure itself
-- a queryable dataset.

-- ===========================================================================
-- View: filings_overview
-- One row per filing, with provenance summary.
-- ===========================================================================

DROP VIEW IF EXISTS filings_overview CASCADE;

CREATE VIEW filings_overview AS
SELECT
    p.slug                                          AS provider_slug,
    p.name                                          AS provider_name,
    p.legal_entity                                  AS legal_entity,
    f.id                                            AS filing_id,
    f.slug                                          AS filing_slug,
    f.period_label                                  AS period_label,
    f.period_start                                  AS period_start,
    f.period_end                                    AS period_end,
    f.original_published_on                         AS original_published_on,
    f.this_version_published_on                     AS this_version_published_on,
    f.version_number                                AS version_number,
    f.restates_filing_id                            AS restates_filing_id,
    f.restatement_reason                            AS restatement_reason,
    f.report_url                                    AS report_url,
    f.imported_at                                   AS imported_at,
    -- Counts of loaded rows per table, for at-a-glance completeness
    (SELECT COUNT(*) FROM member_state_orders   WHERE filing_id = f.id) AS rows_member_state_orders,
    (SELECT COUNT(*) FROM article16_notices     WHERE filing_id = f.id) AS rows_article16_notices,
    (SELECT COUNT(*) FROM own_initiative_illegal WHERE filing_id = f.id) AS rows_own_initiative_illegal,
    (SELECT COUNT(*) FROM own_initiative_tc     WHERE filing_id = f.id) AS rows_own_initiative_tc,
    (SELECT COUNT(*) FROM indicators            WHERE filing_id = f.id) AS rows_indicators,
    (SELECT COUNT(*) FROM qualitative_indicators WHERE filing_id = f.id) AS rows_qualitative_indicators,
    (SELECT COUNT(*) FROM import_anomalies      WHERE filing_id = f.id) AS rows_anomalies
FROM filings f
JOIN providers p ON p.id = f.provider_id;

COMMENT ON VIEW filings_overview IS
    'One row per filing event with provenance summary and per-table row counts. '
    'rows_anomalies > 0 signals that provider-level methodology issues were '
    'flagged during loading. Anywhere rows_own_initiative_illegal = 0 indicates '
    'the provider either left the file blank or filled it with placeholders — '
    'a known TikTok pattern.';

-- ===========================================================================
-- View: anomalies_by_filing
-- Friendly join of import_anomalies to providers.
-- ===========================================================================

DROP VIEW IF EXISTS anomalies_by_filing CASCADE;

CREATE VIEW anomalies_by_filing AS
SELECT
    p.slug                                          AS provider_slug,
    p.name                                          AS provider_name,
    f.period_label                                  AS period_label,
    ia.source_file                                  AS source_file,
    ia.anomaly_type                                 AS anomaly_type,
    ia.description                                  AS description,
    ia.detected_at                                   AS observed_at
FROM import_anomalies ia
JOIN filings   f ON f.id = ia.filing_id
JOIN providers p ON p.id = f.provider_id
ORDER BY p.slug, ia.source_file, ia.anomaly_type;

COMMENT ON VIEW anomalies_by_filing IS
    'Methodology and data-quality observations recorded during the import '
    'process. Each row is a structured finding: undeclared category codes '
    'auto-added to the taxonomy, files filed empty, unexpected encoding, '
    'numeric values stored as text. These rows are themselves a contribution '
    'of the project — they describe the gap between what the harmonised '
    'template asks for and what providers actually file.';

-- ===========================================================================
-- View: disclosure_coverage
-- One row per (provider × key disclosure), with whether the value was reported.
-- The HIIG "selective disclosure" critique made queryable.
-- ===========================================================================

DROP VIEW IF EXISTS disclosure_coverage CASCADE;

CREATE VIEW disclosure_coverage AS
WITH key_disclosures AS (
    -- A curated list of disclosures Article 15/24/42 either mandates or
    -- treats as primary. Each is a (article_reference, disclosure_label,
    -- source_table, qualifying_expr) tuple realised as a UNION ALL.

    -- ---- Article 15(1)(a) — government orders ----
    SELECT p.slug AS provider_slug, p.name AS provider_name,
           'Art. 15(1)(a)'  AS article_reference,
           'Article 9 orders received (total)' AS disclosure_label,
           (mso.orders_act_received IS NOT NULL AND mso.orders_act_received >= 0) AS is_reported,
           mso.orders_act_received AS value_if_reported
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN member_state_orders mso
           ON mso.filing_id = f.id AND mso.scope = 'TOTAL' AND mso.category_code = 'TOTAL'

    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(a)', 'Article 10 orders received (total)',
           (mso.orders_info_received IS NOT NULL AND mso.orders_info_received >= 0),
           mso.orders_info_received
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN member_state_orders mso
           ON mso.filing_id = f.id AND mso.scope = 'TOTAL' AND mso.category_code = 'TOTAL'

    -- ---- Article 15(1)(b) — Article 16 notices ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(b)', 'Article 16 notices received (total)',
           (a16.notices_received IS NOT NULL AND a16.notices_received >= 0),
           a16.notices_received
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN article16_notices a16
           ON a16.filing_id = f.id AND a16.category_code = 'TOTAL'

    UNION ALL
    SELECT p.slug, p.name,
           'Art. 22',      'Trusted Flagger notices received (total)',
           (a16.notices_received_tf IS NOT NULL AND a16.notices_received_tf >= 0),
           a16.notices_received_tf
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN article16_notices a16
           ON a16.filing_id = f.id AND a16.category_code = 'TOTAL'

    -- ---- Article 15(1)(c) — own initiative against illegal ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(c)','Own-initiative actions against illegal content (total)',
           (oii.measures_total IS NOT NULL AND oii.measures_total >= 0),
           oii.measures_total
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN own_initiative_illegal oii
           ON oii.filing_id = f.id AND oii.category_code = 'TOTAL'

    -- ---- Article 15(1)(d) — own initiative against ToS ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(d)','Own-initiative actions against ToS violations (total)',
           (oitc.measures_total IS NOT NULL AND oitc.measures_total >= 0),
           oitc.measures_total
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN own_initiative_tc oitc
           ON oitc.filing_id = f.id AND oitc.category_code = 'TOTAL'

    -- ---- Article 20 — internal complaints ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 20',      'Internal complaints submitted (total)',
           (ics.total_complaints IS NOT NULL AND ics.total_complaints >= 0),
           ics.total_complaints
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN internal_complaints_summary ics
           ON ics.provider_slug = p.slug
          AND ics.period_label  = f.period_label
          AND ics.complaint_subject = 'Number of complaints submitted to the internal-complaints mechanism'

    -- ---- Article 21 / 24(1)(a) — out-of-court disputes ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 24(1)(a)','Out-of-court disputes — share implemented',
           (ocd.share_provider_implemented_pct IS NOT NULL),
           ocd.share_provider_implemented_pct
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN out_of_court_disputes ocd
           ON ocd.provider_slug = p.slug AND ocd.period_label = f.period_label

    -- ---- Article 23 / 24(1)(b) — misuse suspensions ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 24(1)(b)','Article 23 suspensions for manifestly illegal content',
           (ms.suspensions_for_illegal_content IS NOT NULL),
           ms.suspensions_for_illegal_content
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN misuse_suspensions ms
           ON ms.provider_slug = p.slug AND ms.period_label = f.period_label

    -- ---- Article 42(2)(a) — moderator headcount ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 42(2)(a)','Total moderator headcount',
           (hm.moderators IS NOT NULL AND hm.moderators > 0),
           hm.moderators
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN human_moderators_by_language hm
           ON hm.provider_slug = p.slug
          AND hm.period_label  = f.period_label
          AND hm.language_code = 'total'

    -- ---- Article 42(3) — per-Member-State AMAR ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 42(3)',   'AMAR for all 27 EU Member States',
           (
             SELECT COUNT(DISTINCT amar.country_code) FROM amar_by_country amar
             WHERE amar.provider_slug = p.slug
               AND amar.period_label  = f.period_label
               AND amar.is_eu_member  = TRUE
           ) = 27,
           (
             SELECT COUNT(DISTINCT amar.country_code) FROM amar_by_country amar
             WHERE amar.provider_slug = p.slug
               AND amar.period_label  = f.period_label
               AND amar.is_eu_member  = TRUE
           )::numeric
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id

    -- ---- Article 42(2)(a) — moderator coverage of all 24 EU languages ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 42(2)(a)','Moderators reported for all 24 EU official languages',
           (
             SELECT COUNT(DISTINCT hm.language_code) FROM human_moderators_by_language hm
             WHERE hm.provider_slug = p.slug
               AND hm.period_label  = f.period_label
               AND hm.is_eu_official = TRUE
               AND hm.moderators > 0
           ) = 24,
           (
             SELECT COUNT(DISTINCT hm.language_code) FROM human_moderators_by_language hm
             WHERE hm.provider_slug = p.slug
               AND hm.period_label  = f.period_label
               AND hm.is_eu_official = TRUE
               AND hm.moderators > 0
           )::numeric
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
)
SELECT
    provider_slug,
    provider_name,
    article_reference,
    disclosure_label,
    is_reported,
    value_if_reported
FROM key_disclosures
ORDER BY provider_slug, article_reference, disclosure_label;

COMMENT ON VIEW disclosure_coverage IS
    'For each (provider × key disclosure) the regulation mandates or treats '
    'as primary, whether the provider populated it. Twelve disclosure checks '
    'cover Articles 15(1)(a)–(d), 20, 22, 23, 24, and 42(2)(a)/(3). For two '
    'of those (per-Member-State AMAR coverage and per-language moderator '
    'coverage), the value_if_reported column gives the count of populated '
    'rows rather than a single number — useful for "filed 18 of 24 languages" '
    'reporting. The HIIG (Sept 2025) critique made queryable: selective '
    'disclosure is itself the most analytically interesting variable in the '
    'dataset.';
