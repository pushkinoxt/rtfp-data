-- Migration 008: Create the own_initiative_illegal table
-- Article 15(1)(c) DSA data: content moderation actions taken by the provider
-- on its own initiative against illegal content.
-- Source CSV: 05_A151C_Own_Illegal.csv per Annex II template.
--
-- NOTE: Unlike files 03/04/06, file 05 does NOT contain a parent "Category label"
-- column. category_label_raw is therefore nullable for this table.

DROP TABLE IF EXISTS own_initiative_illegal CASCADE;

CREATE TABLE own_initiative_illegal (
    id                                          BIGSERIAL PRIMARY KEY,
    filing_id                                   BIGINT NOT NULL
                                                REFERENCES filings(id) ON DELETE CASCADE,

    category_code                               TEXT NOT NULL REFERENCES categories(code),
    category_label_raw                          TEXT,
    description_other                           TEXT,

    measures_total                              NUMERIC,
    measures_solely_automated                   NUMERIC,

    vis_removal                                 NUMERIC,
    vis_disable                                 NUMERIC,
    vis_demoted                                 NUMERIC,
    vis_age_restricted                          NUMERIC,
    vis_interaction_restricted                  NUMERIC,
    vis_labelled                                NUMERIC,
    vis_other                                   NUMERIC,

    mon_suspension                              NUMERIC,
    mon_termination                             NUMERIC,
    mon_other                                   NUMERIC,

    svc_suspension                              NUMERIC,
    svc_termination                             NUMERIC,

    acc_suspension                              NUMERIC,
    acc_termination                             NUMERIC,

    context_measures_total                      TEXT,
    context_measures_solely_automated           TEXT,
    context_vis_removal                         TEXT,
    context_vis_disable                         TEXT,
    context_vis_demoted                         TEXT,
    context_vis_age_restricted                  TEXT,
    context_vis_interaction_restricted          TEXT,
    context_vis_labelled                        TEXT,
    context_vis_other                           TEXT,
    context_mon_suspension                      TEXT,
    context_mon_termination                     TEXT,
    context_mon_other                           TEXT,
    context_svc_suspension                      TEXT,
    context_svc_termination                     TEXT,
    context_acc_suspension                      TEXT,
    context_acc_termination                     TEXT,

    UNIQUE (filing_id, category_code)
);

COMMENT ON TABLE own_initiative_illegal IS
    'Article 15(1)(c) DSA: content moderation actions taken by the provider '
    'on its own initiative against illegal content, broken down by category '
    'and restriction type per Annex II.';

CREATE INDEX idx_oii_filing ON own_initiative_illegal (filing_id);
CREATE INDEX idx_oii_category ON own_initiative_illegal (category_code);

ALTER TABLE own_initiative_illegal ENABLE ROW LEVEL SECURITY;
