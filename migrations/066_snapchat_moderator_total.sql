-- 066_snapchat_moderator_total.sql
-- Correct Snapchat's total-moderators figure on its current (restated) filing.
--
-- Filing 36 (snapchat/2025-h2/restated, the current version) stores the total
-- as "1.43". The source figure is the European-format "1.430"; a float
-- round-trip at load dropped the trailing zero, so migration 031's parser read
-- "1.43" as a decimal (1.43) rather than thousands (1430). The original filing
-- (id 35) still carries the correct "1,430", which confirms the real figure is
-- 1,430.
--
-- value_numeric is a generated column and recomputes from `value` automatically,
-- so updating the text is sufficient. This is a data-only change: no view or
-- PostgREST schema reload is needed. Expect "UPDATE 1".

UPDATE indicators i
SET value = '1430'
FROM filings f
JOIN providers p ON p.id = f.provider_id
WHERE i.filing_id = f.id
  AND p.slug = 'snapchat'
  AND i.source_file = '09_A422AB_Human.csv'
  AND i.indicator   = 'Number of total moderators with sufficient linguistic expertise'
  AND lower(trim(i.scope)) IN ('total', 'total number')
  AND trim(i.value) = '1.43';
