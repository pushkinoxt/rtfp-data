import pandas as pd

CSV = "/Users/pushkin/Documents/DSAPROJECT/duck-dsa-reports/raw/instagram/2025h2/03_A151A_MSO.csv"

df = pd.read_csv(CSV)
df.columns = [c.strip() for c in df.columns]

print(f"Total rows in CSV:           {len(df)}")
print(f"Rows with non-null category: {df['Category of illegal content'].notna().sum()}")
print(f"Rows with NaN category:      {df['Category of illegal content'].isna().sum()}")
print(f"Rows with non-null scope:    {df['Scope'].notna().sum()}")
print()
print("First 25 rows of (Category, Scope, Orders received):")
cols = ["Category of illegal content", "Scope",
        "Number of orders to act against illegal content received",
        "Number of orders to provide information"]
print(df[cols].head(25).to_string(max_colwidth=45))
print()
print("Sample of NaN-category rows (rows 20-35):")
print(df[cols].iloc[20:35].to_string(max_colwidth=45))
