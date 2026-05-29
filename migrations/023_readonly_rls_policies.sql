-- Migration 023: Read-only RLS policies and grants for the public API surface.
-- After this migration runs:
--   anon and authenticated: SELECT on all 10 base tables and all 20 views
--   service_role: unchanged (already bypasses RLS by Supabase default)
--   no role: INSERT, UPDATE, or DELETE access on any table
--
-- This is Phase D of the DSA diff tool — turning the database into a public,
-- read-only REST API via Supabase's built-in PostgREST.

-- ===========================================================================
-- Base table policies — SELECT only, no write
-- ===========================================================================

-- providers
DROP POLICY IF EXISTS "Public read providers" ON providers;
CREATE POLICY "Public read providers" ON providers
    FOR SELECT TO anon, authenticated
    USING (true);

-- filings
DROP POLICY IF EXISTS "Public read filings" ON filings;
CREATE POLICY "Public read filings" ON filings
    FOR SELECT TO anon, authenticated
    USING (true);

-- categories
DROP POLICY IF EXISTS "Public read categories" ON categories;
CREATE POLICY "Public read categories" ON categories
    FOR SELECT TO anon, authenticated
    USING (true);

-- member_state_orders
DROP POLICY IF EXISTS "Public read member_state_orders" ON member_state_orders;
CREATE POLICY "Public read member_state_orders" ON member_state_orders
    FOR SELECT TO anon, authenticated
    USING (true);

-- article16_notices
DROP POLICY IF EXISTS "Public read article16_notices" ON article16_notices;
CREATE POLICY "Public read article16_notices" ON article16_notices
    FOR SELECT TO anon, authenticated
    USING (true);

-- own_initiative_illegal
DROP POLICY IF EXISTS "Public read own_initiative_illegal" ON own_initiative_illegal;
CREATE POLICY "Public read own_initiative_illegal" ON own_initiative_illegal
    FOR SELECT TO anon, authenticated
    USING (true);

-- own_initiative_tc
DROP POLICY IF EXISTS "Public read own_initiative_tc" ON own_initiative_tc;
CREATE POLICY "Public read own_initiative_tc" ON own_initiative_tc
    FOR SELECT TO anon, authenticated
    USING (true);

-- indicators
DROP POLICY IF EXISTS "Public read indicators" ON indicators;
CREATE POLICY "Public read indicators" ON indicators
    FOR SELECT TO anon, authenticated
    USING (true);

-- qualitative_indicators
DROP POLICY IF EXISTS "Public read qualitative_indicators" ON qualitative_indicators;
CREATE POLICY "Public read qualitative_indicators" ON qualitative_indicators
    FOR SELECT TO anon, authenticated
    USING (true);

-- import_anomalies
DROP POLICY IF EXISTS "Public read import_anomalies" ON import_anomalies;
CREATE POLICY "Public read import_anomalies" ON import_anomalies
    FOR SELECT TO anon, authenticated
    USING (true);

-- country_codes
DROP POLICY IF EXISTS "Public read country_codes" ON country_codes;
CREATE POLICY "Public read country_codes" ON country_codes
    FOR SELECT TO anon, authenticated
    USING (true);

-- language_codes
DROP POLICY IF EXISTS "Public read language_codes" ON language_codes;
CREATE POLICY "Public read language_codes" ON language_codes
    FOR SELECT TO anon, authenticated
    USING (true);

-- ===========================================================================
-- Grants — PostgREST needs SELECT explicitly granted before RLS even runs
-- ===========================================================================

GRANT SELECT ON
    providers,
    filings,
    categories,
    member_state_orders,
    article16_notices,
    own_initiative_illegal,
    own_initiative_tc,
    indicators,
    qualitative_indicators,
    import_anomalies,
    country_codes,
    language_codes
TO anon, authenticated;

-- Custom functions used by views
GRANT EXECUTE ON FUNCTION normalise_scope(TEXT)    TO anon, authenticated;
GRANT EXECUTE ON FUNCTION normalise_language(TEXT) TO anon, authenticated;

-- ===========================================================================
-- Revoke writes — defence in depth even though RLS already blocks
-- ===========================================================================

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON
    providers,
    filings,
    categories,
    member_state_orders,
    article16_notices,
    own_initiative_illegal,
    own_initiative_tc,
    indicators,
    qualitative_indicators,
    import_anomalies,
    country_codes,
    language_codes
FROM anon, authenticated;
