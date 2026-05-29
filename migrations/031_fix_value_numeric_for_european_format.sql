-- Migration 031: Fix value_numeric to handle European thousand separators.
--
-- The original generated expression (migration 010) assumed dots were
-- always decimal points and stripped only commas. European-format providers
-- (Snapchat uses dots like "19.845.717") produced NULL in value_numeric.
--
-- This migration drops and re-adds value_numeric with an expression that
-- distinguishes between dots-as-thousand-separators and dots-as-decimals:
--   "1,234,567"     -> strip commas, "1234567" (English thousands)
--   "1.234.567"     -> strip dots,   "1234567" (European thousands, multiple)
--   "6.564"         -> strip dot,    "6564"    (European thousands, single, 3-digit group)
--   "6.5"           -> keep dot,     "6.5"     (decimal — only 1 digit after dot)
--   "1,234.56"      -> strip commas, "1234.56" (US decimal, dots are kept)
--   "TOTAL"         -> NULL (not numeric)
--
-- Generated columns cannot be modified in place; we drop and re-add.
-- The stored TEXT column `value` is untouched, so the new expression
-- recomputes value_numeric for every existing row on creation.

ALTER TABLE indicators DROP COLUMN value_numeric CASCADE;

ALTER TABLE indicators ADD COLUMN value_numeric NUMERIC
    GENERATED ALWAYS AS (
        CASE
            WHEN value IS NULL THEN NULL

            -- Has commas: strip commas, dots are decimals (US/UK convention)
            WHEN value LIKE '%,%' THEN
                CASE
                    WHEN regexp_replace(value, '[,\s]', '', 'g') ~ '^-?\d+(\.\d+)?$'
                        THEN regexp_replace(value, '[,\s]', '', 'g')::NUMERIC
                    ELSE NULL
                END

            -- No commas, multiple dots: European thousands, strip all dots
            WHEN value ~ '\..+\.' THEN
                CASE
                    WHEN regexp_replace(value, '[.\s]', '', 'g') ~ '^-?\d+$'
                        THEN regexp_replace(value, '[.\s]', '', 'g')::NUMERIC
                    ELSE NULL
                END

            -- No commas, exactly one dot followed by exactly 3 digits at end:
            -- European thousands single-grouping (e.g. "6.564")
            WHEN value ~ '^-?\d+\.\d{3}$' THEN
                regexp_replace(value, '[.\s]', '', 'g')::NUMERIC

            -- No commas, plain integer or normal decimal: use as-is
            WHEN regexp_replace(value, '\s', '', 'g') ~ '^-?\d+(\.\d+)?$'
                THEN regexp_replace(value, '\s', '', 'g')::NUMERIC

            ELSE NULL
        END
    ) STORED;

COMMENT ON COLUMN indicators.value_numeric IS
    'Numeric form of value, computed automatically. Handles English '
    'thousand separators (commas), European thousand separators (dots), '
    'and plain decimals. Falls back to NULL for non-numeric values such '
    'as text labels.';
