"""
Load long-format indicators from files 07, 08, 09, 10.

Handles:
  - Different "Contextual Information" / "information" casing across files.
  - Excel-merged Section/Indicator cells exported as blank — forward-filled.
  - Comma-formatted numeric values (handled by the value_numeric generated column).
"""
import os
import sys
import argparse
import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

FILES = [
    "07_Appeals.csv",
    "08_A151BCE_422C_Auto.csv",
    "09_A422AB_Human.csv",
    "10_A423_AMAR.csv",
]

CANONICAL = {
    "section":   ["Section"],
    "indicator": ["Indicator"],
    "scope":     ["Scope"],
    "value":     ["Value"],
    "context":   ["Contextual Information", "Contextual information"],
}


def normalise_columns(df, source_file):
    out = pd.DataFrame()
    for canonical, variants in CANONICAL.items():
        found = next((v for v in variants if v in df.columns), None)
        if found is None:
            if canonical == "context":
                out[canonical] = None
                continue
            raise ValueError(
                f"{source_file}: cannot find column for {canonical} "
                f"(tried {variants}). Available: {list(df.columns)}"
            )
        out[canonical] = df[found].values
    return out


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

    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM indicators WHERE filing_id = :fid"),
            {"fid": filing_id}
        )

    bundle = Path(args.bundle)
    grand_total = 0

    for csv_name in FILES:
        csv_path = bundle / csv_name
        if not csv_path.exists():
            print(f"  SKIP: {csv_name} not found")
            continue

        # Some providers (Temu, AliExpress) ship CSVs in Latin-1 instead of UTF-8.
        # Try common encodings in order; the first that succeeds wins.
        df_raw = None
        for encoding in ("utf-8", "utf-8-sig", "iso-8859-1", "cp1252"):
            try:
                df_raw = pd.read_csv(csv_path, encoding=encoding)
                if encoding != "utf-8":
                    print(f"  Note: read {csv_path.name} as {encoding} (not UTF-8)")
                break
            except UnicodeDecodeError:
                continue
        if df_raw is None:
            sys.exit(f"Could not decode {csv_path}")
        df_raw.columns = [c.strip() for c in df_raw.columns]

        # Forward-fill Section and Indicator BEFORE normalising columns.
        # Files exported from Excel with merged cells leave these blank in
        # subsequent rows of the same group.
        for col in ["Section", "Indicator"]:
            if col in df_raw.columns:
                nan_before = df_raw[col].isna().sum()
                if nan_before > 0:
                    df_raw[col] = df_raw[col].ffill()
                    print(f"  {csv_name}: forward-filled {col} ({nan_before} NaN rows)")

        df = normalise_columns(df_raw, csv_name)

        for col in ["section", "indicator", "scope", "value", "context"]:
            if col in df.columns:
                df[col] = df[col].astype(str).str.strip()
                df[col] = df[col].where(~df[col].isin(["", "nan", "NaN"]), None)

        before = len(df)
        df = df[df["indicator"].notna() & df["section"].notna() & df["scope"].notna()]
        if len(df) < before:
            print(f"  {csv_name}: dropped {before - len(df)} rows with empty section/indicator/scope")

        df["filing_id"] = filing_id
        df["source_file"] = csv_name
        # Some providers' files legitimately carry more than one row per
        # (section, indicator, scope): the adult-content services report each
        # detection tool's accuracy/precision/recall separately, with the tool in
        # the context column. So the unique key (and this dedup) includes context
        # (migration 054); only byte-identical rows are genuine duplicates. Keep
        # the first occurrence of each and report how many were dropped.
        before = len(df)
        df = df.drop_duplicates(
            subset=["filing_id", "source_file", "section", "indicator", "scope", "context"],
            keep="first"
        )
        dropped = before - len(df)
        if dropped > 0:
            print(f"  {csv_name}: dropped {dropped} duplicate rows on (section, indicator, scope, context)")
        df.to_sql("indicators", engine, if_exists="append", index=False)
        print(f"  {csv_name}: loaded {len(df)} rows")
        grand_total += len(df)

    print(f"Total indicator rows loaded: {grand_total}")


if __name__ == "__main__":
    main()
