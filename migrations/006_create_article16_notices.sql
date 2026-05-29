-- Migration 006: Create the article16_notices table
-- Article 15(1)(b) DSA data: notices received via the Article 16 notice-and-action
-- mechanism, with Article 22 Trusted Flagger breakdown.
-- Source CSV: 04_A151B_Notices.csv per Annex II template.

DROP TABLE IF EXISTS article16_notices CASCADE;

CREATE TABLE article16_notices (
    id                                          BIGSERIAL PRIMARY KEY,
    filing_id                                   BIGINT NOT NULL
                                                REFERENCES filings(id) ON DELETE CASCADE,

    -- Dimensions
    category_code                               TEXT NOT NULL REFERENCES categories(code),
    category_label_raw                          TEXT NOT NULL,
    description_other                           TEXT,

    -- Notice volumes (all notices vs Trusted Flagger only)
    notices_received                            NUMERIC,
    notices_received_tf                         NUMERIC,
    items_in_notices                            NUMERIC,
    items_in_notices_tf                         NUMERIC,

    -- Response times (in provider-disclosed units)
    median_time_to_action                       NUMERIC,
    median_time_to_action_tf                    NUMERIC,

    -- Actions taken, split by legal basis (law vs ToS)
    actions_basis_law                           NUMERIC,
    actions_basis_law_tf                        NUMERIC,
    actions_basis_tc                            NUMERIC,
    actions_basis_tc_tf                         NUMERIC,

    -- Paired contextual information columns
    context_notices_received                    TEXT,
    context_notices_received_tf                 TEXT,
    context_items_in_notices                    TEXT,
    context_items_in_notices_tf                 TEXT,
    context_median_time_to_action               TEXT,
    context_median_time_to_action_tf            TEXT,
    context_actions_basis_law                   TEXT,
    context_actions_basis_law_tf                TEXT,
    context_actions_basis_tc                    TEXT,
    context_actions_basis_tc_tf                 TEXT,

    UNIQUE (filing_id, category_label_raw, category_code)
);

COMMENT ON TABLE article16_notices IS
    'Article 15(1)(b) DSA: notices received under the Article 16 '
    'notice-and-action mechanism, including the Article 22 Trusted '
    'Flagger breakdown. Columns suffixed _tf cover Trusted Flagger notices only.';

COMMENT ON COLUMN article16_notices.actions_basis_law IS
    'Actions taken on the legal basis of EU or national law. Triggers '
    'Article 17 statement-of-reasons obligations.';
COMMENT ON COLUMN article16_notices.actions_basis_tc IS
    'Actions taken on the basis of the providers terms and conditions.';

CREATE INDEX idx_a16_filing ON article16_notices (filing_id);
CREATE INDEX idx_a16_category ON article16_notices (category_code);

ALTER TABLE article16_notices ENABLE ROW LEVEL SECURITY;
