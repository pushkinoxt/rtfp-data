-- Migration 055: platform_notes — surface the platforms' own contextual notes.
--
-- The own_initiative_illegal and own_initiative_tc tables each store 16 paired
-- context_* columns: free-text notes the platform attached to a specific measure
-- (e.g. Google Maps disclosing a reporting error against its service-restriction
-- figures, or noting that advertising metrics are presented separately). These
-- are the platform's OWN words about its OWN data, captured verbatim at load, but
-- nothing has surfaced them yet.
--
-- This view unpivots those columns into one row per non-empty note, keyed by
-- provider, the reporting basis (ToS vs illegal content), the category, and which
-- figure the note annotates. The per-provider page can then list them as the
-- platform's disclosures. RTFP's own (authored) comparability notes are kept
-- entirely separate, in a curated table, so the two are never confused.
--
-- Built on primary_current_filings, so it reflects the current main filing per
-- provider, consistent with the rest of the analytical layer. Idempotent.

CREATE OR REPLACE VIEW platform_notes AS
WITH tos AS (
  SELECT p.slug AS provider_slug,
         p.name AS provider_name,
         f.period_label,
         'Own-initiative (terms of service)'::text AS basis,
         oitc.category_code,
         n.field_label,
         n.note
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
  SELECT p.slug AS provider_slug,
         p.name AS provider_name,
         f.period_label,
         'Own-initiative (illegal content)'::text AS basis,
         oii.category_code,
         n.field_label,
         n.note
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
SELECT provider_slug, provider_name, period_label, basis, category_code, field_label, note
FROM tos
UNION ALL
SELECT provider_slug, provider_name, period_label, basis, category_code, field_label, note
FROM illegal
ORDER BY provider_slug, basis, category_code, field_label;

COMMENT ON VIEW platform_notes IS
    'Contextual notes the platforms attached to their own-initiative figures, '
    'unpivoted from the context_* columns of own_initiative_tc and '
    'own_initiative_illegal. One row per non-empty note, with the basis, category '
    'and annotated figure. These are the platforms own words; RTFP-authored '
    'comparability notes live separately in a curated table.';

GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Verify: Google Maps's two reporting-error disclosures should appear.
--   SELECT basis, category_code, field_label, note FROM platform_notes
--   WHERE provider_slug = 'google-maps';
