-- Migration 056: Extend platform_notes to government orders and Article 16 notices.
--
-- platform_notes (migration 055) gathered the contextual notes the platforms
-- attached to their own-initiative figures (files 05 and 06). The same paired
-- context_* pattern exists on member_state_orders (file 03: 7 note columns) and
-- article16_notices (file 04: 10 note columns). This recreates the view to gather
-- those as well, so every contextual note across files 03-06 surfaces under its
-- provider, with the same shape and the same "platform's own words" treatment.
--
-- Still NOT covered by this view, by design: the indicators files (07-10), whose
-- single context column is mixed (real notes, but also the detection-tool names
-- for the adult services and the odd sub-value), and the Article 42 narratives in
-- qualitative_indicators, which are long-form answers rather than notes-on-figures.
-- Both are captured in their tables and are the next surfacing steps.
--
-- Same 7-column shape as before, so this is a clean CREATE OR REPLACE. Idempotent.

CREATE OR REPLACE VIEW platform_notes AS
WITH orders AS (
  SELECT p.slug AS provider_slug, p.name AS provider_name, f.period_label,
         'Government orders'::text AS basis, mso.category_code, n.field_label, n.note
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
         'Article 16 notices'::text AS basis, a16.category_code, n.field_label, n.note
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
         'Own-initiative (terms of service)'::text AS basis, oitc.category_code, n.field_label, n.note
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
         'Own-initiative (illegal content)'::text AS basis, oii.category_code, n.field_label, n.note
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
)
SELECT provider_slug, provider_name, period_label, basis, category_code, field_label, note FROM orders
UNION ALL
SELECT provider_slug, provider_name, period_label, basis, category_code, field_label, note FROM notices
UNION ALL
SELECT provider_slug, provider_name, period_label, basis, category_code, field_label, note FROM tos
UNION ALL
SELECT provider_slug, provider_name, period_label, basis, category_code, field_label, note FROM illegal
ORDER BY provider_slug, basis, category_code, field_label;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: the per-provider counts should rise vs the own-initiative-only version.
--   SELECT basis, count(*) FROM platform_notes GROUP BY 1 ORDER BY 2 DESC;
