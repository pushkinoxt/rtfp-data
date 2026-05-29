"""
Load the Annex II category taxonomy from a provider's 02_categories.csv.

Idempotent: existing codes are updated, new codes inserted. The categories
table accumulates the union of all providers' Annex II references.

Handles header whitespace quirks: some providers ship CSV headers with
trailing spaces, so we strip them before column lookup.

Usage:
    python load_categories.py --bundle /path/to/provider/period
"""
import os
import sys
import argparse
import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

CSV_NAME = "02_categories.csv"

EXPECTED = {
    "Category label": "label_raw",
    "Category description": "description",
    "Category of illegal content / incompatible with the terms and conditions": "code",
    "Contextual information": "context",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True)
    args = parser.parse_args()

    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    csv_path = Path(args.bundle) / CSV_NAME
    if not csv_path.exists():
        sys.exit(f"Cannot find {csv_path}")

    # Read everything, then strip whitespace from headers
    df = pd.read_csv(csv_path)
    df.columns = [c.strip() for c in df.columns]

    missing = set(EXPECTED.keys()) - set(df.columns)
    if missing:
        sys.exit(f"Missing expected columns: {missing}. Found: {list(df.columns)}")

    df = df[list(EXPECTED.keys())].rename(columns=EXPECTED)

    df["code"] = df["code"].astype(str).str.strip()
    df["description"] = df["description"].astype(str).str.strip()
    df = df[df["code"].notna() & (df["code"] != "") & (df["code"] != "nan")]

    total_rows = len(df)
    unique_codes = df["code"].nunique()
    duplicates = total_rows - unique_codes
    print(f"Read {total_rows} rows from {csv_path}")
    print(f"  Unique codes: {unique_codes} | Duplicates collapsed: {duplicates}")

    with engine.connect() as conn:
        existing = set(r[0] for r in conn.execute(text("SELECT code FROM categories")))

    incoming = set(df["code"].unique())
    new_codes = incoming - existing
    if new_codes:
        print(f"  NEW codes introduced by this provider ({len(new_codes)}): {sorted(new_codes)}")
    else:
        print(f"  No new codes — all already in categories table.")

    rows = []
    for sort_order, (_, r) in enumerate(df.drop_duplicates("code").iterrows()):
        is_total = (r["code"] == "TOTAL")
        label = "Total" if is_total else r["description"]
        rows.append({
            "code": r["code"],
            "label": label,
            "description": r["description"],
            "sort_order": sort_order,
            "is_total": is_total,
        })

    sql = text("""
        INSERT INTO categories (code, label, description, sort_order, is_total)
        VALUES (:code, :label, :description, :sort_order, :is_total)
        ON CONFLICT (code) DO UPDATE
        SET label = EXCLUDED.label,
            description = EXCLUDED.description,
            is_total = EXCLUDED.is_total
    """)

    with engine.begin() as conn:
        for row in rows:
            conn.execute(sql, row)

    with engine.connect() as conn:
        new_total = conn.execute(text("SELECT COUNT(*) FROM categories")).scalar()
    print(f"Categories table now contains {new_total} unique codes.")


if __name__ == "__main__":
    main()
