-- Migration 035: Recreate analytical views dropped by migration 031's cascade.
--
-- Migration 031 ran `ALTER TABLE indicators DROP COLUMN value_numeric CASCADE`,
-- which silently dropped every view depending (directly or transitively) on
-- value_numeric, then re-added the column without recreating the views. Those
-- views (and their SELECT grants) were lost, so the public API 404s them.
--
-- This migration recreates all 22 analytical views from their canonical
-- definitions (CREATE OR REPLACE, so it is a no-op for the survivors and a
-- restore for the casualties), re-grants read access, and reloads PostgREST.
-- It is idempotent and safe to re-run.

-- amar_by_country  (from 015_country_codes_and_amar_views.sql)
CREATE OR REPLACE VIEW amar_by_country AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    f.period_label                  AS period_label,
    normalise_scope(i.scope)        AS country_code,
    cc.name                         AS country_name,
    cc.is_eu_member                 AS is_eu_member,
    i.value                         AS amar_raw,
    i.value_numeric                 AS amar
FROM indicators i
JOIN filings   f  ON f.id = i.filing_id
JOIN providers p  ON p.id = f.provider_id
LEFT JOIN country_codes cc ON cc.code = normalise_scope(i.scope)
WHERE i.source_file = '10_A423_AMAR.csv'
  AND normalise_scope(i.scope) IS DISTINCT FROM 'total';

-- provider_overview  (from 015_country_codes_and_amar_views.sql)
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
    amar_total.value_numeric        AS amar_eu_total
FROM providers p
JOIN filings f ON f.provider_id = p.id
LEFT JOIN indicators amar_total
       ON amar_total.filing_id = f.id
      AND amar_total.source_file = '10_A423_AMAR.csv'
      AND normalise_scope(amar_total.scope) = 'total';

-- government_orders_by_country  (from 016_government_orders_views.sql)
CREATE OR REPLACE VIEW government_orders_by_country AS
SELECT
    p.slug                              AS provider_slug,
    p.name                              AS provider_name,
    f.period_label                      AS period_label,
    normalise_scope(mso.scope)          AS country_code,
    cc.name                             AS country_name,
    cc.is_eu_member                     AS is_eu_member,
    mso.orders_act_received             AS orders_act_received,
    mso.items_in_orders_act             AS items_in_orders_act,
    mso.median_time_inform_receipt_act  AS median_time_inform_receipt_act,
    mso.median_time_give_effect_act     AS median_time_give_effect_act,
    mso.orders_info_received            AS orders_info_received,
    mso.median_time_inform_receipt_info AS median_time_inform_receipt_info,
    mso.median_time_give_effect_info    AS median_time_give_effect_info
FROM member_state_orders mso
JOIN filings   f ON f.id = mso.filing_id
JOIN providers p ON p.id = f.provider_id
LEFT JOIN country_codes cc ON cc.code = normalise_scope(mso.scope)
WHERE mso.category_code = 'TOTAL'
  AND normalise_scope(mso.scope) IS DISTINCT FROM 'total';

-- government_orders_by_category  (from 016_government_orders_views.sql)
CREATE OR REPLACE VIEW government_orders_by_category AS
SELECT
    p.slug                              AS provider_slug,
    p.name                              AS provider_name,
    f.period_label                      AS period_label,
    mso.category_code                   AS category_code,
    cat.label                           AS category_label,
    mso.category_label_raw              AS parent_label_raw,
    mso.description_other               AS description_other,
    mso.orders_act_received             AS orders_act_received,
    mso.items_in_orders_act             AS items_in_orders_act,
    mso.orders_info_received            AS orders_info_received
FROM member_state_orders mso
JOIN filings   f   ON f.id = mso.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = mso.category_code
WHERE mso.scope = 'TOTAL'
  AND mso.category_code != 'TOTAL';

