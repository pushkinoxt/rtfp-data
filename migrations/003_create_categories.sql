-- Migration 003: Create the categories table
-- The closed taxonomy from Annex II of Implementing Regulation (EU) 2024/2835.
-- Aligned with the DSA Transparency Database category list.

DROP TABLE IF EXISTS categories CASCADE;

CREATE TABLE categories (
    code            TEXT PRIMARY KEY,
    label           TEXT NOT NULL,
    description     TEXT,
    parent_code     TEXT REFERENCES categories(code),
    sort_order      INTEGER,
    is_total        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE categories IS
    'Closed taxonomy of content moderation categories from Annex II of '
    'Implementing Regulation (EU) 2024/2835. Used by VLOPs to classify '
    'both illegal content and terms-of-service violations.';

COMMENT ON COLUMN categories.code IS
    'The harmonised code, e.g. STATEMENT_CATEGORY_ANIMAL_WELFARE. Stable across reports.';
COMMENT ON COLUMN categories.label IS
    'Human-readable name, e.g. "Animal welfare". Suitable for display.';
COMMENT ON COLUMN categories.parent_code IS
    'Self-reference for sub-categories. NULL for top-level categories.';
COMMENT ON COLUMN categories.is_total IS
    'TRUE only for the synthetic TOTAL row used to represent aggregate values.';

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
