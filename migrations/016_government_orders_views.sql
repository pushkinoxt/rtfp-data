-- Migration 016: Three views over member_state_orders for Phase C.
-- Article 15(1)(a) DSA + Articles 9 and 10 DSA: orders received from
-- Member State authorities, with response-time medians.
--
-- Source data is a three-dimensional cube (provider × country × category),
-- but providers only populate the marginals — (country, all categories) and
-- (category, all countries). The grand total is the (TOTAL, TOTAL) row.
-- These three views expose each marginal as a separate friendly endpoint.

-- ===========================================================================
-- View: government_orders_by_country
-- One row per (provider × Member State). Categories summed.
-- ===========================================================================

DROP VIEW IF EXISTS government_orders_by_country CASCADE;

CREATE VIEW government_orders_by_country AS
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

COMMENT ON VIEW government_orders_by_country IS
    'Article 15(1)(a) DSA: orders from Member State authorities, broken down '
    'by Member State, summed across all content categories. Each row is one '
    '(provider × country). Columns covering Article 9 (orders to act against '
    'illegal content) are prefixed orders_act_; Article 10 (orders to provide '
    'information) are orders_info_. Time medians are in the unit each provider '
    'disclosed (typically hours); units may vary — see methodology notes.';

-- ===========================================================================
-- View: government_orders_by_category
-- One row per (provider × content category). Member States summed.
-- ===========================================================================

DROP VIEW IF EXISTS government_orders_by_category CASCADE;

CREATE VIEW government_orders_by_category AS
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

COMMENT ON VIEW government_orders_by_category IS
    'Article 15(1)(a) DSA: orders from Member State authorities, broken down '
    'by content category, summed across all Member States. Each row is one '
    '(provider × category_code × parent). The parent_label_raw column preserves '
    'the "Category 10e"-style parent disambiguation needed because KEYWORD_OTHER '
    'appears under multiple parents — without it, a JOIN to categories would '
    'collapse them. Time medians not included here; they are dimensionally a '
    'country attribute, not a category one.';

-- ===========================================================================
-- View: government_orders_summary
-- One row per (provider × filing). Grand totals.
-- ===========================================================================

DROP VIEW IF EXISTS government_orders_summary CASCADE;

CREATE VIEW government_orders_summary AS
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

COMMENT ON VIEW government_orders_summary IS
    'Article 15(1)(a) DSA: one row per (provider × filing) with grand totals '
    'across all Member States and all categories, plus median response times. '
    'This is the headline number for "how many government orders did each '
    'platform receive this period."';
