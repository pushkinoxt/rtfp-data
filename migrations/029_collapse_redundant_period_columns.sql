-- Migration 029: Collapse redundant period columns introduced in 027.
--
-- Migration 004 already defined period_start / period_end. Migration 027
-- mistakenly added period_start_date / period_end_date duplicating them.
-- This migration copies any values across to the original columns (in case
-- 027's backfill set values 004's columns lacked), then drops the duplicates.
-- previous_publication_date (also added in 027) is genuinely new and stays.

-- Ensure the canonical columns hold the values (idempotent — they should
-- already match, since both were backfilled to the same H2 2025 dates).
UPDATE filings
SET period_start = COALESCE(period_start, period_start_date),
    period_end   = COALESCE(period_end,   period_end_date)
WHERE period_start_date IS NOT NULL;

-- Drop the duplicates.
ALTER TABLE filings
    DROP COLUMN period_start_date,
    DROP COLUMN period_end_date;
