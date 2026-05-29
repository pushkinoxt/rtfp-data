-- Migration 009: Create the own_initiative_tc table
-- Article 15(1)(d) DSA: content moderation actions taken by the provider on its
-- own initiative against violations of the provider's terms and conditions.
-- Also captures any inline Article 24(1)(a)/(b) indicators where providers
-- include them in this file.
-- Source CSV: 06_A151D_241AB_Own_TC.csv per Annex II template.

DROP TABLE IF EXISTS own_initiative_tc CASCADE;

CREATE TABLE own_initiative_tc (
    id                                          BIGSERIAL PRIMARY KEY,
    filing_id                                   BIGINT NOT NULL
                                                REFERENCES filings(id) ON DELETE CASCADE,

    -- Dimensions
    category_code                               TEXT NOT NULL REFERENCES categories(code),
    category_label_raw                          TEXT NOT NULL,
    description_other                           TEXT,

    -- Volume and automation
    measures_total                              NUMERIC,
    measures_solely_automated                   NUMERIC,

    -- Visibility restrictions
    vis_removal                                 NUMERIC,
    vis_disable                                 NUMERIC,
    vis_demoted                                 NUMERIC,
    vis_age_restricted                          NUMERIC,
    vis_interaction_restricted                  NUMERIC,
    vis_labelled                                NUMERIC,
    vis_other                                   NUMERIC,

    -- Monetary restrictions
    mon_suspension                              NUMERIC,
    mon_termination                             NUMERIC,
    mon_other                                   NUMERIC,

    -- Provision of service restrictions
    svc_suspension                              NUMERIC,
    svc_termination                             NUMERIC,

    -- Account restrictions
    acc_suspension                              NUMERIC,
    acc_termination                             NUMERIC,

    -- Paired contextual information
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

    UNIQUE (filing_id, category_label_raw, category_code)
);

COMMENT ON TABLE own_initiative_tc IS
    'Article 15(1)(d) DSA: content moderation actions taken by the provider '
    'on its own initiative against violations of its terms and conditions, '
    'broken down by category and restriction type. May also contain inline '
    'Article 24(1)(a)/(b) figures depending on provider reporting practice.';

CREATE INDEX idx_oitc_filing ON own_initiative_tc (filing_id);
CREATE INDEX idx_oitc_category ON own_initiative_tc (category_code);

ALTER TABLE own_initiative_tc ENABLE ROW LEVEL SECURITY;
