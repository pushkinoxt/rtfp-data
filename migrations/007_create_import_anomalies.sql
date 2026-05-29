-- Migration 007: Create the import_anomalies table
-- A general-purpose log of anything the loaders noticed but couldn't normally
-- represent in the data tables. Examples: unfilled template rows in source
-- CSVs, codes referencing categories not in our lookup, malformed dates, etc.

DROP TABLE IF EXISTS import_anomalies CASCADE;

CREATE TABLE import_anomalies (
    id              BIGSERIAL PRIMARY KEY,
    filing_id       BIGINT REFERENCES filings(id) ON DELETE CASCADE,
    source_file     TEXT NOT NULL,
    anomaly_type    TEXT NOT NULL,
    description     TEXT NOT NULL,
    raw_row         JSONB,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE import_anomalies IS
    'Loader-detected oddities in source CSVs. Not errors that block loading - '
    'rather, things worth surfacing to researchers (unfilled template rows, '
    'unexpected codes, format violations).';

CREATE INDEX idx_anomalies_filing ON import_anomalies (filing_id);
CREATE INDEX idx_anomalies_type ON import_anomalies (anomaly_type);

ALTER TABLE import_anomalies ENABLE ROW LEVEL SECURITY;
