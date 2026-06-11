-- Migration 038: Mark estimated / banded / threshold values, so they are never
-- presented as exact figures.
--
-- Several providers disclose audience and volume figures as bands or thresholds
-- rather than exact counts:
--   Google:  AMAR reported per country as "100,000", "1,100,000", "< 10,000"
--            (rounded bands), in a separate MAR report.
--   Booking: AMAR reported as "> 45" (a threshold, in millions).
-- The generated value_numeric column will happily parse "100,000" to 100000,
-- which would imply a precision the provider explicitly avoided. This flag lets
-- us store the value exactly as reported while signalling that value_numeric
-- (where non-NULL) is a band/threshold, not an exact figure. Consumers and
-- views can then surface the band and exclude it from precise comparisons.
--
-- Existing rows are exact by definition, so the default is FALSE and no backfill
-- of existing data is needed. The banded AMAR rows themselves are inserted by a
-- follow-up migration with this flag set TRUE.

ALTER TABLE indicators
    ADD COLUMN value_is_estimate BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN indicators.value_is_estimate IS
    'TRUE when the reported value is a band, threshold or rounded estimate '
    '(e.g. Google''s "100,000" or Booking''s "> 45") rather than an exact figure. '
    'When TRUE, value_numeric (if non-NULL) must not be treated as precise.';