-- government_orders_summary  (from 016_government_orders_views.sql)
CREATE OR REPLACE VIEW government_orders_summary AS
SELECT
    p.slug                              AS provider_slug,
    p.name                              AS provider_name,
    f.period_label                      AS period_label,
    mso.orders_act_received             AS total_orders_act,
    mso.items_in_orders_act             AS total_items_in_orders_act,
    mso.median_time_inform_receipt_act  AS median_time_inform_receipt_act,
    mso.median_time_give_effect_act     AS median_time_give_effect_act,
    mso.orders_info_received            AS total_orders_info,
    mso.median_time_inform_receipt_info AS median_time_inform_receipt_info,
    mso.median_time_give_effect_info    AS median_time_give_effect_info
FROM member_state_orders mso
JOIN filings   f ON f.id = mso.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE mso.category_code = 'TOTAL'
  AND mso.scope = 'TOTAL';

-- notices_by_category  (from 017_notices_and_tf_views.sql)
CREATE OR REPLACE VIEW notices_by_category AS
SELECT
    p.slug                              AS provider_slug,
    p.name                              AS provider_name,
    f.period_label                      AS period_label,
    a16.category_code                   AS category_code,
    cat.label                           AS category_label,
    a16.category_label_raw              AS parent_label_raw,
    a16.description_other               AS description_other,
    a16.notices_received                AS notices_received,
    a16.notices_received_tf             AS notices_received_tf,
    a16.items_in_notices                AS items_in_notices,
    a16.items_in_notices_tf             AS items_in_notices_tf,
    a16.median_time_to_action           AS median_time_to_action,
    a16.median_time_to_action_tf        AS median_time_to_action_tf,
    a16.actions_basis_law               AS actions_basis_law,
    a16.actions_basis_law_tf            AS actions_basis_law_tf,
    a16.actions_basis_tc                AS actions_basis_tc,
    a16.actions_basis_tc_tf             AS actions_basis_tc_tf
FROM article16_notices a16
JOIN filings   f   ON f.id = a16.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = a16.category_code
WHERE a16.category_code != 'TOTAL';

-- trusted_flagger_intensity  (from 017_notices_and_tf_views.sql)
CREATE OR REPLACE VIEW trusted_flagger_intensity AS
SELECT
    p.slug                              AS provider_slug,
    p.name                              AS provider_name,
    f.period_label                      AS period_label,
    a16.category_code                   AS category_code,
    cat.label                           AS category_label,
    a16.category_label_raw              AS parent_label_raw,
    a16.notices_received                AS notices_received,
    a16.notices_received_tf             AS notices_received_tf,
    CASE
        WHEN a16.notices_received IS NULL THEN NULL
        WHEN a16.notices_received = 0    THEN NULL
        ELSE ROUND(
            (COALESCE(a16.notices_received_tf, 0)::numeric /
             a16.notices_received::numeric) * 100,
            4
        )
    END                                 AS tf_share_pct,
    a16.actions_basis_law               AS actions_basis_law,
    a16.actions_basis_law_tf            AS actions_basis_law_tf,
    a16.actions_basis_tc                AS actions_basis_tc,
    a16.actions_basis_tc_tf             AS actions_basis_tc_tf
FROM article16_notices a16
JOIN filings   f   ON f.id = a16.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = a16.category_code;

-- notice_response_times  (from 017_notices_and_tf_views.sql)
CREATE OR REPLACE VIEW notice_response_times AS
SELECT
    p.slug                              AS provider_slug,
    p.name                              AS provider_name,
    f.period_label                      AS period_label,
    a16.category_code                   AS category_code,
    cat.label                           AS category_label,
    a16.median_time_to_action           AS median_time_to_action,
    a16.median_time_to_action_tf        AS median_time_to_action_tf,
    CASE
        WHEN a16.median_time_to_action IS NULL THEN NULL
        WHEN a16.median_time_to_action = 0    THEN NULL
        WHEN a16.median_time_to_action_tf IS NULL THEN NULL
        ELSE ROUND(
            a16.median_time_to_action_tf::numeric /
            a16.median_time_to_action::numeric,
            3
        )
    END                                 AS tf_to_regular_ratio
FROM article16_notices a16
JOIN filings   f   ON f.id = a16.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = a16.category_code;

