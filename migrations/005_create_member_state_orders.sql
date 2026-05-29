-- Migration 005: Create the member_state_orders table
-- Article 15(1)(a) DSA data: orders received from Member State authorities
-- under Articles 9 and 10. Source: 03_A151A_MSO.csv per Annex II template.

DROP TABLE IF EXISTS member_state_orders CASCADE;

CREATE TABLE member_state_orders (
    id                                          BIGSERIAL PRIMARY KEY,
    filing_id                                   BIGINT NOT NULL
                                                REFERENCES filings(id) ON DELETE CASCADE,

    -- Dimensions
    category_code                               TEXT NOT NULL REFERENCES categories(code),
    category_label_raw                          TEXT NOT NULL,
    description_other                           TEXT,
    scope                                       TEXT NOT NULL
                                                CHECK (scope = 'TOTAL' OR length(scope) = 2),

    -- Article 9 orders (act against illegal content)
    orders_act_received                         NUMERIC,
    items_in_orders_act                         NUMERIC,
    median_time_inform_receipt_act              NUMERIC,
    median_time_give_effect_act                 NUMERIC,

    -- Article 10 orders (provide information)
    orders_info_received                        NUMERIC,
    median_time_inform_receipt_info             NUMERIC,
    median_time_give_effect_info                NUMERIC,

    -- Paired contextual information
    context_orders_act_received                 TEXT,
    context_items_in_orders_act                 TEXT,
    context_median_time_inform_receipt_act      TEXT,
    context_median_time_give_effect_act         TEXT,
    context_orders_info_received                TEXT,
    context_median_time_inform_receipt_info     TEXT,
    context_median_time_give_effect_info        TEXT,

    -- Identity: parent_label + leaf_code + scope, per filing
    UNIQUE (filing_id, category_label_raw, category_code, scope)
);

COMMENT ON TABLE member_state_orders IS
    'Article 15(1)(a) DSA: orders received from Member State authorities '
    'under Articles 9 and 10, with response-time medians.';

COMMENT ON COLUMN member_state_orders.scope IS
    'Either an ISO-3166 alpha-2 country code (e.g. DE, FR) or TOTAL for EU-wide aggregates.';
COMMENT ON COLUMN member_state_orders.category_label_raw IS
    'The raw "Category label" column from the CSV (e.g. "Category 1"). '
    'Combined with category_code to disambiguate sub-categories like KEYWORD_OTHER '
    'that appear under multiple parents.';

CREATE INDEX idx_mso_filing ON member_state_orders (filing_id);
CREATE INDEX idx_mso_category ON member_state_orders (category_code);

ALTER TABLE member_state_orders ENABLE ROW LEVEL SECURITY;
