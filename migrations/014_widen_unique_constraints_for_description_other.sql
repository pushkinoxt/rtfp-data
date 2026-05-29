-- Migration 014: Widen UNIQUE constraints to include description_other.
-- Some providers (notably X) use the description_other text as a disambiguator
-- between multiple KEYWORD_OTHER rows under the same parent category in a
-- single filing. This is a permissible provider reporting choice under
-- Annex II of 2024/2835. Schema must accommodate it.

DO $$
DECLARE
    tbl TEXT;
    cons_name TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'member_state_orders', 'article16_notices',
        'own_initiative_illegal', 'own_initiative_tc'
    ]
    LOOP
        FOR cons_name IN
            SELECT conname FROM pg_constraint
            WHERE conrelid = tbl::regclass AND contype = 'u'
        LOOP
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', tbl, cons_name);
        END LOOP;
    END LOOP;
END $$;

-- Now add the new wider UNIQUE constraints, each with NULLS NOT DISTINCT.
-- member_state_orders also includes scope (Member State dimension).

ALTER TABLE member_state_orders
    ADD CONSTRAINT member_state_orders_uniq
        UNIQUE NULLS NOT DISTINCT
        (filing_id, category_label_raw, category_code, description_other, scope);

ALTER TABLE article16_notices
    ADD CONSTRAINT article16_notices_uniq
        UNIQUE NULLS NOT DISTINCT
        (filing_id, category_label_raw, category_code, description_other);

ALTER TABLE own_initiative_illegal
    ADD CONSTRAINT own_initiative_illegal_uniq
        UNIQUE NULLS NOT DISTINCT
        (filing_id, category_label_raw, category_code, description_other);

ALTER TABLE own_initiative_tc
    ADD CONSTRAINT own_initiative_tc_uniq
        UNIQUE NULLS NOT DISTINCT
        (filing_id, category_label_raw, category_code, description_other);
