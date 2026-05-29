-- Migration 021: Two derived cross-cutting metrics computed across base tables.
-- These are the metrics that justify harmonisation: no individual provider
-- reports them, but they're what makes the platforms genuinely comparable.

-- ===========================================================================
-- View: actions_per_user
-- Own-initiative moderation actions normalised by EU AMAR.
-- ===========================================================================

DROP VIEW IF EXISTS actions_per_user CASCADE;

CREATE VIEW actions_per_user AS
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

COMMENT ON VIEW actions_per_user IS
    'Own-initiative moderation volume normalised by EU AMAR. Per (provider × '
    'basis): how many moderation actions per average monthly active EU user '
    'during the period. The denominator is the average count of users in a '
    'given month, not unique users across the period, so a value of 1.0 does '
    'NOT mean "every user got moderated once" — it means actions equal one '
    'monthly headcount-worth. Still, the cross-provider ratio is the more '
    'useful comparison: X actions-per-user vs Instagram actions-per-user '
    'controls for platform size.';

-- ===========================================================================
-- View: amar_per_moderator
-- AMAR divided by total human moderators. Inverse of "moderator density".
-- ===========================================================================

DROP VIEW IF EXISTS amar_per_moderator CASCADE;

CREATE VIEW amar_per_moderator AS
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

COMMENT ON VIEW amar_per_moderator IS
    'EU AMAR divided by total human moderator headcount per Article 42(2)(a). '
    'One row per provider. Higher users_per_moderator means each moderator is '
    'nominally responsible for more EU users — the closest single number to '
    '"is this platform adequately staffed?" Sums across language-row '
    'multilingualism, so providers with multilingual moderators get a slightly '
    'flattering ratio. Useful as a relative comparison rather than an absolute '
    'staffing-adequacy benchmark.';
