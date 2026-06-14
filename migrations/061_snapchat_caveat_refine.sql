-- Migration 061: Refine the Snapchat data-gap caveat with verified detail.
--
-- Confirmed against the live data (article16_notices TOTAL row for Snapchat): the two
-- "actions taken on the basis of terms and conditions" columns -- the ordinary count
-- and its Trusted Flagger equivalent -- come in empty (NULL). Snapchat's own contextual
-- note explains why: it reclassified those enforcements into the own-initiative fields
-- to align with the DSA template, so the notices figures show actions taken on the
-- basis of law only. This replaces the draft wording seeded in migration 058 (which
-- referred imprecisely to "four columns").
--
-- Snapchat has a single seeded caveat, so a clean delete-and-reinsert is safe.

DELETE FROM provider_caveats WHERE provider_slug = 'snapchat';

INSERT INTO provider_caveats (provider_slug, category, note, sort_order) VALUES
('snapchat', 'Data gap',
 'Snapchat''s Article 16 notices filing leaves the two "action on the basis of terms and conditions" columns (the ordinary count and its Trusted Flagger equivalent) empty. Per Snapchat''s own note, it reclassified those enforcements into the own-initiative fields to align with the template, so the notices figures show actions taken on the basis of law only.',
 10);

-- Verify:
--   SELECT provider_slug, category, left(note, 60) FROM provider_caveats WHERE provider_slug = 'snapchat';
