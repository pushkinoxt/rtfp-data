-- Migration 027: Capture file 01 metadata fields directly in the filings table.
--
-- File 01 of Annex II is the canonical source for filing-level metadata:
-- provider name, publication dates, reporting-period dates. Until now we
-- hard-coded the publication date when running each loader. This migration
-- adds explicit columns for every file-01 metadata field so future loads
-- pull these straight from the file, eliminating human error.
--
-- This also corrects two existing date errors discovered during the audit:
--   LinkedIn: 28/02/2026 → 26/02/2026 (file 01 value)
--   X:        28/02/2026 → 02/03/2026 (file 01 value)

-- ===========================================================================
-- Add the three new metadata columns
-- ===========================================================================

ALTER TABLE filings
    ADD COLUMN previous_publication_date DATE,
    ADD COLUMN period_start_date         DATE,
    ADD COLUMN period_end_date           DATE;

COMMENT ON COLUMN filings.previous_publication_date IS
    'Per Annex II file 01: date the provider published their previous report. '
    'NULL for first filings or where the provider does not disclose this field. '
    'Useful for measuring publication cadence across periods.';

COMMENT ON COLUMN filings.period_start_date IS
    'Per Annex II file 01: first day of the reporting period. The period_label '
    'column (e.g. "2025-h2") is the human-friendly equivalent; this column is '
    'the precise machine-readable boundary.';

COMMENT ON COLUMN filings.period_end_date IS
    'Per Annex II file 01: last day of the reporting period.';

-- ===========================================================================
-- Backfill existing rows from what we now know is in their file 01
-- ===========================================================================

-- All four H2 2025 filings cover the same period: 1 Jul to 31 Dec 2025.
UPDATE filings
SET period_start_date = '2025-07-01',
    period_end_date   = '2025-12-31',
    previous_publication_date = '2025-08-29';

-- Correct the two wrong publication dates discovered during the audit.
UPDATE filings
SET original_published_on     = '2026-02-26',
    this_version_published_on = '2026-02-26'
WHERE provider_id = (SELECT id FROM providers WHERE slug = 'linkedin');

UPDATE filings
SET original_published_on     = '2026-03-02',
    this_version_published_on = '2026-03-02'
WHERE provider_id = (SELECT id FROM providers WHERE slug = 'x');

-- ===========================================================================
-- Now require the period dates to always be present going forward
-- ===========================================================================

ALTER TABLE filings
    ALTER COLUMN period_start_date SET NOT NULL,
    ALTER COLUMN period_end_date   SET NOT NULL;

-- previous_publication_date stays nullable: a provider's first filing has
-- no previous filing, so NULL is a meaningful value here.
