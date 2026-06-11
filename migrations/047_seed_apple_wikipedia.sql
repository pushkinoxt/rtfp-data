-- Migration 047: Seed Apple App Store (app_store) and Wikipedia (other).
--
-- Both were designated in the first VLOP wave on 25 April 2023. provider_type values
-- are valid since migration 043. Unlike the Google services, each is a single service
-- (no _Ads files) and reports real per-country AMAR numbers directly in file 10, so no
-- report-24 backfill is needed; Apple's are self-described as approximate (flagged as
-- estimates after loading), Wikipedia's are precise.
--
-- Apple's legal entity is Apple Distribution International Limited (Ireland). Wikipedia
-- is run by the Wikimedia Foundation (United States), a volunteer-moderated non-profit,
-- so its employed-moderator count (17) reflects only Foundation staff, not the
-- community that does most moderation; downstream per-moderator views will read that
-- way and should be read with that caveat. service_category uses existing labels
-- ('App store'; 'Knowledge' for Wikipedia).

INSERT INTO providers (
    slug, name, legal_entity, service_type, service_category,
    provider_type, designated_on, country_of_establishment
) VALUES
(
    'apple-app-store', 'Apple App Store', 'Apple Distribution International Limited',
    'VLOP', 'App store', 'app_store', '2023-04-25', 'IE'
),
(
    'wikipedia', 'Wikipedia', 'Wikimedia Foundation',
    'VLOP', 'Knowledge', 'other', '2023-04-25', 'US'
);
