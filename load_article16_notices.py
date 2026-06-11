"""
Load Article 15(1)(b) data (notices and Trusted Flagger breakdown).

Handles:
  - CSVs with or without a "Category label" column (synthesis fallback).
  - Header whitespace inconsistencies across providers.
  - Numeric values with thousands separators ("353,997").
  - Excel-merged category cells (forward-fill).
  - Undeclared category codes (self-healing FK).
"""
import os
import sys
import json
import argparse
import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

CSV_NAME = "04_A151B_Notices.csv"
OPTIONAL_LABEL_COL = "Category label"

REQUIRED_COLUMN_MAP = {
    "Category of illegal content": "category_code",
    "Description of the sub-category \"Other\"": "description_other",

    "Number of notices received": "notices_received",
    "Number of notices received from Trusted flaggers": "notices_received_tf",
    "Number of specific items of information included in the total number of notices": "items_in_notices",
    "Number of specific items of information included in the total number of notices by Trusted Flaggers (Trusted Flagger notices)": "items_in_notices_tf",
    "Median time to take action": "median_time_to_action",
    "Median time to take action (Trusted Flagger notices)": "median_time_to_action_tf",
    "Number of actions taken on the basis of the law": "actions_basis_law",
    "Number of actions taken on the basis of the law (Trusted Flagger notices)": "actions_basis_law_tf",
    "Number of actions taken on the basis of the terms and conditions of the service": "actions_basis_tc",
    "Number of actions taken on the basis of the terms and conditions of the service (Trusted Flagger notices)": "actions_basis_tc_tf",

    "Contextual information on Number of notices received": "context_notices_received",
    "Contextual information on Number of notices received from Trusted flaggers": "context_notices_received_tf",
    "Contextual information on Number of specific items of information included in the total number of notices": "context_items_in_notices",
    "Contextual information on Number of specific items of information included in the total number of notices by Trusted Flaggers (Trusted Flagger notices)": "context_items_in_notices_tf",
    "Contextual information on Median time to take action": "context_median_time_to_action",
    "Contextual information on Median time to take action (Trusted Flagger notices)": "context_median_time_to_action_tf",
    "Contextual information on Number of actions taken on the basis of the law": "context_actions_basis_law",
    "Contextual information on Number of actions taken on the basis of the law (Trusted Flagger notices)": "context_actions_basis_law_tf",
    "Contextual information on Number of actions taken on the basis of the terms and conditions of the service": "context_actions_basis_tc",
    "Contextual information on Number of actions taken on the basis of the terms and conditions of the service (Trusted Flagger notices)": "context_actions_basis_tc_tf",
}

NUMERIC_COLUMNS = {
    "notices_received", "notices_received_tf",
    "items_in_notices", "items_in_notices_tf",
    "median_time_to_action", "median_time_to_action_tf",
    "actions_basis_law", "actions_basis_law_tf",
    "actions_basis_tc", "actions_basis_tc_tf",
}


def synthesise_category_labels(category_codes):
    labels = []
    current_parent = None
    for code in category_codes:
        if code is None or pd.isna(code):
            labels.append(None)
            continue
        if code == "TOTAL":
            labels.append(None)
            current_parent = None
        elif code.startswith("STATEMENT_CATEGORY_"):
            labels.append(None)
            current_parent = code
        elif code.startswith("KEYWORD_"):
            labels.append(current_parent)
        else:
            labels.append(None)
    return labels


def log_anomaly(conn, filing_id, anomaly_type, description, raw_row=None):
    conn.execute(text("""
        INSERT INTO import_anomalies (filing_id, source_file, anomaly_type, description, raw_row)
        VALUES (:filing_id, :source_file, :anomaly_type, :description, CAST(:raw_row AS JSONB))
    """), {
        "filing_id": filing_id,
        "source_file": CSV_NAME,
        "anomaly_type": anomaly_type,
        "description": description,
        "raw_row": json.dumps(raw_row) if raw_row else None,
    })


def ensure_codes_exist(engine, filing_id, incoming_codes):
    with engine.connect() as conn:
        existing = set(r[0] for r in conn.execute(
            text("SELECT code FROM categories WHERE code = ANY(:codes)"),
            {"codes": list(incoming_codes)}
        ))
    missing = incoming_codes - existing
    if not missing:
        return
    print(f"Auto-adding {len(missing)} unknown category codes: {sorted(missing)}")
    with engine.begin() as conn:
        for code in missing:
            conn.execute(text("""
                INSERT INTO categories (code, label, description, sort_order, is_total)
                VALUES (:code, :label, :description, 9999, FALSE)
                ON CONFLICT (code) DO NOTHING
            """), {
                "code": code,
                "label": code.replace("_", " ").title(),
                "description": f"Auto-added by loader from {CSV_NAME}.",
            })
        log_anomaly(
            conn, filing_id=filing_id,
            anomaly_type="undeclared_category_codes",
            description=(
                f"File {CSV_NAME} references {len(missing)} category codes not present "
                f"in any 02_categories.csv loaded so far. Codes: {sorted(missing)}"
            ),
        )


