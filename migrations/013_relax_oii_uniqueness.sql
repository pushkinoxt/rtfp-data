-- Migration 013: Align own_initiative_illegal with the other wide-format tables.
-- The Annex II hierarchy means leaf codes (KEYWORD_OTHER especially) can recur
-- under multiple parents within a single filing. The unique constraint must
-- include the parent label to disambiguate them.

DO $$
DECLARE
    cons_name TEXT;
BEGIN
    -- Ensure category_label_raw exists and is nullable (it's already nullable from migration 008)
    EXECUTE 'ALTER TABLE own_initiative_illegal ALTER COLUMN category_label_raw DROP NOT NULL';

    -- Drop the existing unique constraint, whatever its auto-generated name is
    FOR cons_name IN
        SELECT conname FROM pg_constraint
        WHERE conrelid = 'own_initiative_illegal'::regclass AND contype = 'u'
    LOOP
        EXECUTE format('ALTER TABLE own_initiative_illegal DROP CONSTRAINT %I', cons_name);
    END LOOP;
END $$;

ALTER TABLE own_initiative_illegal
    ADD CONSTRAINT own_initiative_illegal_uniq
        UNIQUE NULLS NOT DISTINCT (filing_id, category_label_raw, category_code);
