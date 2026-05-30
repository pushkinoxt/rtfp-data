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

        df_raw = pd.read_csv(csv_path)
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
        df = df[df["indicator"].notna() & df["section"].notna()]
        if len(df) < before:
            print(f"  {csv_name}: dropped {before - len(df)} rows with empty section/indicator")

        df["filing_id"] = filing_id
        df["source_file"] = csv_name
        # Some providers' files contain duplicate rows under the unique key
        # (filing_id, source_file, section, indicator, scope). The database
        # rejects them. Drop duplicates here, keep the first occurrence,
        # and report how many were dropped.
        before = len(df)
        df = df.drop_duplicates(
            subset=["filing_id", "source_file", "section", "indicator", "scope"],
            keep="first"
        )
        dropped = before - len(df)
        if dropped > 0:
            print(f"  {csv_name}: dropped {dropped} duplicate rows on (section, indicator, scope)")
        df.to_sql("indicators", engine, if_exists="append", index=False)
        print(f"  {csv_name}: loaded {len(df)} rows")
        grand_total += len(df)

    print(f"Total indicator rows loaded: {grand_total}")


if __name__ == "__main__":
    main()