def strip_commas_for_numeric(s):
    """Normalise a numeric string for parsing. Handles two thousand-separator
    conventions: English (commas, e.g. "353,997") and European (dots, e.g.
    "11.279.462"). Returns the original input if it's NaN.

    Heuristic: a value containing a comma uses commas as thousand separators
    (English). A value containing only dots and digits uses dots as thousand
    separators only when there are 2+ dots OR the dot is followed by exactly
    three digits with no further digits — both unambiguous signs of a
    European-style integer. Other dot patterns (a single dot before fewer
    than three digits, or any value with both commas and dots) are passed
    through unchanged so genuine decimals are preserved.
    """
    if pd.isna(s):
        return s
    text = str(s).strip()
    if "," in text:
        # English convention — strip commas
        return text.replace(",", "")
    if "." in text:
        # European convention if and only if: multiple dots, OR a single dot
        # followed by exactly 3 digits with nothing after (e.g. "6.564")
        parts = text.split(".")
        if len(parts) > 2:
            # Multiple dots — definitely thousand separators
            return text.replace(".", "")
        if len(parts) == 2 and len(parts[1]) == 3 and parts[1].isdigit() and parts[0].isdigit():
            # Exactly one dot, three digits after — European thousand separator
            return text.replace(".", "")
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True)
    parser.add_argument("--period", required=True)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--version", type=int, default=1,
                        help="version_number of the filing to load into "
                             "(default 1). Use 2+ for a restatement.")
    parser.add_argument("--service-name", default=None,
                        help="target one service of a multi-service provider, e.g. 'YouTube Ads'.")
    args = parser.parse_args()

    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    with engine.connect() as conn:
        filing_id = conn.execute(text("""
            SELECT f.id FROM filings f
            JOIN providers p ON p.id = f.provider_id
            WHERE p.slug = :slug AND f.period_label = :period AND f.version_number = :version
              AND (:service IS NULL OR f.service_name = :service)
        """), {"slug": args.provider, "period": args.period, "service": args.service_name, "version": args.version}).scalar()

    if filing_id is None:
        sys.exit(f"No filing found for {args.provider} {args.period}.")
    print(f"Filing id: {filing_id}")

    csv_path = Path(args.bundle) / CSV_NAME
    if not csv_path.exists():
        sys.exit(f"Cannot find {csv_path}")
    df_raw = pd.read_csv(csv_path)
    df_raw.columns = [c.strip() for c in df_raw.columns]
    print(f"Read {len(df_raw)} rows from {csv_path.name}")

    # Per Annex II, not every provider populates every column. Treat missing
    # columns as missing data: insert NULL for those columns rather than
    # refusing the file. Anomaly logged so the absence is visible.
    missing = set(REQUIRED_COLUMN_MAP.keys()) - set(df_raw.columns)
    if missing:
        print(f"Warning: CSV missing {len(missing)} expected columns; inserting NULL for those: {sorted(missing)}")
        for col in missing:
            df_raw[col] = None

    cat_col = "Category of illegal content"
    nan_before = df_raw[cat_col].isna().sum()
    if nan_before > 0:
        df_raw[cat_col] = df_raw[cat_col].ffill()
        nan_after = df_raw[cat_col].isna().sum()
        print(f"Forward-filled category column: {nan_before} → {nan_after} NaN rows")
    if OPTIONAL_LABEL_COL in df_raw.columns:
        df_raw[OPTIONAL_LABEL_COL] = df_raw[OPTIONAL_LABEL_COL].ffill()

    df = df_raw[list(REQUIRED_COLUMN_MAP.keys())].rename(columns=REQUIRED_COLUMN_MAP)

    if OPTIONAL_LABEL_COL in df_raw.columns:
        df["category_label_raw"] = df_raw[OPTIONAL_LABEL_COL].values
        print(f"Using CSV's '{OPTIONAL_LABEL_COL}' column for category_label_raw")
    else:
        df["category_label_raw"] = synthesise_category_labels(df["category_code"])
        synth_count = sum(1 for x in df["category_label_raw"] if x is not None)
        print(f"Synthesised category_label_raw from row order ({synth_count} non-null)")

    for col in df.select_dtypes(include="object").columns:
        df[col] = df[col].astype(str).str.strip()
        df[col] = df[col].where(~df[col].isin(["", "nan", "NaN"]), None)

    before = len(df)
    df = df[df["category_code"].notna()]
    if len(df) < before:
        print(f"Dropped {before - len(df)} rows with empty category_code")

    for col in NUMERIC_COLUMNS:
        df[col] = df[col].apply(strip_commas_for_numeric)
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df["filing_id"] = filing_id

    ensure_codes_exist(engine, filing_id, set(df["category_code"].dropna().unique()))

    with engine.begin() as conn:
        deleted = conn.execute(
            text("DELETE FROM article16_notices WHERE filing_id = :fid"),
            {"fid": filing_id}
        ).rowcount
        if deleted:
            print(f"Deleted {deleted} existing rows for this filing")

    df.to_sql("article16_notices", engine, if_exists="append", index=False)
    print(f"Loaded {len(df)} rows.")


if __name__ == "__main__":
    main()
