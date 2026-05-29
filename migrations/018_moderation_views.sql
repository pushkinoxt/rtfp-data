-- Migration 018: Four views over own_initiative_illegal + own_initiative_tc.
-- Article 15(1)(c) DSA (own-initiative against illegal content) + Article
-- 15(1)(d) (own-initiative against ToS violations).
--
-- Both source tables contain THREE LEVELS of granularity (TOTAL / parent /
-- keyword) with the same actions counted at each. moderation_volume_comparison
-- exposes a `level` column so queries can pick one. The other three views
-- pre-filter to the TOTAL row to avoid double-counting.

-- ===========================================================================
-- View: moderation_volume_comparison
-- Unions illegal + tc with basis and level columns. Full restriction detail.
-- ===========================================================================

DROP VIEW IF EXISTS moderation_volume_comparison CASCADE;

CREATE VIEW moderation_volume_comparison AS
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

COMMENT ON VIEW moderation_volume_comparison IS
    'Article 15(1)(c) and 15(1)(d) DSA: own-initiative moderation actions, with '
    'a basis column distinguishing illegal-content actions from ToS actions. '
    'IMPORTANT: contains three levels of granularity (total / parent / keyword) '
    'with the same actions counted at each. Filter on level to avoid double-'
    'counting. Note: TikTok H2 2025 contributes no illegal-basis rows because '
    'they filed an empty file 05 — TikTok classifies essentially all '
    'own-initiative action as ToS-based.';

-- ===========================================================================
-- View: automation_share_by_provider
-- Per (provider × basis): share of moderation that was solely automated.
-- ===========================================================================

DROP VIEW IF EXISTS automation_share_by_provider CASCADE;

CREATE VIEW automation_share_by_provider AS
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

COMMENT ON VIEW automation_share_by_provider IS
    'Article 15(1)(c)(e) and 15(1)(d) DSA: percentage of own-initiative '
    'measures that were taken solely by automated means, per provider per basis '
    '(illegal vs ToS). Grand totals only. NULL where measures_total is zero or '
    'NULL (no denominator).';

-- ===========================================================================
-- View: restriction_type_breakdown
-- Per (provider × basis): actions aggregated to the four restriction families.
-- ===========================================================================

DROP VIEW IF EXISTS restriction_type_breakdown CASCADE;

CREATE VIEW restriction_type_breakdown AS
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

COMMENT ON VIEW restriction_type_breakdown IS
    'Annex II Part II restriction taxonomy: own-initiative actions aggregated '
    'into the four mandated families — visibility, monetary, service, account. '
    'The four columns are designed to be non-overlapping per Annex II. Sum of '
    'the four may not equal measures_total because a single measure can '
    'theoretically span multiple families, but in practice provider methodology '
    'varies — divergence between sum and measures_total is itself a finding.';

-- ===========================================================================
-- View: account_actions_summary
-- Per (provider × basis): account-level enforcement, the politically loaded slice.
-- ===========================================================================

DROP VIEW IF EXISTS account_actions_summary CASCADE;

CREATE VIEW account_actions_summary AS
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

COMMENT ON VIEW account_actions_summary IS
    'Annex II Part II account restriction columns: how many EU user accounts '
    'each provider suspended or terminated under its own initiative, split by '
    'basis (illegal vs ToS). The single most politically loaded number in '
    'transparency reporting because it directly measures "platform power over '
    'users".';
