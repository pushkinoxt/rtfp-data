"""
Load Article 15(1)(c) data (own-initiative moderation of illegal content).

Handles entirely placeholder files (TikTok), with-or-without Category label
column, header whitespace, comma-formatted numerics, merged-cell forward-fill,
and self-healing FK for undeclared codes.
"""
import os
import sys
import json
import argparse
import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

CSV_NAME = "05_A151C_Own_Illegal.csv"
PERIOD_COL = "Reporting period"
PLACEHOLDER = "YYYY-MM-DD/YYYY-MM-DD"
OPTIONAL_LABEL_COL = "Category label"

REQUIRED_COLUMN_MAP = {
    "Category of illegal content": "category_code",
    "Description of the sub-category \"Other\"": "description_other",

    "Number of measures taken at the provider's own initiative": "measures_total",
    "Number of measures taken after detection with solely automated means": "measures_solely_automated",

    "Visibility restriction Removal": "vis_removal",
    "Visibility restriction Disable": "vis_disable",
    "Visibility restriction Demoted": "vis_demoted",
    "Visibility restriction Age restricted": "vis_age_restricted",
    "Visibility restriction Interaction restricted": "vis_interaction_restricted",
    "Visibility restriction Labelled": "vis_labelled",
    "Visibility restriction Other": "vis_other",

    "Monetary restriction Suspension": "mon_suspension",
    "Monetary restriction Termination": "mon_termination",
    "Monetary restriction Other": "mon_other",

    "Provision of the service Suspension": "svc_suspension",
    "Provision of the service Termination": "svc_termination",

    "Account restriction Suspension": "acc_suspension",
    "Account restriction Termination": "acc_termination",

    "Contextual Information on Number of measures taken at the provider's own initiative": "context_measures_total",
    "Contextual Information on Number of measures taken after detection with solely automated means": "context_measures_solely_automated",
    "Contextual Information on Visibility restriction Removal": "context_vis_removal",
    "Contextual Information on Visibility restriction Disable": "context_vis_disable",
    "Contextual Information on Visibility restriction Demoted": "context_vis_demoted",
    "Contextual Information on Visibility restriction Age restricted": "context_vis_age_restricted",
    "Contextual Information on Visibility restriction Interaction restricted": "context_vis_interaction_restricted",
    "Contextual Information on Visibility restriction Labelled": "context_vis_labelled",
    "Contextual Information on Visibility restriction Other": "context_vis_other",
    "Contextual Information on Monetary restriction Suspension": "context_mon_suspension",
    "Contextual Information on Monetary restriction Termination": "context_mon_termination",
    "Contextual Information on Monetary restriction Other": "context_mon_other",
    "Contextual Information on Provision of the service Suspension": "context_svc_suspension",
    "Contextual Information on Provision of the service Termination": "context_svc_termination",
    "Contextual Information on Account restriction Suspension": "context_acc_suspension",
    "Contextual Information on Account restriction Termination": "context_acc_termination",
}

NUMERIC_COLUMNS = {
    "measures_total", "measures_solely_automated",
    "vis_removal", "vis_disable", "vis_demoted",
    "vis_age_restricted", "vis_interaction_restricted",
    "vis_labelled", "vis_other",
    "mon_suspension", "mon_termination", "mon_other",
    "svc_suspension", "svc_termination",
    "acc_suspension", "acc_termination",
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
    args = parser.parse_args()

    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    with engine.connect() as conn:
        filing_id = conn.execute(text("""
            SELECT f.id FROM filings f
            JOIN providers p ON p.id = f.provider_id
            WHERE p.slug = :slug AND f.period_label = :period AND f.version_number = 1
        """), {"slug": args.provider, "period": args.period}).scalar()

    if filing_id is None:
        sys.exit(f"No filing found for {args.provider} {args.period}.")
    print(f"Filing id: {filing_id}")

    csv_path = Path(args.bundle) / CSV_NAME
    if not csv_path.exists():
        sys.exit(f"Cannot find {csv_path}")
    df_raw = pd.read_csv(csv_path)
    df_raw.columns = [c.strip() for c in df_raw.columns]
    print(f"Read {len(df_raw)} rows from {csv_path.name}")

    placeholder_mask = df_raw[PERIOD_COL].astype(str).str.strip() == PLACEHOLDER
    placeholder_count = int(placeholder_mask.sum())
    real_rows = df_raw[~placeholder_mask].copy()
    print(f"Placeholder rows: {placeholder_count} | Real rows: {len(real_rows)}")

    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM own_initiative_illegal WHERE filing_id = :fid"),
            {"fid": filing_id}
        )
        conn.execute(text("""
            DELETE FROM import_anomalies
            WHERE filing_id = :fid AND source_file = :src
        """), {"fid": filing_id, "src": CSV_NAME})

        if len(real_rows) == 0:
            log_anomaly(
                conn, filing_id=filing_id,
                anomaly_type="entire_file_unfilled",
                description=(
                    f"File {CSV_NAME} contains {placeholder_count} rows, all with "
                    f"placeholder reporting period '{PLACEHOLDER}'. Provider classifies "
                    f"all own-initiative moderation as ToS-based rather than illegal-content-based."
                ),
            )
            print("Logged filing-level anomaly: file entirely unfilled.")
            return

        if placeholder_count > 0:
            log_anomaly(
                conn, filing_id=filing_id,
                anomaly_type="partial_file_unfilled",
                description=(
                    f"File {CSV_NAME} contains {placeholder_count} placeholder rows "
                    f"out of {len(df_raw)}. Skipped."
                ),
            )

    missing = set(REQUIRED_COLUMN_MAP.keys()) - set(real_rows.columns)
    if missing:
        sys.exit(f"CSV is missing expected columns: {missing}")

    # Forward-fill merged category cells if any
    cat_col = "Category of illegal content"
    nan_before = real_rows[cat_col].isna().sum()
    if nan_before > 0:
        real_rows[cat_col] = real_rows[cat_col].ffill()
        nan_after = real_rows[cat_col].isna().sum()
        print(f"Forward-filled category column: {nan_before} → {nan_after} NaN rows")
    if OPTIONAL_LABEL_COL in real_rows.columns:
        real_rows[OPTIONAL_LABEL_COL] = real_rows[OPTIONAL_LABEL_COL].ffill()

    df = real_rows[list(REQUIRED_COLUMN_MAP.keys())].rename(columns=REQUIRED_COLUMN_MAP)

    if OPTIONAL_LABEL_COL in real_rows.columns:
        df["category_label_raw"] = real_rows[OPTIONAL_LABEL_COL].values
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

    df.to_sql("own_initiative_illegal", engine, if_exists="append", index=False)
    print(f"Loaded {len(df)} data rows.")


if __name__ == "__main__":
    main()
