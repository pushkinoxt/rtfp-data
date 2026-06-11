"""
Load qualitative narrative indicators from 11_A151CE_422AB_Qualitative.csv.

Usage:
    python load_qualitative_indicators.py --provider tiktok \\
        --period 2025-h2 \\
        --bundle /Users/pushkin/Documents/DSAPROJECT/duck-dsa-reports/raw/tiktok/2025h2
"""
import os
import sys
import argparse
import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

CSV_NAME = "11_A151CE_422AB_Qualitative.csv"


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
    # Some providers (notably AliExpress) encode their CSVs in Latin-1
    # rather than UTF-8. Try common encodings in order; the first one
    # that succeeds wins.
    df = None
    for encoding in ("utf-8", "utf-8-sig", "iso-8859-1", "cp1252"):
        try:
            df = pd.read_csv(csv_path, encoding=encoding)
            if encoding != "utf-8":
                print(f"Note: read {CSV_NAME} as {encoding} (not UTF-8)")
            break
        except UnicodeDecodeError:
            continue
    if df is None:
        sys.exit(f"Could not decode {csv_path} with any of the tried encodings")
        print(f"Read {len(df)} rows from {csv_path.name}")

    # Keep only Indicator and Value
    if "Indicator" not in df.columns or "Value" not in df.columns:
        sys.exit(f"CSV missing expected columns. Available: {list(df.columns)}")

    df = df[["Indicator", "Value"]].rename(columns={
        "Indicator": "indicator",
        "Value": "value",
    })

    for col in ["indicator", "value"]:
        df[col] = df[col].astype(str).str.strip()
        df[col] = df[col].where(~df[col].isin(["", "nan", "NaN"]), None)

    before = len(df)
    df = df[df["indicator"].notna()]
    if len(df) < before:
        print(f"Dropped {before - len(df)} rows with empty indicator")

    df["filing_id"] = filing_id

    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM qualitative_indicators WHERE filing_id = :fid"),
            {"fid": filing_id}
        )

    df.to_sql("qualitative_indicators", engine, if_exists="append", index=False)
    print(f"Loaded {len(df)} qualitative indicators.")


if __name__ == "__main__":
    main()
