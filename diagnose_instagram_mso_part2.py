import pandas as pd

CSV = "/Users/pushkin/Documents/DSAPROJECT/duck-dsa-reports/raw/instagram/2025h2/03_A151A_MSO.csv"
df = pd.read_csv(CSV)
df.columns = [c.strip() for c in df.columns]

# What scopes appear at the boundary?
print(f"Total rows: {len(df)}")
print()
print("Rows 215-225 (around the suspected boundary between sections):")
print(df[["Category of illegal content", "Scope"]].iloc[215:225].to_string())
print()
print("Distribution of Scope values where Category is NaN:")
print(df[df["Category of illegal content"].isna()]["Scope"].value_counts().head(30))
print()
print("Distribution of Scope values where Category is present:")
print(df[df["Category of illegal content"].notna()]["Scope"].value_counts())
print()
print("Last 5 rows of the CSV:")
print(df[["Category of illegal content", "Scope",
          "Number of orders to act against illegal content received"]].tail(5).to_string())
