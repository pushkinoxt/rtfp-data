import sys
import pandas as pd
from pathlib import Path

if len(sys.argv) < 2:
    print("Usage: python inspect_csvs.py /path/to/csv/folder")
    sys.exit(1)

folder = Path(sys.argv[1])
csv_files = sorted(folder.rglob("*.csv"))

print(f"Found {len(csv_files)} CSV files in {folder}\n")

for csv_path in csv_files:
    print("=" * 70)
    print(f"FILE: {csv_path.relative_to(folder)}")
    print("=" * 70)
    try:
        df = pd.read_csv(csv_path, nrows=2)
        full_count = sum(1 for _ in open(csv_path, encoding='utf-8')) - 1
        print(f"Rows (excluding header): {full_count}")
        print(f"Columns ({len(df.columns)}):")
        for col in df.columns:
            print(f"  - {col}")
        print("First 2 rows of data:")
        print(df.to_string(max_colwidth=40))
    except Exception as e:
        print(f"  Could not read: {e}")
    print()
