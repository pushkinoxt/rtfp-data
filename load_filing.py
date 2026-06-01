#!/usr/bin/env python3
"""
Create a filings row from Annex II file 01 (the ID / metadata sheet).

File 01 is the canonical source for filing-level metadata: provider name,
publication dates, and reporting-period boundaries. This script reads those
fields directly from the file rather than relying on hand-entered values.

The provider must already exist in the providers table (seeded via migration).
This script only creates the filings row.

Usage:
    python load_filing.py --provider tiktok --period 2025-h2 \
        --bundle /path/to/raw/tiktok/2025h2

Idempotent: if a v1 filing already exists for (provider, period), the script
reports it and exits without inserting a duplicate.
"""
import os
import re
import sys
import argparse
from pathlib import Path
from datetime import datetime

import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

CSV_NAME = "01_ID.csv"

# Indicator strings as they appear in file 01's "Indicator" column.
IND_NAME          = "Name of the service provider"
IND_PUB_DATE      = "Date of the publication of the report"
IND_PREV_PUB_DATE = "Date of the publication of the latest previous report"
IND_PERIOD_START  = "Starting date of reporting period"
IND_PERIOD_END    = "Ending date of reporting period"


def parse_date(value):
    """Parse a date string in either ISO (YYYY-MM-DD) or DD/MM/YYYY format.
    Returns None for blanks. Providers are inconsistent about which they use,
    so we try both."""
    if value is None or str(value).strip() == "" or str(value).strip().lower() == "nan":
        return None
    s = str(value).strip()
    s = re.sub(r'\s*\[Updated [^\]]+\]\s*', '', s)
    s = re.sub(r'\s*\([^\)]+\)\s*', '', s)
    for fmt in ("%Y-%m-%d", "%Y-%m-%d %H:%M:%S", "%d/%m/%Y", "%d-%m-%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    sys.exit(f"Could not parse date '{s}' (tried ISO and DD/MM/YYYY formats).")


def read_file_01(bundle_path):
    """Read file 01 and return a dict of {indicator: value}."""
    csv_path = Path(bundle_path) / CSV_NAME
    if not csv_path.exists():
        sys.exit(f"File 01 not found at {csv_path}")

    # Tab-separated in the provider files; fall back to comma if needed.
    try:
        df = pd.read_csv(csv_path, sep="\t", dtype=str)
        if "Indicator" not in df.columns:
            df = pd.read_csv(csv_path, sep=",", dtype=str)
    except Exception as e:
        sys.exit(f"Could not read {csv_path}: {e}")

    df.columns = [c.strip() for c in df.columns]
    if "Indicator" not in df.columns or "Value" not in df.columns:
        sys.exit(f"File 01 missing 'Indicator'/'Value' columns. Found: {list(df.columns)}")

    metadata = {}
    for _, row in df.iterrows():
        indicator = str(row["Indicator"]).strip()
        value = row["Value"]
        metadata[indicator] = None if pd.isna(value) else str(value).strip()
    return metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True, help="provider slug, e.g. facebook")
    parser.add_argument("--period", required=True, help="period label, e.g. 2025-h2")
    parser.add_argument("--bundle", required=True, help="path to the CSV bundle folder")
    args = parser.parse_args()

    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    meta = read_file_01(args.bundle)

    name_of_provider   = meta.get(IND_NAME)
    original_pub       = parse_date(meta.get(IND_PUB_DATE))
    previous_pub       = parse_date(meta.get(IND_PREV_PUB_DATE))
    period_start       = parse_date(meta.get(IND_PERIOD_START))
    period_end         = parse_date(meta.get(IND_PERIOD_END))

    # Validate the essentials before touching the database.
    missing = []
    if original_pub is None: missing.append(IND_PUB_DATE)
    if period_start is None: missing.append(IND_PERIOD_START)
    if period_end is None:   missing.append(IND_PERIOD_END)
    if missing:
        sys.exit(f"File 01 missing required fields: {missing}")
    if period_end < period_start:
        sys.exit(f"Period end {period_end} precedes period start {period_start}.")

    with engine.begin() as conn:
        provider_id = conn.execute(text(
            "SELECT id FROM providers WHERE slug = :slug"
        ), {"slug": args.provider}).scalar()
        if provider_id is None:
            sys.exit(f"Provider '{args.provider}' not found. Seed it via a migration first.")

        existing = conn.execute(text("""
            SELECT id FROM filings
            WHERE provider_id = :pid AND period_label = :period AND version_number = 1
        """), {"pid": provider_id, "period": args.period}).scalar()
        if existing is not None:
            print(f"Filing already exists (id {existing}) for {args.provider} {args.period}. "
                  f"No insert performed.")
            return

        slug = f"{args.provider}/{args.period}"
        filing_id = conn.execute(text("""
            INSERT INTO filings (
                provider_id, slug, service_name,
                period_start, period_end, period_label,
                original_published_on, this_version_published_on,
                previous_publication_date,
                version_number, name_of_service_provider
            ) VALUES (
                :pid, :slug, :service_name,
                :pstart, :pend, :period,
                :pub, :pub,
                :prevpub,
                1, :name
            )
            RETURNING id
        """), {
            "pid": provider_id,
            "slug": slug,
            "service_name": name_of_provider,
            "pstart": period_start,
            "pend": period_end,
            "period": args.period,
            "pub": original_pub,
            "prevpub": previous_pub,
            "name": name_of_provider,
        }).scalar()

    print(f"Created filing id {filing_id} for {args.provider} {args.period}")
    print(f"  Provider name (from file 01): {name_of_provider}")
    print(f"  Published:    {original_pub}")
    print(f"  Prev publish: {previous_pub}")
    print(f"  Period:       {period_start} to {period_end}")


if __name__ == "__main__":
    main()
