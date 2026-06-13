-- Migration 057: Complete platform_notes — add appeals/human/AMAR notes, and
-- return DISTINCT notes so repeated cells collapse.
--
-- Two changes over migration 056:
--
-- 1. Coverage. The indicators files 07 (appeals, complaints & disputes), 09 (human
--    resources) and 10 (AMAR) carry genuine free-text notes in indicators.context
--    -- e.g. a provider explaining it reports decisions received because it cannot
--    track disputes submitted, or that a given appeal count includes duplicates.
--    These are folded in. File 08 is deliberately excluded: its context column
--    holds detection-tool names (Vercucy, Safer, ...), which are a breakdown
--    dimension of the accuracy metrics, not notes, and belong in a future
--    accuracy-by-tool view.
--
-- 2. De-duplication. Platforms attach the same note to every (category, country)
--    row, so the previous view returned a note once per row -- 693 "rows" for
--    government orders, most of them the same few sentences repeated. The view now
--    returns DISTINCT (provider, basis, field, note), so each distinct note shows
--    once. The raw per-row cells remain in the base tables for anyone who wants
--    them. category_code is dropped from the output, since a note repeated across
--    categories should collapse to one; the note text carries any specificity.
--
-- This recreates the view with a changed column set (category_code removed), so it
-- is DROP + CREATE rather than CREATE OR REPLACE. No other view depends on it.
-- Idempotent.

DROP VIEW IF EXISTS platform_notes;

