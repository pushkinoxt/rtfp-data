-- Migration 049: Seed the adult-content trio (Pornhub, XVideos, XNXX).
--
-- These complete the VLOP list. provider_type 'adult_content' is valid since migration
-- 043. Pornhub and XVideos were designated on 20 December 2023 (second wave); XNXX was
-- designated later, on 10 July 2024 (Commission decision C(2024) 4936). Stripchat is
-- intentionally excluded (de-designated in 2025).
--
-- Legal entities and countries of establishment: Pornhub -> Aylo Freesites Ltd (Cyprus);
-- XVideos -> WebGroup Czech Republic, a.s. (Czechia); XNXX -> NKL Associates s.r.o.
-- (Czechia, Prague). Verify each against the "Name of the service provider" cell in that
-- report's file 01 once loaded and adjust if the filed name differs.

INSERT INTO providers (
    slug, name, legal_entity, service_type, service_category,
    provider_type, designated_on, country_of_establishment
) VALUES
(
    'pornhub', 'Pornhub', 'Aylo Freesites Ltd',
    'VLOP', 'Adult content', 'adult_content', '2023-12-20', 'CY'
),
(
    'xvideos', 'XVideos', 'WebGroup Czech Republic, a.s.',
    'VLOP', 'Adult content', 'adult_content', '2023-12-20', 'CZ'
),
(
    'xnxx', 'XNXX', 'NKL Associates s.r.o.',
    'VLOP', 'Adult content', 'adult_content', '2024-07-10', 'CZ'
);
