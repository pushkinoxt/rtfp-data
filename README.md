# rtfp-data
Data loaders and database migrations for [RTFP](https://rtfp.io) — a cross-platform comparison of the major social platforms' and marketplaces' EU Digital Services Act transparency reports.
This repository contains the Python loaders and PostgreSQL migrations that build the public RTFP database from the providers' Annex II filings. The website itself lives in [pushkinoxt/rtfp](https://github.com/pushkinoxt/rtfp).
## What's here
- `migrations/` — numbered SQL migration files, run in order against the Supabase project
- `load_filing.py` — reads file 01 of an Annex II bundle and creates a filings row
- `load_member_state_orders.py`, `load_article16_notices.py`, `load_own_initiative_illegal.py`, `load_own_initiative_tc.py`, `load_indicators.py`, `load_qualitative_indicators.py` — per-table loaders, run after `load_filing.py`
## Loading a new provider
After seeding the provider via a migration: 
py3 load_filing.py --provider <slug> --period 2025-h2 --bundle <path>
py3 load_member_state_orders.py --provider <slug> --period 2025-h2 --bundle <path>
py3 load_article16_notices.py --provider <slug> --period 2025-h2 --bundle <path>
py3 load_own_initiative_illegal.py --provider <slug> --period 2025-h2 --bundle <path>
py3 load_own_initiative_tc.py --provider <slug> --period 2025-h2 --bundle <path>
py3 load_indicators.py --provider <slug> --period 2025-h2 --bundle <path>
py3 load_qualitative_indicators.py --provider <slug> --period 2025-h2 --bundle <path> 
## Source data
Raw CSV bundles are not in this repo. They are downloaded from each provider's own transparency hub. See the [Sources page on rtfp.io](https://rtfp.io/sources) for the canonical links. 