CREATE VIEW platform_notes AS
WITH orders AS (
  SELECT p.slug AS provider_slug, p.name AS provider_name, f.period_label,
         'Government orders'::text AS basis, n.field_label, n.note
  FROM member_state_orders mso
  JOIN primary_current_filings f ON f.id = mso.filing_id
  JOIN providers p ON p.id = f.provider_id
  CROSS JOIN LATERAL (VALUES
    ('Article 9 orders received',                     mso.context_orders_act_received),
    ('Article 9: items in orders',                    mso.context_items_in_orders_act),
    ('Article 9: median time to inform of receipt',   mso.context_median_time_inform_receipt_act),
    ('Article 9: median time to give effect',         mso.context_median_time_give_effect_act),
    ('Article 10 orders received',                    mso.context_orders_info_received),
    ('Article 10: median time to inform of receipt',  mso.context_median_time_inform_receipt_info),
    ('Article 10: median time to give effect',        mso.context_median_time_give_effect_info)
  ) AS n(field_label, note)
  WHERE n.note IS NOT NULL AND btrim(n.note) <> ''
),
notices AS (
  SELECT p.slug AS provider_slug, p.name AS provider_name, f.period_label,
         'Article 16 notices'::text AS basis, n.field_label, n.note
  FROM article16_notices a16
  JOIN primary_current_filings f ON f.id = a16.filing_id
  JOIN providers p ON p.id = f.provider_id
  CROSS JOIN LATERAL (VALUES
    ('Notices received',                              a16.context_notices_received),
    ('Notices received (Trusted Flaggers)',           a16.context_notices_received_tf),
    ('Items in notices',                              a16.context_items_in_notices),
    ('Items in notices (Trusted Flaggers)',           a16.context_items_in_notices_tf),
    ('Median time to action',                         a16.context_median_time_to_action),
    ('Median time to action (Trusted Flaggers)',      a16.context_median_time_to_action_tf),
    ('Actions on the basis of law',                   a16.context_actions_basis_law),
    ('Actions on the basis of law (Trusted Flaggers)',a16.context_actions_basis_law_tf),
    ('Actions on the basis of terms',                 a16.context_actions_basis_tc),
    ('Actions on the basis of terms (Trusted Flaggers)', a16.context_actions_basis_tc_tf)
  ) AS n(field_label, note)
  WHERE n.note IS NOT NULL AND btrim(n.note) <> ''
),
tos AS (
  SELECT p.slug AS provider_slug, p.name AS provider_name, f.period_label,
         'Own-initiative (terms of service)'::text AS basis, n.field_label, n.note
  FROM own_initiative_tc oitc
  JOIN primary_current_filings f ON f.id = oitc.filing_id
  JOIN providers p ON p.id = f.provider_id
  CROSS JOIN LATERAL (VALUES
    ('Measures (total)',                          oitc.context_measures_total),
    ('Measures solely automated',                 oitc.context_measures_solely_automated),
    ('Visibility restriction: removal',           oitc.context_vis_removal),
    ('Visibility restriction: disable',           oitc.context_vis_disable),
    ('Visibility restriction: demote',            oitc.context_vis_demoted),
    ('Visibility restriction: age-restrict',      oitc.context_vis_age_restricted),
    ('Visibility restriction: limit interaction', oitc.context_vis_interaction_restricted),
    ('Visibility restriction: label',             oitc.context_vis_labelled),
    ('Visibility restriction: other',             oitc.context_vis_other),
    ('Monetary restriction: suspension',          oitc.context_mon_suspension),
    ('Monetary restriction: termination',         oitc.context_mon_termination),
    ('Monetary restriction: other',               oitc.context_mon_other),
    ('Service restriction: suspension',           oitc.context_svc_suspension),
    ('Service restriction: termination',          oitc.context_svc_termination),
    ('Account restriction: suspension',           oitc.context_acc_suspension),
    ('Account restriction: termination',          oitc.context_acc_termination)
  ) AS n(field_label, note)
  WHERE n.note IS NOT NULL AND btrim(n.note) <> ''
),
illegal AS (
  SELECT p.slug AS provider_slug, p.name AS provider_name, f.period_label,
         'Own-initiative (illegal content)'::text AS basis, n.field_label, n.note
  FROM own_initiative_illegal oii
  JOIN primary_current_filings f ON f.id = oii.filing_id
  JOIN providers p ON p.id = f.provider_id
  CROSS JOIN LATERAL (VALUES
    ('Measures (total)',                          oii.context_measures_total),
    ('Measures solely automated',                 oii.context_measures_solely_automated),
    ('Visibility restriction: removal',           oii.context_vis_removal),
    ('Visibility restriction: disable',           oii.context_vis_disable),
    ('Visibility restriction: demote',            oii.context_vis_demoted),
    ('Visibility restriction: age-restrict',      oii.context_vis_age_restricted),
    ('Visibility restriction: limit interaction', oii.context_vis_interaction_restricted),
    ('Visibility restriction: label',             oii.context_vis_labelled),
    ('Visibility restriction: other',             oii.context_vis_other),
    ('Monetary restriction: suspension',          oii.context_mon_suspension),
    ('Monetary restriction: termination',         oii.context_mon_termination),
    ('Monetary restriction: other',               oii.context_mon_other),
    ('Service restriction: suspension',           oii.context_svc_suspension),
    ('Service restriction: termination',          oii.context_svc_termination),
    ('Account restriction: suspension',           oii.context_acc_suspension),
    ('Account restriction: termination',          oii.context_acc_termination)
  ) AS n(field_label, note)
  WHERE n.note IS NOT NULL AND btrim(n.note) <> ''
),
indicator_notes AS (
  SELECT p.slug AS provider_slug, p.name AS provider_name, f.period_label,
         CASE i.source_file
           WHEN '07_Appeals.csv'        THEN 'Complaints, appeals & disputes'
           WHEN '09_A422AB_Human.csv'   THEN 'Human resources'
           WHEN '10_A423_AMAR.csv'      THEN 'Active monthly recipients'
         END AS basis,
         i.indicator AS field_label,
         i.context   AS note
  FROM indicators i
  JOIN primary_current_filings f ON f.id = i.filing_id
  JOIN providers p ON p.id = f.provider_id
  WHERE i.source_file IN ('07_Appeals.csv','09_A422AB_Human.csv','10_A423_AMAR.csv')
    AND i.context IS NOT NULL AND btrim(i.context) <> ''
)
SELECT DISTINCT provider_slug, provider_name, period_label, basis, field_label, note
FROM (
  SELECT * FROM orders
  UNION ALL SELECT * FROM notices
  UNION ALL SELECT * FROM tos
  UNION ALL SELECT * FROM illegal
  UNION ALL SELECT * FROM indicator_notes
) all_notes
ORDER BY provider_slug, basis, field_label, note;

COMMENT ON VIEW platform_notes IS
    'Distinct contextual notes the platforms wrote into their own filings, gathered '
    'from the context columns of files 03-07, 09 and 10 (orders, notices, '
    'own-initiative, appeals/complaints/disputes, human resources, AMAR). The '
    'platforms own words about their own figures. File 08 (detection-tool accuracy) '
    'and file 11 (Article 42 narratives) are surfaced separately. RTFP-authored '
    'comparability notes live in a separate curated table.';

GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: distinct-note counts, now collapsed, and the full per-provider spread.
--   SELECT basis, count(*) FROM platform_notes GROUP BY 1 ORDER BY 2 DESC;
--   SELECT provider_slug, count(*) FROM platform_notes GROUP BY 1 ORDER BY 2 DESC;
