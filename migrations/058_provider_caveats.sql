-- Migration 058: provider_caveats — RTFP's own (authored) comparability notes.
--
-- Distinct from platform_notes: those are the platforms' OWN words, surfaced
-- verbatim from the filings. This table holds the small set of notes RTFP writes
-- itself, where we've noticed something about comparability or a data gap that the
-- platform did not state. The two are rendered in clearly separate places on the
-- provider page so they're never mistaken for one another.
--
-- No foreign key on provider_slug (kept deliberately simple for a tiny curated
-- table); slugs must match providers.slug. RLS + read policy + grant follow the
-- same public-read pattern as every other table (migration 023). Idempotent.

DROP TABLE IF EXISTS provider_caveats CASCADE;

CREATE TABLE provider_caveats (
    id              BIGSERIAL PRIMARY KEY,
    provider_slug   TEXT NOT NULL,          -- matches providers.slug
    category        TEXT NOT NULL,          -- short label, e.g. 'Comparability', 'Data gap'
    note            TEXT NOT NULL,          -- RTFP's authored note
    sort_order      INT  NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider_slug, note)
);

COMMENT ON TABLE provider_caveats IS
    'RTFP-authored comparability and data-gap notes, shown on the provider page '
    'under a clearly-separated "RTFP notes" heading. These are RTFPs own words, '
    'NOT the platforms; the platforms own contextual notes are in platform_notes.';

ALTER TABLE provider_caveats ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read provider_caveats" ON provider_caveats;
CREATE POLICY "Public read provider_caveats" ON provider_caveats
    FOR SELECT TO anon, authenticated USING (true);
GRANT SELECT ON provider_caveats TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- Seed: the three caveats we know about. DRAFT WORDING — edit freely before/after.
-- ---------------------------------------------------------------------------
INSERT INTO provider_caveats (provider_slug, category, note, sort_order) VALUES
('wikipedia', 'Comparability',
 'Wikipedia''s reported moderator headcount counts only paid Wikimedia Foundation staff. The volunteer editor community, which carries out the large majority of day-to-day moderation, is not included. The figure therefore understates the number of people moderating the platform and is not comparable to platforms that employ their moderators directly.',
 1),

('snapchat', 'Data gap',
 'Snap''s Article 16 notices filing does not report the breakdown of actions taken on the basis of its terms of service (for both ordinary and Trusted Flagger notices). Those fields are blank in Snap''s filing and so are blank here; this is a gap in the source, not a loading error.',
 1),

('youtube', 'Comparability',
 'Google reports average monthly active recipients per EU member state, split into signed-in accounts and signed-out sessions, and does not publish a single EU total. The headline figure shown here is RTFP''s sum of those per-country counts, not a figure Google stated. Because other platforms report a single deduplicated EU total, this should not be ranked directly against them.',
 1),
('google-play', 'Comparability',
 'Google reports average monthly active recipients per EU member state, split into signed-in accounts and signed-out sessions, and does not publish a single EU total. The headline figure shown here is RTFP''s sum of those per-country counts, not a figure Google stated. Because other platforms report a single deduplicated EU total, this should not be ranked directly against them.',
 1),
('google-maps', 'Comparability',
 'Google reports average monthly active recipients per EU member state, split into signed-in accounts and signed-out sessions, and does not publish a single EU total. The headline figure shown here is RTFP''s sum of those per-country counts, not a figure Google stated. Because other platforms report a single deduplicated EU total, this should not be ranked directly against them.',
 1),
('google-shopping', 'Comparability',
 'Google reports average monthly active recipients per EU member state, split into signed-in accounts and signed-out sessions, and does not publish a single EU total. The headline figure shown here is RTFP''s sum of those per-country counts, not a figure Google stated. Because other platforms report a single deduplicated EU total, this should not be ranked directly against them.',
 1);

NOTIFY pgrst, 'reload schema';

-- Verify:
--   SELECT provider_slug, category, left(note, 60) FROM provider_caveats ORDER BY provider_slug;