-- moderation_volume_comparison  (from 018_moderation_views.sql)
CREATE OR REPLACE VIEW moderation_volume_comparison AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    f.period_label                  AS period_label,
    'illegal'::text                 AS basis,
    CASE
        WHEN oii.category_code = 'TOTAL'                    THEN 'total'
        WHEN oii.category_code LIKE 'STATEMENT_CATEGORY_%'  THEN 'parent'
        WHEN oii.category_code LIKE 'KEYWORD_%'             THEN 'keyword'
        ELSE 'other'
    END                             AS level,
    oii.category_code               AS category_code,
    cat.label                       AS category_label,
    oii.category_label_raw          AS parent_label_raw,
    oii.description_other           AS description_other,
    oii.measures_total              AS measures_total,
    oii.measures_solely_automated   AS measures_solely_automated,
    oii.vis_removal,
    oii.vis_disable,
    oii.vis_demoted,
    oii.vis_age_restricted,
    oii.vis_interaction_restricted,
    oii.vis_labelled,
    oii.vis_other,
    oii.mon_suspension,
    oii.mon_termination,
    oii.mon_other,
    oii.svc_suspension,
    oii.svc_termination,
    oii.acc_suspension,
    oii.acc_termination
FROM own_initiative_illegal oii
JOIN filings   f   ON f.id = oii.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = oii.category_code

UNION ALL

SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    f.period_label                  AS period_label,
    'tc'::text                      AS basis,
    CASE
        WHEN oitc.category_code = 'TOTAL'                   THEN 'total'
        WHEN oitc.category_code LIKE 'STATEMENT_CATEGORY_%' THEN 'parent'
        WHEN oitc.category_code LIKE 'KEYWORD_%'            THEN 'keyword'
        ELSE 'other'
    END                             AS level,
    oitc.category_code              AS category_code,
    cat.label                       AS category_label,
    oitc.category_label_raw         AS parent_label_raw,
    oitc.description_other          AS description_other,
    oitc.measures_total             AS measures_total,
    oitc.measures_solely_automated  AS measures_solely_automated,
    oitc.vis_removal,
    oitc.vis_disable,
    oitc.vis_demoted,
    oitc.vis_age_restricted,
    oitc.vis_interaction_restricted,
    oitc.vis_labelled,
    oitc.vis_other,
    oitc.mon_suspension,
    oitc.mon_termination,
    oitc.mon_other,
    oitc.svc_suspension,
    oitc.svc_termination,
    oitc.acc_suspension,
    oitc.acc_termination
FROM own_initiative_tc oitc
JOIN filings   f   ON f.id = oitc.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = oitc.category_code;

-- automation_share_by_provider  (from 018_moderation_views.sql)
CREATE OR REPLACE VIEW automation_share_by_provider AS
SELECT
    provider_slug,
    provider_name,
    period_label,
    basis,
    measures_total,
    measures_solely_automated,
    CASE
        WHEN measures_total IS NULL OR measures_total = 0 THEN NULL
        ELSE ROUND(
            measures_solely_automated::numeric / measures_total::numeric * 100,
            2
        )
    END                             AS automation_share_pct
FROM moderation_volume_comparison
WHERE level = 'total';

-- restriction_type_breakdown  (from 018_moderation_views.sql)
CREATE OR REPLACE VIEW restriction_type_breakdown AS
SELECT
    provider_slug,
    provider_name,
    period_label,
    basis,
    measures_total,
    -- Family totals — Annex II defines these as non-overlapping
    COALESCE(vis_removal,0) + COALESCE(vis_disable,0) + COALESCE(vis_demoted,0) +
    COALESCE(vis_age_restricted,0) + COALESCE(vis_interaction_restricted,0) +
    COALESCE(vis_labelled,0) + COALESCE(vis_other,0)
                                    AS visibility_actions,
    COALESCE(mon_suspension,0) + COALESCE(mon_termination,0) + COALESCE(mon_other,0)
                                    AS monetary_actions,
    COALESCE(svc_suspension,0) + COALESCE(svc_termination,0)
                                    AS service_actions,
    COALESCE(acc_suspension,0) + COALESCE(acc_termination,0)
                                    AS account_actions
