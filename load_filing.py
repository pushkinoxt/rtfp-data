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
    parser.add_argument("--service-name", default=None,
                        help="override the filing's service_name, e.g. 'YouTube Ads'. "
                             "Defaults to the provider name read from file 01.")
    # CONVENTION (load-bearing): an advertising service of a provider that also
    # files a main service MUST be loaded with --slug-suffix ads, giving a slug
    # ending in '/ads'. The primary_current_filings view (migration 051) excludes
    # exactly those /ads filings so provider-level analytical views resolve to one
    # main-service row per provider. Use a different suffix (e.g. /restated, set
    # automatically for restatements) for anything that is NOT an ad service, or it
    # will be silently dropped from the analytical layer.
    parser.add_argument("--slug-suffix", default=None,
                        help="append a suffix to the filing slug so a second service of the "
                             "same provider/period stays unique. Use 'ads' for an advertising "
                             "service (slug '/ads' is excluded from provider-level views by "
                             "primary_current_filings); see the convention note above.")
    parser.add_argument("--version", type=int, default=1,
                        help="version_number for this filing (default 1). Use a higher "
                             "number to load a restatement as a separate version of the "
                             "same provider/service/period, e.g. --version 2. Pair with "
                             "--slug-suffix to keep the slug unique.")
    args = parser.parse_args()

    if args.version < 1:
        sys.exit("--version must be a positive integer.")

    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    meta = read_file_01(args.bundle)

    name_of_provider   = meta.get(IND_NAME)
    original_pub       = parse_date(meta.get(IND_PUB_DATE))
    previous_pub       = parse_date(meta.get(IND_PREV_PUB_DATE))
    period_start       = parse_date(meta.get(IND_PERIOD_START))
    period_end         = parse_date(meta.get(IND_PERIOD_END))

    # this_version_published_on is always this version's own publication date.
    # original_published_on is when the report was *first* published for this period:
    # equal to this version's date for an original (version 1), but the earlier cited
    # "previous publication" date for a restatement (version > 1) -- for a first
    # restatement that previous publication is precisely the original. If a restatement
    # somehow lacks a previous date, fall back to this version's date.
    if args.version > 1 and previous_pub is not None:
        first_published = previous_pub
    else:
        first_published = original_pub

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

        slug = f"{args.provider}/{args.period}"
        if args.slug_suffix:
            slug = f"{slug}/{args.slug_suffix}"
        service_name = args.service_name if args.service_name else name_of_provider

        existing = conn.execute(text(
            "SELECT id FROM filings WHERE slug = :slug"
        ), {"slug": slug}).scalar()
        if existing is not None:
            print(f"Filing already exists (id {existing}) with slug '{slug}'. "
                  f"No insert performed.")
            return

        # A restatement (version > 1) must link to the filing it restates. By schema
        # rule, version 1 has no link and version > 1 must have one. We point at the
        # immediately-prior version of the same provider/service/period, so versions
        # form a chain (v2 restates v1, v3 restates v2).
        restates_id = None
        if args.version > 1:
            prev_v = args.version - 1
            restates_id = conn.execute(text("""
                SELECT id FROM filings
                WHERE provider_id = :pid AND period_label = :period
                  AND service_name = :service AND version_number = :prev
            """), {"pid": provider_id, "period": args.period,
                   "service": service_name, "prev": prev_v}).scalar()
            if restates_id is None:
                sys.exit(
                    f"Cannot load version {args.version}: no version {prev_v} filing found "
                    f"for {args.provider} {args.period} service '{service_name}' to restate. "
                    f"Load the prior version first."
                )

        filing_id = conn.execute(text("""
            INSERT INTO filings (
                provider_id, slug, service_name,
                period_start, period_end, period_label,
                original_published_on, this_version_published_on,
                previous_publication_date,
                version_number, name_of_service_provider,
                restates_filing_id
            ) VALUES (
                :pid, :slug, :service_name,
                :pstart, :pend, :period,
                :firstpub, :pub,
                :prevpub,
                :version, :name,
                :restates
            )
            RETURNING id
        """), {
            "pid": provider_id,
            "slug": slug,
            "service_name": service_name,
            "pstart": period_start,
            "pend": period_end,
            "period": args.period,
            "pub": original_pub,
            "firstpub": first_published,
            "prevpub": previous_pub,
            "name": name_of_provider,
            "version": args.version,
            "restates": restates_id,
        }).scalar()

    print(f"Created filing id {filing_id} for {args.provider} {args.period}")
    print(f"  Provider name (from file 01): {name_of_provider}")
    print(f"  Published:    {original_pub}")
    if args.version > 1:
        print(f"  First publ.:  {first_published}  (version {args.version} restatement)")
        print(f"  Restates:     filing id {restates_id}")
    print(f"  Prev publish: {previous_pub}")
    print(f"  Period:       {period_start} to {period_end}")


if __name__ == "__main__":
    main()
