-- Migration 034: Populate filings.report_url with each provider's canonical
-- DSA transparency-report location on its own website, for the H2 2025 cycle.
--
-- These URLs are surfaced on the RTFP Sources page as the "Provider's original
-- filing" link, and let any number on the site be checked against the source.
--
-- report_url lives on the FILING, not the provider, because some providers use
-- period-specific URLs (e.g. Snapchat's path names the H2 2025 cycle). The next
-- cycle (H1 2026) will get its own report_url values on its own filing rows.
--
-- Assumes report_url is a column on the filings table (as exposed by the
-- filings_overview view). Keyed on provider slug + period_label so it is safe
-- to re-run and applies to every version of the H2 2025 filing per provider.

UPDATE filings f
SET report_url = v.url
FROM providers p,
     (VALUES
        ('tiktok',       'https://www.tiktok.com/safety/en/transparency/dsa-transparency'),
        ('instagram',    'https://transparency.meta.com/reports/regulatory-transparency-reports/'),
        ('facebook',     'https://transparency.meta.com/reports/regulatory-transparency-reports/'),
        ('linkedin',     'https://www.linkedin.com/help/linkedin/answer/a1678508'),
        ('x',            'https://transparency.x.com/en/reports/dsa-transparency-report'),
        ('snapchat',     'https://values.snap.com/privacy/transparency/european-union-h2-2025?lang=en-GB'),
        ('pinterest',    'https://policy.pinterest.com/en/digital-services-act-transparency'),
        ('amazon-store', 'https://trustworthyshopping.aboutamazon.com/resources/digital-services-act-dsa'),
        ('shein',        'https://eur.shein.com/digital-service-act-a-1994.html'),
        ('temu',         'https://www.temu.com/transparency-center-reports.html'),
        ('zalando',      'https://corporate.zalando.com/en/investor-relations/corporate-governance/transparency-hub'),
        ('aliexpress',   'https://www.aliexpress.com/p/transparencycenter/transparencyReport.html')
     ) AS v(slug, url)
WHERE p.slug = v.slug
  AND f.provider_id = p.id
  AND f.period_label = '2025-h2';

-- Verify: every loaded provider should now have a report_url for H2 2025.
-- Expect 12 rows, none with a NULL url.
--   SELECT p.slug, f.period_label, f.report_url
--   FROM filings f
--   JOIN providers p ON p.id = f.provider_id
--   WHERE f.period_label = '2025-h2'
--   ORDER BY p.slug;
