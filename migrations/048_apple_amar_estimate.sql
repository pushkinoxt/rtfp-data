-- Migration 048: Flag Apple App Store's AMAR figures as estimates.
--
-- Apple reports real per-country AMAR numbers in file 10 but states they are
-- "approximate" (and they are round to the nearest million). This marks all of Apple's
-- AMAR rows value_is_estimate = TRUE so amar_by_country surfaces them as estimates,
-- consistent with the report-24 Google services and Booking's ranges. Wikipedia's AMAR
-- is left exact, since its figures are reported to the thousand (e.g. 155,663,000), not
-- rounded. Run after the Apple load (filing 27). Idempotent.

UPDATE indicators
SET value_is_estimate = TRUE
WHERE filing_id = (SELECT id FROM filings WHERE slug = 'apple-app-store/2025-h2')
  AND source_file = '10_A423_AMAR.csv';

NOTIFY pgrst, 'reload schema';
