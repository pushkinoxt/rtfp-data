-- Migration 068: Reclassify TikTok from "Video sharing" to "Social media".
--
-- service_category is RTFP's own grouping, not a field from any filing. TikTok
-- was seeded as "Video sharing" in migration 001 ("first VLOP we'll be loading
-- data for"); on reflection it sits better with the social platforms. This
-- leaves YouTube as the sole "Video sharing" provider, which is intended.
--
-- One row. provider_overview and the grouped listings on About and the platform
-- page pick it up on the next build. "Social media" is already an allowed value
-- in the service_category check constraint.

UPDATE providers
SET service_category = 'Social media'
WHERE slug = 'tiktok';

-- Verify:
--   SELECT slug, name, service_category FROM providers
--   WHERE service_category = 'Video sharing' OR slug = 'tiktok'
--   ORDER BY service_category, slug;
