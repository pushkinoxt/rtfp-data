-- Give the public (anon) role read access to the two reference tables,
-- matching the read-only access your data views already have.
alter table country_codes  enable row level security;
alter table language_codes enable row level security;

drop policy if exists "Public can read country_codes" on country_codes;
drop policy if exists "Public can read language_codes" on language_codes;

create policy "Public can read country_codes"
  on country_codes for select to anon using (true);
create policy "Public can read language_codes"
  on language_codes for select to anon using (true);