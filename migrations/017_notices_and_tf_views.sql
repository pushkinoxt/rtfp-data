-- Migration 017: Three views over article16_notices for Phase C.
-- Article 15(1)(b) DSA + Article 22 DSA: notices submitted via the Article 16
-- notice-and-action mechanism, with mandated Trusted Flagger breakdown.
--
-- File 04 has no scope dimension (EU-wide only), so all three views are
-- variations on provider × category × {everything, TF only}.

-- ===========================================================================
-- View: notices_by_category
-- One row per (provider × category). Raw breakdown with TF columns alongside.
-- ===========================================================================

DROP VIEW IF EXISTS notices_by_category CASCADE;

CREATE VIEW notices_by_category AS
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

COMMENT ON VIEW notices_by_category IS
    'Article 15(1)(b) DSA: notices submitted via the Article 16 mechanism, '
    'with the Article 22 Trusted Flagger breakdown alongside. One row per '
    '(provider × category × parent). Columns with the _tf suffix cover '
    'Trusted Flagger notices only; the unsuffixed columns cover ALL notices '
    'including TF ones (per the Annex II template definition). Use '
    'trusted_flagger_intensity for the share metric.';

-- ===========================================================================
-- View: trusted_flagger_intensity
-- Per (provider × category) plus a per-provider TOTAL. Computes TF share.
-- ===========================================================================

DROP VIEW IF EXISTS trusted_flagger_intensity CASCADE;

CREATE VIEW trusted_flagger_intensity AS
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

COMMENT ON VIEW trusted_flagger_intensity IS
    'Article 22 DSA: the share of Article 16 notices that come from Trusted '
    'Flaggers — civil society organisations with privileged notice channels. '
    'Per (provider × category) plus a category_code = TOTAL row per provider '
    'giving the overall share. tf_share_pct is a percentage (0–100). NULL '
    'where notices_received is zero or NULL (no denominator). The four '
    'actions_basis_* columns let you compute law-vs-ToS treatment of TF '
    'versus regular notices, which is itself a quality-of-Trusted-Flagger metric.';

-- ===========================================================================
-- View: notice_response_times
-- Focused on the median_time_to_action figures, regular vs TF.
-- ===========================================================================

DROP VIEW IF EXISTS notice_response_times CASCADE;

CREATE VIEW notice_response_times AS
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

COMMENT ON VIEW notice_response_times IS
    'Article 15(1)(b) DSA: median time to take action on Article 16 notices, '
    'regular and Trusted Flagger separately, in whatever unit the provider '
    'disclosed (typically hours; units may vary). tf_to_regular_ratio < 1 '
    'means TF notices are actioned faster than regular ones (the regulatory '
    'expectation under Article 22); > 1 means slower (a flag in itself).';
