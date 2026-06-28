-- Migration 070: API guardrails for the public read-only surface
--
-- Two cheap protections on the anonymous PostgREST API so a single runaway or
-- abusive request cannot pin the shared free-tier database or pull the whole
-- dataset in one call. Neither affects the static site, which reads small
-- filtered slices at build time, and neither changes any view, so no site
-- rebuild is needed for these to take effect on the live API.
--
-- This is the separate database flow: run it in the Supabase SQL editor first,
-- then commit this file to rtfp-data.

-- 1. Cap how long any anon or authenticated request may run. Every legitimate
--    read of these small views finishes in well under a second, so a request
--    that runs for several seconds is a sign of abuse and is cut off. This
--    protects the shared CPU.
ALTER ROLE anon SET statement_timeout = '5s';
ALTER ROLE authenticated SET statement_timeout = '5s';

-- 2. Cap the rows returned by a single API response. Bulk consumers should take
--    the static dumps under /data/dumps instead. The build paginates past this
--    cap, and the largest single page the site reads is a few hundred rows, so
--    nothing the site needs is truncated. Applied via the authenticator role
--    with a PostgREST config reload.
--
--    NOTE: confirm this took effect after running it, e.g. request a view with
--    more than 5000 rows and check the response is capped. PostgREST has moved
--    this setting between versions, so if the cap does not apply the
--    statement_timeout above remains the primary guard.
ALTER ROLE authenticator SET pgrst.db_max_rows = '5000';
NOTIFY pgrst, 'reload config';
