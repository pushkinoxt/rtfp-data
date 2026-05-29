import pandas as pd

CSV_PATH = "/Users/pushkin/Documents/DSAPROJECT/duck-dsa-reports/raw/tiktok/2025h2/02_categories.csv"

df = pd.read_csv(CSV_PATH, usecols=[
    "Category label",
    "Category description",
    "Category of illegal content / incompatible with the terms and conditions",
])

df = df.rename(columns={
    "Category of illegal content / incompatible with the terms and conditions": "code",
    "Category description": "description",
})

df["code"] = df["code"].astype(str).str.strip()

print(f"Total rows in CSV:        {len(df)}")

# Empties
empty = df[df["code"].isin(["", "nan", "NaN"]) | df["code"].isna()]
print(f"Rows with empty/NaN code: {len(empty)}")

# After cleaning
cleaned = df[~df["code"].isin(["", "nan", "NaN"]) & df["code"].notna()]
print(f"Rows after cleaning:      {len(cleaned)}")

# Unique vs duplicate codes
print(f"Unique codes:             {cleaned['code'].nunique()}")
dupes = cleaned[cleaned.duplicated("code", keep=False)].sort_values("code")
print(f"Duplicate code rows:      {len(dupes)}")

if len(dupes) > 0:
    print("\nDuplicates (first occurrence and any after):")
    print(dupes[["code", "description"]].to_string(index=False))
