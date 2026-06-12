-- Migration 050: Introduce current_filings and repoint analytical views to it.
--
-- Why: filings now holds restatements (Amazon and Snap each have a v1 and a v2,
-- linked by restates_filing_id). Every analytical view joined `filings` directly
-- and none filtered on version, so each restated provider produced duplicate rows;
-- worse, views that join on (provider_slug, period_label) -- actions_per_user,
-- headline_metrics_normalised -- fanned those duplicates into cartesian products
-- mixing 150.5M and 402.7M figures.
--
-- Fix: current_filings exposes only the latest version in each restatement chain
-- (a filing that nothing else restates). The 15 analytical views below are
-- recreated identically except that their `filings` reference becomes
-- `current_filings`. Column lists are unchanged, so CREATE OR REPLACE keeps every
-- dependent view valid; the 5 views built on these (automation_share_by_provider,
-- restriction_type_breakdown, account_actions_summary, actions_per_user,
-- amar_per_moderator) inherit the fix automatically and are not touched. The two
-- provenance views (filings_overview, anomalies_by_filing) deliberately keep
-- joining `filings` so they still show every version.
--
-- KNOWN LIMITATION (separate issue, not addressed here): current_filings collapses
-- versions but NOT multi-service providers. Google's youtube/google-play/google-maps
-- each have a main and an "Ads" filing, so provider-keyed views still emit two rows
-- per such provider, and headline_metrics_normalised's scalar `= (SELECT id FROM
-- current_filings ...)` subquery can still return >1 row for them. That is the
-- pre-existing multi-service problem, to be fixed in a follow-up (key on service_name
-- or restrict to the main service).
--
-- Generated from migration 036 (13 views) plus the live post-041 definitions of
-- amar_by_country and disclosure_coverage, with `filings` -> `current_filings`.
-- Idempotent.

-- ===========================================================================
-- current_filings: latest version per (provider, service, period) chain
-- ===========================================================================
CREATE OR REPLACE VIEW current_filings AS
SELECT f.*
FROM filings f
WHERE NOT EXISTS (
    SELECT 1 FROM filings r WHERE r.restates_filing_id = f.id
);

COMMENT ON VIEW current_filings IS
    'The latest version of each filing chain: every filing that no other filing '
    'restates. For an un-restated filing this is simply itself; for a restated '
    'one it is the most recent version (v1 is restated by v2, so v1 drops out; '
    'v2 survives). Analytical views join this instead of filings so superseded '
    'versions never appear in or fan out the headline numbers. Provenance views '
    '(filings_overview, anomalies_by_filing) keep using filings to show all versions.';


-- ---------------------------------------------------------------------------
-- amar_by_country  (repointed to current_filings)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW amar_by_country AS
 SELECT p.slug AS provider_slug,
    p.name AS provider_name,
    f.period_label,
    normalise_scope(i.scope) AS country_code,
    cc.name AS country_name,
    cc.is_eu_member,
    i.value AS amar_raw,
        CASE
            WHEN i.value_numeric IS NOT NULL THEN to_char(i.value_numeric, 'FM999,999,999,999'::text)
            WHEN p.slug = 'booking'::text AND TRIM(BOTH FROM i.value) ~ '^[0-9.]+ *- *[0-9.]+$'::text THEN
            CASE
                WHEN TRIM(BOTH FROM split_part(i.value, '-'::text, 1)) = TRIM(BOTH FROM split_part(i.value, '-'::text, 2)) THEN to_char(round(TRIM(BOTH FROM split_part(i.value, '-'::text, 1))::numeric * 1000000::numeric), 'FM999,999,999,999'::text)
                ELSE (to_char(round(TRIM(BOTH FROM split_part(i.value, '-'::text, 1))::numeric * 1000000::numeric), 'FM999,999,999,999'::text) || '-'::text) || to_char(round(TRIM(BOTH FROM split_part(i.value, '-'::text, 2))::numeric * 1000000::numeric), 'FM999,999,999,999'::text)
            END
            ELSE i.value
        END AS amar,
        CASE
            WHEN i.indicator ~~* '%signed-in%'::text THEN 'signed-in accounts'::text
            WHEN i.indicator ~~* '%signed-out%'::text THEN 'signed-out sessions'::text
            ELSE 'all recipients'::text
        END AS measure,
    i.value_is_estimate AS is_estimate
   FROM indicators i
     JOIN current_filings f ON f.id = i.filing_id
     JOIN providers p ON p.id = f.provider_id
     LEFT JOIN country_codes cc ON cc.code = normalise_scope(i.scope)
  WHERE i.source_file = '10_A423_AMAR.csv'::text AND normalise_scope(i.scope) IS DISTINCT FROM 'total'::text;

-- ---------------------------------------------------------------------------
-- provider_overview  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings f ON f.provider_id = p.id
LEFT JOIN indicators amar_total
       ON amar_total.filing_id = f.id
      AND amar_total.source_file = '10_A423_AMAR.csv'
      AND normalise_scope(amar_total.scope) = 'total';

-- ---------------------------------------------------------------------------
-- government_orders_by_country  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f ON f.id = mso.filing_id
JOIN providers p ON p.id = f.provider_id
LEFT JOIN country_codes cc ON cc.code = normalise_scope(mso.scope)
WHERE mso.category_code = 'TOTAL'
  AND normalise_scope(mso.scope) IS DISTINCT FROM 'total';

-- ---------------------------------------------------------------------------
-- government_orders_by_category  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f   ON f.id = mso.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = mso.category_code
WHERE mso.scope = 'TOTAL'
  AND mso.category_code != 'TOTAL';

-- ---------------------------------------------------------------------------
-- government_orders_summary  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f ON f.id = mso.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE mso.category_code = 'TOTAL'
  AND mso.scope = 'TOTAL';

-- ---------------------------------------------------------------------------
-- notices_by_category  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f   ON f.id = a16.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = a16.category_code
WHERE a16.category_code != 'TOTAL';

-- ---------------------------------------------------------------------------
-- trusted_flagger_intensity  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f   ON f.id = a16.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = a16.category_code;

-- ---------------------------------------------------------------------------
-- notice_response_times  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f   ON f.id = a16.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = a16.category_code;

-- ---------------------------------------------------------------------------
-- moderation_volume_comparison  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f   ON f.id = oii.filing_id
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
JOIN current_filings   f   ON f.id = oitc.filing_id
JOIN providers p   ON p.id = f.provider_id
LEFT JOIN categories cat ON cat.code = oitc.category_code;

-- ---------------------------------------------------------------------------
-- internal_complaints_summary  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE i.source_file = '07_Appeals.csv'
  AND i.section = 'Internal complaints mechanism'
GROUP BY p.slug, p.name, f.period_label, i.indicator;

-- ---------------------------------------------------------------------------
-- out_of_court_disputes  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE i.source_file = '07_Appeals.csv'
  AND i.section = 'Out-of-court dispute settlement bodies'
GROUP BY p.slug, p.name, f.period_label;

-- ---------------------------------------------------------------------------
-- misuse_suspensions  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
WHERE i.source_file = '07_Appeals.csv'
  AND i.section = 'Suspensions imposed on repeated offenders'
GROUP BY p.slug, p.name, f.period_label;

-- ---------------------------------------------------------------------------
-- human_moderators_by_language  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
JOIN current_filings   f ON f.id = i.filing_id
JOIN providers p ON p.id = f.provider_id
LEFT JOIN language_codes lc ON lc.code = normalise_language(i.scope)
WHERE i.source_file = '09_A422AB_Human.csv'
  AND i.indicator   = 'Number of total moderators with sufficient linguistic expertise';

-- ---------------------------------------------------------------------------
-- disclosure_coverage  (repointed to current_filings)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW disclosure_coverage AS
 WITH key_disclosures AS (
         SELECT p.slug AS provider_slug,
            p.name AS provider_name,
            'Art. 15(1)(a)'::text AS article_reference,
            'Article 9 orders received (total)'::text AS disclosure_label,
            mso.orders_act_received IS NOT NULL AND mso.orders_act_received >= 0::numeric AS is_reported,
            mso.orders_act_received AS value_if_reported
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN member_state_orders mso ON mso.filing_id = f.id AND mso.scope = 'TOTAL'::text AND mso.category_code = 'TOTAL'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 15(1)(a)'::text,
            'Article 10 orders received (total)'::text,
            mso.orders_info_received IS NOT NULL AND mso.orders_info_received >= 0::numeric,
            mso.orders_info_received
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN member_state_orders mso ON mso.filing_id = f.id AND mso.scope = 'TOTAL'::text AND mso.category_code = 'TOTAL'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 15(1)(b)'::text,
            'Article 16 notices received (total)'::text,
            a16.notices_received IS NOT NULL AND a16.notices_received >= 0::numeric,
            a16.notices_received
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN article16_notices a16 ON a16.filing_id = f.id AND a16.category_code = 'TOTAL'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 22'::text,
            'Trusted Flagger notices received (total)'::text,
            a16.notices_received_tf IS NOT NULL AND a16.notices_received_tf >= 0::numeric,
            a16.notices_received_tf
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN article16_notices a16 ON a16.filing_id = f.id AND a16.category_code = 'TOTAL'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 15(1)(c)'::text,
            'Own-initiative actions against illegal content (total)'::text,
            oii.measures_total IS NOT NULL AND oii.measures_total >= 0::numeric,
            oii.measures_total
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN own_initiative_illegal oii ON oii.filing_id = f.id AND oii.category_code = 'TOTAL'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 15(1)(d)'::text,
            'Own-initiative actions against ToS violations (total)'::text,
            oitc.measures_total IS NOT NULL AND oitc.measures_total >= 0::numeric,
            oitc.measures_total
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN own_initiative_tc oitc ON oitc.filing_id = f.id AND oitc.category_code = 'TOTAL'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 20'::text,
            'Internal complaints submitted (total)'::text,
            ics.total_complaints IS NOT NULL AND ics.total_complaints >= 0::numeric,
            ics.total_complaints
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN internal_complaints_summary ics ON ics.provider_slug = p.slug AND ics.period_label = f.period_label AND ics.complaint_subject = 'Number of complaints submitted to the internal-complaints mechanism'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 24(1)(a)'::text,
            'Out-of-court disputes — share implemented'::text,
            ocd.share_provider_implemented_pct IS NOT NULL,
            ocd.share_provider_implemented_pct
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN out_of_court_disputes ocd ON ocd.provider_slug = p.slug AND ocd.period_label = f.period_label
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 24(1)(b)'::text,
            'Article 23 suspensions for manifestly illegal content'::text,
            ms.suspensions_for_illegal_content IS NOT NULL,
            ms.suspensions_for_illegal_content
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN misuse_suspensions ms ON ms.provider_slug = p.slug AND ms.period_label = f.period_label
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 42(2)(a)'::text,
            'Total moderator headcount'::text,
            hm.moderators IS NOT NULL AND hm.moderators > 0::numeric,
            hm.moderators
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
             LEFT JOIN human_moderators_by_language hm ON hm.provider_slug = p.slug AND hm.period_label = f.period_label AND hm.language_code = 'total'::text
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 42(3)'::text,
            'AMAR for all 27 EU Member States'::text,
            (( SELECT count(DISTINCT amar.country_code) AS count
                   FROM amar_by_country amar
                  WHERE amar.provider_slug = p.slug AND amar.period_label = f.period_label AND amar.is_eu_member = true)) = 27,
            (( SELECT count(DISTINCT amar.country_code) AS count
                   FROM amar_by_country amar
                  WHERE amar.provider_slug = p.slug AND amar.period_label = f.period_label AND amar.is_eu_member = true))::numeric AS count
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
        UNION ALL
         SELECT p.slug,
            p.name,
            'Art. 42(2)(a)'::text,
            'Moderators reported for all 24 EU official languages'::text,
            (( SELECT count(DISTINCT hm.language_code) AS count
                   FROM human_moderators_by_language hm
                  WHERE hm.provider_slug = p.slug AND hm.period_label = f.period_label AND hm.is_eu_official = true AND hm.moderators > 0::numeric)) = 24,
            (( SELECT count(DISTINCT hm.language_code) AS count
                   FROM human_moderators_by_language hm
                  WHERE hm.provider_slug = p.slug AND hm.period_label = f.period_label AND hm.is_eu_official = true AND hm.moderators > 0::numeric))::numeric AS count
           FROM providers p
             LEFT JOIN current_filings f ON f.provider_id = p.id
        )
 SELECT provider_slug,
    provider_name,
    article_reference,
    disclosure_label,
    is_reported,
    value_if_reported
   FROM key_disclosures
  ORDER BY provider_slug, article_reference, disclosure_label;

-- ---------------------------------------------------------------------------
-- headline_metrics_normalised  (repointed to current_filings)
-- ---------------------------------------------------------------------------
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
       ON a16.filing_id = (SELECT id FROM current_filings f
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
       ON a16.filing_id = (SELECT id FROM current_filings f
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
       ON a16.filing_id = (SELECT id FROM current_filings f
                             WHERE f.provider_id = (SELECT id FROM providers
                                                      WHERE slug = a.provider_slug)
                               AND f.period_label = a.period_label)
      AND a16.category_code = 'TOTAL';

-- ===========================================================================
-- Re-grant (covers the new current_filings view) and reload PostgREST
-- ===========================================================================
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: these should now return ONE row each (the restatement), not two.
--   SELECT provider_slug, period_label, count(*) FROM provider_overview
--   WHERE provider_slug IN ('amazon-store','snapchat') GROUP BY 1,2;
-- And amar_by_country / disclosure_coverage should no longer double Amazon or Snap.
