-- Migration 043: widen provider_type to five buckets.
--
-- provider_type was constrained to ('social_network', 'marketplace') in migration
-- 028. The remaining VLOPs need three more buckets: 'app_store' (Google Play, Apple
-- App Store), 'adult_content' (Pornhub, XNXX, XVideos) and 'other' (Google Maps,
-- Wikipedia). This swaps the CHECK for the widened set. Existing rows are unaffected
-- (their two values remain valid). The finer service_category column is untouched; it
-- already permits the precise labels ('App store', 'Adult content', 'Knowledge', etc.).

ALTER TABLE providers
    DROP CONSTRAINT providers_type_check;

ALTER TABLE providers
    ADD CONSTRAINT providers_type_check
    CHECK (provider_type IN (
        'social_network',
        'marketplace',
        'app_store',
        'adult_content',
        'other'
    ));

COMMENT ON COLUMN providers.provider_type IS
    'High-level platform bucket driving site grouping and what is compared against '
    'what. One of: social_network (user-to-user content moderation dominates), '
    'marketplace (seller/product moderation), app_store (app review/removals), '
    'adult_content (adult video platforms), other (services that compare to nothing '
    'else cleanly, e.g. Maps, Wikipedia). The finer service_category column carries '
    'the precise descriptor.';
