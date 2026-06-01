-- Migration 032: Relax member_state_orders.scope check constraint to allow
-- synthetic scope markers used for non-conforming provider data.
--
-- Some providers (notably AliExpress in their H2 2025 filing) use scope
-- values like "AT, [_], SE" to mean "across all relevant member states."
-- The original check constraint only permitted TOTAL or 2-letter ISO codes.
-- We extend it to also permit any value beginning with an underscore, which
-- is reserved for our synthetic markers (e.g. _NON_CONFORMING_RANGE).

ALTER TABLE member_state_orders DROP CONSTRAINT member_state_orders_scope_check;

ALTER TABLE member_state_orders ADD CONSTRAINT member_state_orders_scope_check
    CHECK (
        scope = 'TOTAL'
        OR scope ~ '^[A-Z]{2}$'
        OR scope LIKE '\_%'
    );

COMMENT ON CONSTRAINT member_state_orders_scope_check ON member_state_orders IS
    'Scope must be TOTAL, a 2-letter ISO country code, or a synthetic marker '
    'starting with an underscore (used for non-conforming provider data).';
