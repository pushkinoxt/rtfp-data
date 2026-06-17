-- Migration 065: Record TikTok's empty file 05 as a blank TOTAL row.
--
-- Why: TikTok submitted file 05 (Article 15(1)(c), own-initiative against illegal
-- content) but left every numeric field blank, providing only a qualitative
-- statement in the contextual column of the TOTAL row. The loader skips rows with
-- no numeric measures, so own_initiative_illegal holds no row for TikTok's filing
-- at all. The consequence is that TikTok disappears from the illegal basis of
-- every view built on moderation_volume_comparison (restriction_type_breakdown,
-- automation_share_by_provider, account_actions_summary), so the patterns charts
-- and the public API list 21 providers on the illegal basis and 22 on the
-- terms-and-conditions basis.
--
-- Fix: insert the TOTAL row TikTok actually filed. Measures stay null, because it
-- reported no numbers, and the qualitative statement is preserved in
-- context_measures_total. This is the faithful record: the form was filed, the
-- figures were blank. Because measures_total is NULL, every downstream view reads
-- TikTok-illegal as not reported rather than as a measured zero, which is correct
-- under the Implementing Regulation: a requirement reported without a figure is
-- left blank, and the statement explains the blank.
--
-- disclosure_coverage is unaffected: it already starts from providers and derives
-- is_reported from (measures_total IS NOT NULL AND measures_total >= 0), which
-- stays false. No view definitions change, so no grants or schema reload are
-- needed. This is a pure data correction, idempotent via NOT EXISTS.

INSERT INTO own_initiative_illegal
    (filing_id, category_code, category_label_raw, description_other,
     measures_total, context_measures_total)
SELECT
    f.id,
    'TOTAL',
    NULL,
    NULL,
    NULL,
    'We assess the legality of content where it is reported to us as suspected illegal content, including through user reports, Trusted Flagger notices, or government orders. Outside of these channels, our proactive detection efforts focus on identifying and enforcing violations of our Policies.'
FROM current_filings f
JOIN providers p ON p.id = f.provider_id
WHERE p.slug = 'tiktok'
  AND f.period_label = '2025-h2'
  AND NOT EXISTS (
      SELECT 1 FROM own_initiative_illegal o
      WHERE o.filing_id = f.id
        AND o.category_code = 'TOTAL'
  );

-- Verify: TikTok should now have an illegal row with a null measures_total,
--   SELECT provider_slug, basis, measures_total
--   FROM restriction_type_breakdown
--   WHERE provider_slug = 'tiktok' ORDER BY basis;
-- and both bases should now list 22 providers,
--   SELECT basis, count(*) FROM restriction_type_breakdown GROUP BY basis ORDER BY basis;
