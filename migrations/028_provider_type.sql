-- Migration 028: Add provider_type to the providers table.
--
-- RTFP groups providers into "social platforms" (where Article 16 notices,
-- Article 22 Trusted Flaggers, and content-category moderation dominate) and
-- "marketplaces" (where seller-account suspensions and counterfeit-product
-- removals dominate). This column lets every view and page filter or
-- distinguish between the two groups.

ALTER TABLE providers
    ADD COLUMN provider_type TEXT;

-- The four existing providers — TikTok, Instagram, LinkedIn, X — are all
-- social platforms by any reasonable categorisation.
UPDATE providers
SET provider_type = 'social_network'
WHERE slug IN ('tiktok', 'instagram', 'linkedin', 'x');

-- Now lock it down: every provider must be classified.
ALTER TABLE providers
    ALTER COLUMN provider_type SET NOT NULL,
    ADD CONSTRAINT providers_type_check
    CHECK (provider_type IN ('social_network', 'marketplace'));

COMMENT ON COLUMN providers.provider_type IS
    'High-level platform category. social_network for platforms where '
    'user-to-user content moderation dominates (TikTok, Instagram, X, '
    'Facebook, LinkedIn, Snapchat, Pinterest). marketplace for platforms '
    'where seller/product moderation dominates (Amazon, Shein, Temu, '
    'Zalando, AliExpress).';
