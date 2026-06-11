-- Migration 041: AMAR `amar` column = a clean real-counts read of each figure.
--
-- amar_raw stays verbatim. `amar` reproduces the figure in actual recipient counts,
-- leaning on the existing value_numeric generated column rather than re-implementing
-- parsing: value_numeric already handles US commas, European dots (031) and k/M/B
-- suffixes (035, so Temu's "5.4M" -> 5400000). Only Booking is unhandled there,
-- because it reports ranges ("16.4 - 20"), which value_numeric leaves NULL; those are
-- converted from millions to a count range ("16,400,000-20,000,000"). Google's
-- "< X" / "> X" qualifiers, and any other non-numeric value, are kept verbatim as the
-- most precise honest read.
--
-- No data is mutated. `amar` must become text (ranges and qualifiers), and a view
-- column's type cannot be altered in place, so amar_by_country is dropped and
-- recreated. disclosure_coverage reads only its country/provider/period columns and
-- is reproduced verbatim from migration 036, so its behaviour is unchanged.

DROP VIEW IF EXISTS amar_by_country CASCADE;

CREATE VIEW amar_by_country AS
SELECT
    p.slug                          AS provider_slug,
    p.name                          AS provider_name,
    f.period_label                  AS period_label,
    normalise_scope(i.scope)        AS country_code,
    cc.name                         AS country_name,
    cc.is_eu_member                 AS is_eu_member,
    i.value                         AS amar_raw,
    -- `amar` = the figure read in actual recipient counts.
    -- Single values: value_numeric already normalises every notation present in the
    -- data: US commas, European dots (migration 031) and k/M/B suffixes (migration
    -- 035, which already turns Temu's "5.4M" into 5400000). So nothing platform-
    -- specific is needed here; just format value_numeric as a clean count.
    -- Booking is the only provider that reports ranges, and they are in millions, so
    -- its "16.4 - 20" is converted to "16,400,000-20,000,000".
    -- Qualifiers ("< 10,000", "> 45") and anything else are kept verbatim.
    CASE
        WHEN i.value_numeric IS NOT NULL THEN to_char(i.value_numeric, 'FM999,999,999,999')
        WHEN p.slug = 'booking' AND trim(i.value) ~ '^[0-9.]+ *- *[0-9.]+$' THEN
            CASE WHEN trim(split_part(i.value,'-',1)) = trim(split_part(i.value,'-',2))
                 THEN to_char(round(trim(split_part(i.value,'-',1))::numeric * 1000000), 'FM999,999,999,999')
                 ELSE to_char(round(trim(split_part(i.value,'-',1))::numeric * 1000000), 'FM999,999,999,999')
                      || '-' ||
                      to_char(round(trim(split_part(i.value,'-',2))::numeric * 1000000), 'FM999,999,999,999')
            END
        ELSE i.value
    END                             AS amar,
    CASE
        WHEN i.indicator ILIKE '%signed-in%'  THEN 'signed-in accounts'
        WHEN i.indicator ILIKE '%signed-out%' THEN 'signed-out sessions'
        ELSE 'all recipients'
    END                             AS measure,
    i.value_is_estimate             AS is_estimate
FROM indicators i
JOIN filings   f  ON f.id = i.filing_id
JOIN providers p  ON p.id = f.provider_id
LEFT JOIN country_codes cc ON cc.code = normalise_scope(i.scope)
WHERE i.source_file = '10_A423_AMAR.csv'
  AND normalise_scope(i.scope) IS DISTINCT FROM 'total';

CREATE OR REPLACE VIEW disclosure_coverage AS
WITH key_disclosures AS (
    -- A curated list of disclosures Article 15/24/42 either mandates or
    -- treats as primary. Each is a (article_reference, disclosure_label,
    -- source_table, qualifying_expr) tuple realised as a UNION ALL.

    -- ---- Article 15(1)(a) — government orders ----
    SELECT p.slug AS provider_slug, p.name AS provider_name,
           'Art. 15(1)(a)'  AS article_reference,
           'Article 9 orders received (total)' AS disclosure_label,
           (mso.orders_act_received IS NOT NULL AND mso.orders_act_received >= 0) AS is_reported,
           mso.orders_act_received AS value_if_reported
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN member_state_orders mso
           ON mso.filing_id = f.id AND mso.scope = 'TOTAL' AND mso.category_code = 'TOTAL'

    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(a)', 'Article 10 orders received (total)',
           (mso.orders_info_received IS NOT NULL AND mso.orders_info_received >= 0),
           mso.orders_info_received
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN member_state_orders mso
           ON mso.filing_id = f.id AND mso.scope = 'TOTAL' AND mso.category_code = 'TOTAL'

    -- ---- Article 15(1)(b) — Article 16 notices ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(b)', 'Article 16 notices received (total)',
           (a16.notices_received IS NOT NULL AND a16.notices_received >= 0),
           a16.notices_received
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN article16_notices a16
           ON a16.filing_id = f.id AND a16.category_code = 'TOTAL'

    UNION ALL
    SELECT p.slug, p.name,
           'Art. 22',      'Trusted Flagger notices received (total)',
           (a16.notices_received_tf IS NOT NULL AND a16.notices_received_tf >= 0),
           a16.notices_received_tf
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN article16_notices a16
           ON a16.filing_id = f.id AND a16.category_code = 'TOTAL'

    -- ---- Article 15(1)(c) — own initiative against illegal ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(c)','Own-initiative actions against illegal content (total)',
           (oii.measures_total IS NOT NULL AND oii.measures_total >= 0),
           oii.measures_total
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN own_initiative_illegal oii
           ON oii.filing_id = f.id AND oii.category_code = 'TOTAL'

    -- ---- Article 15(1)(d) — own initiative against ToS ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 15(1)(d)','Own-initiative actions against ToS violations (total)',
           (oitc.measures_total IS NOT NULL AND oitc.measures_total >= 0),
           oitc.measures_total
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN own_initiative_tc oitc
           ON oitc.filing_id = f.id AND oitc.category_code = 'TOTAL'

    -- ---- Article 20 — internal complaints ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 20',      'Internal complaints submitted (total)',
           (ics.total_complaints IS NOT NULL AND ics.total_complaints >= 0),
           ics.total_complaints
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN internal_complaints_summary ics
           ON ics.provider_slug = p.slug
          AND ics.period_label  = f.period_label
          AND ics.complaint_subject = 'Number of complaints submitted to the internal-complaints mechanism'

    -- ---- Article 21 / 24(1)(a) — out-of-court disputes ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 24(1)(a)','Out-of-court disputes — share implemented',
           (ocd.share_provider_implemented_pct IS NOT NULL),
           ocd.share_provider_implemented_pct
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN out_of_court_disputes ocd
           ON ocd.provider_slug = p.slug AND ocd.period_label = f.period_label

    -- ---- Article 23 / 24(1)(b) — misuse suspensions ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 24(1)(b)','Article 23 suspensions for manifestly illegal content',
           (ms.suspensions_for_illegal_content IS NOT NULL),
           ms.suspensions_for_illegal_content
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN misuse_suspensions ms
           ON ms.provider_slug = p.slug AND ms.period_label = f.period_label

    -- ---- Article 42(2)(a) — moderator headcount ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 42(2)(a)','Total moderator headcount',
           (hm.moderators IS NOT NULL AND hm.moderators > 0),
           hm.moderators
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
    LEFT JOIN human_moderators_by_language hm
           ON hm.provider_slug = p.slug
          AND hm.period_label  = f.period_label
          AND hm.language_code = 'total'

    -- ---- Article 42(3) — per-Member-State AMAR ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 42(3)',   'AMAR for all 27 EU Member States',
           (
             SELECT COUNT(DISTINCT amar.country_code) FROM amar_by_country amar
             WHERE amar.provider_slug = p.slug
               AND amar.period_label  = f.period_label
               AND amar.is_eu_member  = TRUE
           ) = 27,
           (
             SELECT COUNT(DISTINCT amar.country_code) FROM amar_by_country amar
             WHERE amar.provider_slug = p.slug
               AND amar.period_label  = f.period_label
               AND amar.is_eu_member  = TRUE
           )::numeric
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id

    -- ---- Article 42(2)(a) — moderator coverage of all 24 EU languages ----
    UNION ALL
    SELECT p.slug, p.name,
           'Art. 42(2)(a)','Moderators reported for all 24 EU official languages',
           (
             SELECT COUNT(DISTINCT hm.language_code) FROM human_moderators_by_language hm
             WHERE hm.provider_slug = p.slug
               AND hm.period_label  = f.period_label
               AND hm.is_eu_official = TRUE
               AND hm.moderators > 0
           ) = 24,
           (
             SELECT COUNT(DISTINCT hm.language_code) FROM human_moderators_by_language hm
             WHERE hm.provider_slug = p.slug
               AND hm.period_label  = f.period_label
               AND hm.is_eu_official = TRUE
               AND hm.moderators > 0
           )::numeric
    FROM providers p
    LEFT JOIN filings f ON f.provider_id = p.id
)
SELECT
    provider_slug,
    provider_name,
    article_reference,
    disclosure_label,
    is_reported,
    value_if_reported
FROM key_disclosures
ORDER BY provider_slug, article_reference, disclosure_label;

GRANT SELECT ON amar_by_country, disclosure_coverage TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