FROM moderation_volume_comparison
WHERE level = 'total';

-- account_actions_summary  (from 018_moderation_views.sql)
CREATE OR REPLACE VIEW account_actions_summary AS
SELECT
    provider_slug,
    provider_name,
    period_label,
    basis,
    acc_suspension                  AS account_suspensions,
    acc_termination                 AS account_terminations,
    COALESCE(acc_suspension,0) + COALESCE(acc_termination,0)
                                    AS total_account_actions
FROM moderation_volume_comparison
WHERE level = 'total';

-- internal_complaints_summary  (from 019_complaints_disputes_misuse_views.sql)
CREATE OR REPLACE VIEW internal_complaints_summary AS
SELECT
    p.slug                                                AS provider_slug,
    p.name                                                AS provider_name,
    f.period_label                                        AS period_label,
    i.indicator                                           AS complaint_subject,
    MAX(CASE WHEN i.scope = 'Total number'
             THEN i.value_numeric END)                    AS total_complaints,
    MAX(CASE WHEN i.scope = 'Decisions upheld'
             THEN i.value_numeric END)                    AS decisions_upheld,
    MAX(CASE WHEN i.scope = 'Decisions reversed'
             THEN i.value_numeric END)                    AS decisions_reversed,
    MAX(CASE WHEN i.scope = 'Decisions partially reversed'
             THEN i.value_numeric END)                    AS decisions_partially_reversed,
    MAX(CASE WHEN i.scope = 'Decision omitted'
             THEN i.value_numeric END)                    AS decisions_omitted,
    MAX(CASE WHEN i.scope = 'Median time'
             THEN i.value_numeric END)                    AS median_time
FROM indicators i
JOIN filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE i.source_file = '07_Appeals.csv'
  AND i.section = 'Internal complaints mechanism'
GROUP BY p.slug, p.name, f.period_label, i.indicator;

-- out_of_court_disputes  (from 019_complaints_disputes_misuse_views.sql)
CREATE OR REPLACE VIEW out_of_court_disputes AS
SELECT
    p.slug                                                AS provider_slug,
    p.name                                                AS provider_name,
    f.period_label                                        AS period_label,
    MAX(CASE WHEN i.scope = 'Total number'
             THEN i.value_numeric END)                    AS disputes_submitted,
    MAX(CASE WHEN i.scope = 'Decisions upheld'
             THEN i.value_numeric END)                    AS decisions_upheld,
    MAX(CASE WHEN i.scope = 'Decisions reversed'
             THEN i.value_numeric END)                    AS decisions_reversed,
    MAX(CASE WHEN i.scope = 'Decisions partially reversed'
             THEN i.value_numeric END)                    AS decisions_partially_reversed,
    MAX(CASE WHEN i.scope = 'Decision omitted'
             THEN i.value_numeric END)                    AS decisions_omitted,
    MAX(CASE WHEN i.scope = 'Median time'
             THEN i.value_numeric END)                    AS median_completion_time,
    MAX(CASE WHEN i.scope = 'Percentage of outcomes implemented'
             THEN i.value_numeric END)                    AS share_provider_implemented_pct
FROM indicators i
JOIN filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE i.source_file = '07_Appeals.csv'
  AND i.section = 'Out-of-court dispute settlement bodies'
GROUP BY p.slug, p.name, f.period_label;

-- misuse_suspensions  (from 019_complaints_disputes_misuse_views.sql)
CREATE OR REPLACE VIEW misuse_suspensions AS
SELECT
    p.slug                                                AS provider_slug,
    p.name                                                AS provider_name,
    f.period_label                                        AS period_label,
    MAX(CASE WHEN i.indicator = 'Number of suspensions enacted for the provision of manifestly illegal content'
             THEN i.value_numeric END)                    AS suspensions_for_illegal_content,
    MAX(CASE WHEN i.indicator = 'Number of suspensions enacted for the provision of manifestly unfounded notices'
             THEN i.value_numeric END)                    AS suspensions_for_unfounded_notices,
    MAX(CASE WHEN i.indicator = 'Number of suspensions enacted for the provision of manifestly unfounded complaints'
             THEN i.value_numeric END)                    AS suspensions_for_unfounded_complaints
