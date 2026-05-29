-- Migration 012: Allow filings without a "Category label" CSV column
-- (Robust version: finds existing unique constraints by table rather
-- than by hard-coded name, so it works regardless of Postgres truncation.)

DO $$
DECLARE
    tbl TEXT;
    cons_name TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['member_state_orders', 'article16_notices', 'own_initiative_tc']
    LOOP
        -- Drop NOT NULL on the column
        EXECUTE format('ALTER TABLE %I ALTER COLUMN category_label_raw DROP NOT NULL', tbl);

        -- Find and drop the existing unique constraint (the one we care about
        -- is the only multi-column UNIQUE on these tables besides the PK).
        FOR cons_name IN
            SELECT conname
            FROM pg_constraint
            WHERE conrelid = tbl::regclass
              AND contype = 'u'
        LOOP
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', tbl, cons_name);
        END LOOP;
    END LOOP;
END $$;

-- Now add the new unique constraints, each with NULLS NOT DISTINCT.

ALTER TABLE member_state_orders
    ADD CONSTRAINT member_state_orders_uniq
        UNIQUE NULLS NOT DISTINCT (filing_id, category_label_raw, category_code, scope);

ALTER TABLE article16_notices
    ADD CONSTRAINT article16_notices_uniq
        UNIQUE NULLS NOT DISTINCT (filing_id, category_label_raw, category_code);

ALTER TABLE own_initiative_tc
    ADD CONSTRAINT own_initiative_tc_uniq
        UNIQUE NULLS NOT DISTINCT (filing_id, category_label_raw, category_code);
