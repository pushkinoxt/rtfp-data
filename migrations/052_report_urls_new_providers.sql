-- Migration 052: Populate filings.report_url for every provider/filing added or
-- re-loaded since migration 034.
--
-- 034 set report_url for the original twelve, but: (a) ten providers have been
-- added since (Booking, the four Google services, Apple, Wikipedia, and the adult
-- trio), and (b) Amazon and Snap gained new filing rows when their restatements
-- were loaded -- and load_filing.py does not set report_url -- so Amazon v2 and
-- both of Snap's reloaded filings are currently NULL. This migration covers all of
-- them.
--
-- Like 034, it is keyed on provider slug + period_label, so it applies to EVERY
-- filing for that provider/period: main and ad services (the Google providers),
-- and every version (Amazon and Snap both get their landing-page URL on v1 and v2).
-- Version-specific document URLs for the restatements can be set later if wanted;
-- for now both versions share the same transparency landing page.
--
-- The original ten providers whose filings did NOT change (TikTok, Instagram,
-- Facebook, LinkedIn, X, Pinterest, Shein, Temu, Zalando, AliExpress) keep their
-- 034 URLs untouched and are intentionally not repeated here.
--
-- Sources-page caveats are derived on the page, not stored: a link that downloads
-- a file directly is identifiable by its extension (Booking's .zip, Wikipedia's
-- .xls), and an adult-content destination is exactly provider_type =
-- 'adult_content' (Pornhub, XVideos, XNXX). The EC's own index carries the same
-- two notes. Idempotent.

UPDATE filings f
SET report_url = v.url
FROM providers p,
     (VALUES
        -- Providers added since 034
        ('booking',         'https://q-xx.bstatic.com/data/mobile/DSA_Transparency_Report_-_6th_report_-_27_February_2026.zip'),
        ('google-shopping', 'https://transparencyreport.google.com/?hl=en'),
        ('youtube',         'https://transparencyreport.google.com/?hl=en'),
        ('google-play',     'https://transparencyreport.google.com/?hl=en'),
        ('google-maps',     'https://transparencyreport.google.com/?hl=en'),
        ('apple-app-store', 'https://www.apple.com/legal/dsa/'),
        ('wikipedia',       'https://foundation.wikimedia.org/wiki/File:Wikipedia_-_DSA_transparency_report_2026-02-28.xls'),
        ('pornhub',         'https://help.pornhub.com/hc/en-us/sections/46212654665363-DSA-Transparency-Reports'),
        ('xvideos',         'https://info.xvideos.net/legal/mandatory-information'),
        ('xnxx',            'https://info.xnxx.com/legal/mandatory-information'),
        -- Re-covered because their restatements added NULL-url filing rows after 034
        ('amazon-store',    'https://trustworthyshopping.aboutamazon.com/resources/digital-services-act-dsa'),
        ('snapchat',        'https://values.snap.com/privacy/transparency/european-union-h2-2025?lang=en-GB')
     ) AS v(slug, url)
WHERE p.slug = v.slug
  AND f.provider_id = p.id
  AND f.period_label = '2025-h2';

-- Verify: no H2 2025 filing should have a NULL report_url after this runs.
--   SELECT p.slug, f.slug AS filing, f.version_number, f.report_url
--   FROM filings f JOIN providers p ON p.id = f.provider_id
--   WHERE f.period_label = '2025-h2' AND f.report_url IS NULL
--   ORDER BY p.slug, f.version_number;
--   -> expect zero rows
