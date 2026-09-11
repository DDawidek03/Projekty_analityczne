import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
import pandas as pd

# Load environment variables from .env file located in the parent directory
env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
load_dotenv(env_path)

USER = os.getenv("DB_USER", "damiandawidek")
PASSWORD = os.getenv("DB_PASSWORD", "")
HOST = os.getenv("DB_HOST", "localhost")
PORT = os.getenv("DB_PORT", "5432")
DN_NAME = os.getenv("DB_NAME", "Projekt_1")

ENGINE = create_engine(f"postgresql://{USER}:{PASSWORD}@{HOST}:{PORT}/{DN_NAME}")

sciezka_do_pliku_parquet = "../dane/merged_data.parquet"

try:
    df = pd.read_parquet(sciezka_do_pliku_parquet)

    df.to_sql(name="gus_indicators", con=ENGINE, if_exists="replace", index=False)
    

except Exception as e:
    print(f"Błąd połączenia: {e}")
