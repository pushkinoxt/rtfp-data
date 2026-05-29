import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
url = os.environ.get('DATABASE_URL')
print("URL found:", url[:40] + "..." if url else "MISSING")

engine = create_engine(url)
with engine.connect() as conn:
    result = conn.execute(text("SELECT version()"))
    print(result.scalar())
