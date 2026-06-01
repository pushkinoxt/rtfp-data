#!/usr/bin/env python3
"""
Normalise a provider bundle's CSV filenames to RTFP's canonical convention.

Providers publish their Annex II CSVs with inconsistent naming. Some use
zero-padded prefixes (01_, 02_), others don't (1_, 2_); some embed the DSA
article reference, others don't. This script renames whatever convention
the provider used to the canonical:

    01_ID.csv
    02_categories.csv
    03_A151A_MSO.csv
    04_A151B_Notices.csv
    05_A151C_Own_Illegal.csv
    06_A151D_241AB_Own_TC.csv
    07_Appeals.csv
    08_A151BCE_422C_Auto.csv
    09_A422AB_Human.csv
    10_A423_AMAR.csv
    11_A151CE_422AB_Qualitative.csv

Identification is done in two passes:
  1. Filename heuristic — match the leading number and a keyword
  2. Fallback to inspecting the file's column headers, which are distinctive
     per template

Originals are preserved with a .original suffix the first time the file
is renamed, so this script is safe to run multiple times.

Usage:
    python3 rename_to_canonical.py --bundle <path-to-bundle>
    python3 rename_to_canonical.py --bundle <path> --dry-run
"""
import argparse
import re
import sys
from pathlib import Path

import pandas as pd

CANONICAL = {
    1:  "01_ID.csv",
    2:  "02_categories.csv",
    3:  "03_A151A_MSO.csv",
    4:  "04_A151B_Notices.csv",
    5:  "05_A151C_Own_Illegal.csv",
    6:  "06_A151D_241AB_Own_TC.csv",
    7:  "07_Appeals.csv",
    8:  "08_A151BCE_422C_Auto.csv",
    9:  "09_A422AB_Human.csv",
    10: "10_A423_AMAR.csv",
    11: "11_A151CE_422AB_Qualitative.csv",
}

# Column-header signatures that uniquely identify each template file.
# A file is identified as template N if it contains ALL of N's signature columns.
SIGNATURES = {
    1:  ["Indicator", "Value"],
    2:  ["Category"],
    3:  ["Number of orders to act against illegal content received"],
    4:  ["Number of notices received"],
    5:  ["Number of own-initiative measures taken in respect of illegal content"],
    6:  ["Number of measures taken at the provider's own initiative"],
    7:  ["Total complaints received from recipients of the service"],
    8:  ["Number of measures solely taken by automated means"],
    9:  ["Number of human resources allocated to content moderation"],
    10: ["Average monthly active recipients"],
    11: ["Description of the content moderation processes and policies"],
}


def identify_by_filename(filename):
    """Try to identify a file from its name. Returns the template number or None.

    Matches patterns like "1_", "01_", "10_" anywhere in the name, prioritising
    matches preceded by a non-word character (space, hyphen, underscore at the
    start of a word). Providers prefix their filenames with all kinds of
    things ("Zalando_Transparency_Report_..._- 3_member_states.csv"), so
    we look for the template number wherever it appears as a clear segment.
    """
    name = filename.lower()
    # Patterns we accept, in order of preference:
    #   "...[non-word]NN_keyword..."  — e.g. " - 03_mso..." or "_10_amar"
    #   "^NN_keyword..."              — e.g. "01_ID..."
    patterns = [
        r"(?:^|[^0-9a-z])0?(\d{1,2})_[a-z]",
        r"^0?(\d{1,2})[_\-]",
    ]
    for pattern in patterns:
        match = re.search(pattern, name)
        if match:
            num = int(match.group(1))
            if num in CANONICAL:
                return num
    return None


def identify_by_headers(filepath):
    """Read the file's column headers and match against known signatures."""
    try:
        # Try several common separators and encodings
        for sep in [",", "\t", ";"]:
            try:
                df = pd.read_csv(filepath, sep=sep, nrows=0, dtype=str)
                if len(df.columns) > 1:
                    break
            except Exception:
                continue
        else:
            return None
    except Exception:
        return None

    headers_lower = {c.strip().lower() for c in df.columns}
    matches = []
    for template_num, signature_cols in SIGNATURES.items():
        if all(sig.lower() in h for sig in signature_cols for h in headers_lower):
            matches.append(template_num)
    if len(matches) == 1:
        return matches[0]
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, help="folder containing the provider's CSVs")
    parser.add_argument("--dry-run", action="store_true",
                        help="show what would be renamed without doing it")
    args = parser.parse_args()

    bundle = Path(args.bundle).expanduser().resolve()
    if not bundle.is_dir():
        sys.exit(f"Not a directory: {bundle}")

    csv_files = sorted(bundle.glob("*.csv"))
    if not csv_files:
        sys.exit(f"No CSV files found in {bundle}")

    plan = []  # list of (current_path, canonical_name, identified_template_num)
    unidentified = []
    already_canonical = []

    for f in csv_files:
        # Skip already-canonical files
        if f.name in CANONICAL.values():
            already_canonical.append(f.name)
            continue
        # Skip backups
        if f.name.endswith(".original"):
            continue

        template_num = identify_by_filename(f.name)
        if template_num is None:
            template_num = identify_by_headers(f)

        if template_num is None:
            unidentified.append(f.name)
        else:
            plan.append((f, CANONICAL[template_num], template_num))

    print(f"Bundle: {bundle}")
    print(f"  Already canonical: {len(already_canonical)} file(s)")
    print(f"  To rename:         {len(plan)} file(s)")
    print(f"  Unidentified:      {len(unidentified)} file(s)")
    print()

    for current, canonical, template_num in plan:
        flag = "[dry-run] " if args.dry_run else ""
        print(f"  {flag}{current.name}  ->  {canonical}  (template {template_num})")

    if unidentified:
        print()
        print("Unidentified files — please inspect manually:")
        for name in unidentified:
            print(f"  {name}")

    if args.dry_run:
        print()
        print("(dry-run — no changes made)")
        return

    if not plan:
        return

    print()
    for current, canonical, _ in plan:
        target = bundle / canonical
        if target.exists() and target != current:
            # Don't overwrite an existing canonical file
            print(f"Skipping {current.name} -> {canonical}: target already exists")
            continue
        # Preserve original via .original suffix the first time
        backup = current.with_suffix(current.suffix + ".original")
        if not backup.exists():
            current.rename(backup)
            # Now create the canonical name as a copy of the backup
            import shutil
            shutil.copy(backup, target)
        else:
            current.rename(target)
        print(f"Renamed {current.name} -> {canonical}")


if __name__ == "__main__":
    main()
