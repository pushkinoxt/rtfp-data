-- Migration 011: Create the qualitative_indicators table
-- Annex I Qualitative Template: free-text answers to fixed questions
-- under Article 15(1)(c)(e) and Article 42(2)(a)(b).
-- Source CSV: 11_A151CE_422AB_Qualitative.csv

DROP TABLE IF EXISTS qualitative_indicators CASCADE;

CREATE TABLE qualitative_indicators (
    id              BIGSERIAL PRIMARY KEY,
    filing_id       BIGINT NOT NULL REFERENCES filings(id) ON DELETE CASCADE,

    indicator       TEXT NOT NULL,        -- The fixed Annex I question
    value           TEXT,                 -- The provider's free-text answer

    UNIQUE (filing_id, indicator)
);

COMMENT ON TABLE qualitative_indicators IS
    'Annex I Qualitative Template: free-text narrative answers from VLOPs to '
    'the fixed list of qualitative questions under Articles 15(1)(c)(e) and '
    '42(2)(a)(b). Period-over-period diffs of these fields surface deliberate '
    'policy and practice changes.';

COMMENT ON COLUMN qualitative_indicators.indicator IS
    'The fixed Annex I question, e.g. "Summary of the content moderation '
    'enforcement", "Languages supported by content moderation teams".';
COMMENT ON COLUMN qualitative_indicators.value IS
    'Provider-supplied prose answer. May be empty if the provider declined or '
    'considered the indicator not applicable.';

CREATE INDEX idx_qi_filing ON qualitative_indicators (filing_id);

ALTER TABLE qualitative_indicators ENABLE ROW LEVEL SECURITY;
