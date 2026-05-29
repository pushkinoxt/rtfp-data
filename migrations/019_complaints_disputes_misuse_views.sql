-- Migration 019: Three views over indicators for file 07 data.
-- Article 20 DSA (internal complaints), Article 21 DSA (out-of-court disputes),
-- and Article 23 + 24(1)(b) DSA (suspensions for repeated abuse).
--
-- file 07 stores `scope` as the outcome dimension (Total / upheld / reversed
-- / partially reversed / omitted / median time / pct implemented for A21).
-- These three views pivot long → wide via conditional aggregation.

-- ===========================================================================
-- View: internal_complaints_summary
-- Article 20 DSA. One row per (provider × complaint_subject).
-- ===========================================================================

DROP VIEW IF EXISTS internal_complaints_summary CASCADE;

CREATE VIEW internal_complaints_summary AS
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

COMMENT ON VIEW internal_complaints_summary IS
    'Article 20 DSA: internal complaint-handling mechanism volumes and outcomes. '
    'One row per (provider × complaint_subject), where complaint_subject is '
    'either the umbrella indicator ("Number of complaints submitted to the '
    'internal-complaints mechanism") or one of six per-decision-type breakdowns '
    'distinguishing what the original moderation action was. The follow-up '
    'metric "Number of restrictions newly imposed as a result of an internal '
    'complaint" also appears here, with only total_complaints populated.';

-- ===========================================================================
-- View: out_of_court_disputes
-- Article 21 DSA + Article 24(1)(a). One row per provider.
-- ===========================================================================

DROP VIEW IF EXISTS out_of_court_disputes CASCADE;

CREATE VIEW out_of_court_disputes AS
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

COMMENT ON VIEW out_of_court_disputes IS
    'Article 21 DSA + Article 24(1)(a) DSA: disputes submitted to certified '
    'out-of-court dispute settlement bodies (e.g. Appeals Centre Europe), with '
    'outcome breakdown and the politically-loaded share_provider_implemented_pct '
    '— the Article 24(1)(a) metric of "share of disputes where the provider of '
    'the online platform implemented the decisions of the body." One row per '
    'provider per filing.';

-- ===========================================================================
-- View: misuse_suspensions
-- Article 23 DSA + Article 24(1)(b). One row per provider.
-- ===========================================================================

DROP VIEW IF EXISTS misuse_suspensions CASCADE;

CREATE VIEW misuse_suspensions AS
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

COMMENT ON VIEW misuse_suspensions IS
    'Article 23 DSA + Article 24(1)(b) DSA: suspensions imposed on repeat '
    'abusers, distinguishing the three statutory grounds — manifestly illegal '
    'content, manifestly unfounded notices, and manifestly unfounded complaints. '
    'One row per provider per filing. The three-way split is what Article '
    '24(1)(b) specifically requires; tracking divergence between the three '
    'columns lets researchers see which category of abuse each platform '
    'actually enforces against.';