FROM indicators i
JOIN filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE i.source_file = '07_Appeals.csv'
  AND i.section = 'Suspensions imposed on repeated offenders'
GROUP BY p.slug, p.name, f.period_label;

-- human_moderators_by_language  (from 020_human_moderators_view.sql)
CREATE OR REPLACE VIEW human_moderators_by_language AS
SELECT
    p.slug                                                AS provider_slug,
    p.name                                                AS provider_name,
    f.period_label                                        AS period_label,
    normalise_language(i.scope)                           AS language_code,
    lc.name                                               AS language_name,
    lc.is_eu_official                                     AS is_eu_official,
    i.value_numeric                                       AS moderators
FROM indicators i
JOIN filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
LEFT JOIN language_codes lc ON lc.code = normalise_language(i.scope)
WHERE i.source_file = '09_A422AB_Human.csv'
  AND i.indicator   = 'Number of total moderators with sufficient linguistic expertise';

-- actions_per_user  (from 021_derived_metrics_views.sql)
CREATE OR REPLACE VIEW actions_per_user AS
SELECT
    po.provider_slug,
    po.provider_name,
    po.period_label,
    po.amar_eu_total,
    asp.basis,
    asp.measures_total,
    asp.measures_solely_automated,
    CASE
        WHEN po.amar_eu_total IS NULL OR po.amar_eu_total = 0 THEN NULL
        WHEN asp.measures_total IS NULL THEN NULL
        ELSE ROUND(
            asp.measures_total::numeric / po.amar_eu_total::numeric,
            4
        )
    END                                 AS actions_per_user,
    CASE
        WHEN po.amar_eu_total IS NULL OR po.amar_eu_total = 0 THEN NULL
        WHEN asp.measures_solely_automated IS NULL THEN NULL
        ELSE ROUND(
            asp.measures_solely_automated::numeric / po.amar_eu_total::numeric,
            4
        )
    END                                 AS automated_actions_per_user
FROM provider_overview po
LEFT JOIN automation_share_by_provider asp
       ON asp.provider_slug = po.provider_slug
      AND asp.period_label  = po.period_label;

-- amar_per_moderator  (from 021_derived_metrics_views.sql)
CREATE OR REPLACE VIEW amar_per_moderator AS
SELECT
    po.provider_slug,
    po.provider_name,
    po.period_label,
    po.amar_eu_total,
    hmt.moderators                                  AS total_moderators,
    CASE
        WHEN hmt.moderators IS NULL OR hmt.moderators = 0 THEN NULL
        WHEN po.amar_eu_total IS NULL THEN NULL
        ELSE ROUND(
            po.amar_eu_total::numeric / hmt.moderators::numeric,
            0
        )
    END                                             AS users_per_moderator
FROM provider_overview po
LEFT JOIN human_moderators_by_language hmt
       ON hmt.provider_slug = po.provider_slug
      AND hmt.period_label  = po.period_label
      AND hmt.language_code = 'total';

-- filings_overview  (from 022_data_quality_views.sql)
CREATE OR REPLACE VIEW filings_overview AS
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

-- anomalies_by_filing  (from 022_data_quality_views.sql)
CREATE OR REPLACE VIEW anomalies_by_filing AS
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

-- disclosure_coverage  (from 022_data_quality_views.sql)
CREATE OR REPLACE VIEW disclosure_coverage AS
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

-- headline_metrics_normalised  (from 026_headline_metrics_normalised.sql)
CREATE OR REPLACE VIEW headline_metrics_normalised AS

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

-- ---------------------------------------------------------------------------
-- Restore read-only grants (CASCADE-recreated views lose the grants from 023).
-- GRANT ... ON ALL TABLES covers views too, and is harmless on survivors.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- Ask PostgREST to reload its schema cache so the views appear immediately.
NOTIFY pgrst, 'reload schema';
