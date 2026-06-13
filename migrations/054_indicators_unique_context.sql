-- Migration 054: Widen the indicators unique key to include context.
--
-- Files 07-10 are long-format: Section, Indicator, Scope, Value, Contextual
-- Information. The unique key was (filing_id, source_file, section, indicator,
-- scope), which assumes at most one row per (indicator, scope). That holds for
-- most providers, but the adult-content services (XVideos, XNXX, and likely
-- Pornhub) report the accuracy / precision / recall of EACH detection tool they
-- run -- Vercucy, Safer, GoogleSafety, Hive, split by videos vs images -- with the
-- tool named in the Contextual Information column. So one (indicator, scope)
-- legitimately has up to six rows, one per tool. The old key treated five of them
-- as duplicates and the loader dropped them: 289 rows for XVideos, 148 for XNXX,
-- keeping only the first tool. That is real lost data, not redundancy.
--
-- Fix: add context to the unique key so per-tool rows coexist. Verified against
-- the raw file -- (filing, source_file, section, indicator, scope, context) has
-- zero remaining same-key/different-value collisions; the only rows that still
-- drop are a few byte-identical duplicates, which the loader handles.
--
-- The existing rows (one per old key) stay valid under the wider key, so adding it
-- cannot fail on current data. No view reads the section-8 accuracy rows, so no
-- view is affected. After this runs, reload indicators for the affected filings
-- (the loader now dedups on the same wider key) to recover the dropped rows.
-- Idempotent: re-running drops and re-adds the same constraint.

-- Drop whatever unique constraint currently exists on indicators (there is one,
-- the inline key from migration 010), found by lookup so we needn't guess its
-- auto-generated name.
DO $$
DECLARE c record;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'indicators'::regclass AND contype = 'u'
  LOOP
    EXECUTE format('ALTER TABLE indicators DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE indicators
  ADD CONSTRAINT indicators_filing_source_section_indicator_scope_context_key
  UNIQUE (filing_id, source_file, section, indicator, scope, context);

NOTIFY pgrst, 'reload schema';

-- Verify after reloading the affected filings: XVideos's section-8 row count
-- should jump from ~137 to ~423.
--   SELECT p.slug, i.source_file, count(*)
--   FROM indicators i JOIN filings f ON f.id = i.filing_id
--   JOIN providers p ON p.id = f.provider_id
--   WHERE p.slug IN ('xvideos','xnxx','pornhub') AND i.source_file LIKE '08_%'
--   GROUP BY 1,2 ORDER BY 1;
