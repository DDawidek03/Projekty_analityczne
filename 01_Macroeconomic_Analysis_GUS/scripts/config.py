import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

PROJECT_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_DIR / "dane"
SQL_DIR = Path(__file__).resolve().parent / "sql"
PARQUET_PATH = DATA_DIR / "merged_data.parquet"

LATA = [2018, 2019, 2020, 2021, 2022, 2023, 2024]

WSKAZNIKI = {
    459121: "bezrobocie",
    64428: "wynagrodzenia",
    155064: "inwestycje",
    58565: "przestepstwa",
    395374: "nowe_firmy",
    72305: "ludnosc",
    450540: "urodzenia",
    450541: "zgony",
}

load_dotenv(PROJECT_DIR / ".env")


def get_engine():
    user = os.getenv("DB_USER", "damiandawidek")
    password = os.getenv("DB_PASSWORD", "")
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "Projekt_1")
    database_url = URL.create(
        "postgresql",
        username=user,
        password=password,
        host=host,
        port=port,
        database=db_name,
    )
    return create_engine(database_url)


def run_sql_file(conn, nazwa_pliku):
    sql = (SQL_DIR / nazwa_pliku).read_text(encoding="utf-8")
    # surowy kursor bez parametrów, inaczej psycopg2 traktuje % w SQL jako placeholder
    conn.connection.cursor().execute(sql)
    print(f"Wykonano {nazwa_pliku}")
